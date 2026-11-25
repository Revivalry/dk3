// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Navigation values and policy. Routes propose movement; collision remains authoritative.
const std = @import("std");
const v = @import("vector.zig");
pub const Mode = enum { easy, normal, hard, dm, ctf, deathtag };
pub fn selection(bytes: []const u8, wanted: Mode) ![]const u8 {
    var tokens = std.mem.tokenizeAny(u8, bytes, " \t\r\n");
    if (!std.mem.eql(u8, tokens.next() orelse "", "dk3_navigation") or !std.mem.eql(u8, tokens.next() orelse "", "1")) return error.NavigationHeader;
    var seen: u8 = 0;
    var result: ?[]const u8 = null;
    while (tokens.next()) |name| {
        const mode = std.meta.stringToEnum(Mode, name) orelse return error.NavigationMode;
        const bit = @as(u8, 1) << @intFromEnum(mode);
        if (seen & bit != 0) return error.DuplicateNavigationMode;
        seen |= bit;
        const value = tokens.next() orelse return error.NavigationName;
        if (value.len == 0 or value.len >= 64) return error.NavigationName;
        for (value) |char| if (!(char >= 'a' and char <= 'z') and !std.ascii.isDigit(char) and char != '_' and char != '-') return error.NavigationName;
        if (mode == wanted) result = value;
    }
    return result orelse error.MissingNavigationMode;
}
/// `entrance`: where the next reachability starts (for a lift link, beside
/// or on the lift at its lower stop; `point` is then its far end).
pub const Waypoint = struct { point: v.Vec3, jump: bool = false, crouch: bool = false, ladder: bool = false, elevator: bool = false, drop: bool = false, entrance: v.Vec3 = @splat(0), from_area: i32 = 0, to_area: i32 = 0 };
/// Detect a route which repeatedly ends under a stationary traveller while its
/// real destination remains elsewhere. Special traversal waits retain ownership.
pub const EndpointHold = struct {
    since: ?i64 = null,
    position: v.Vec3 = @splat(0),
    destination: v.Vec3 = @splat(0),
    point: v.Vec3 = @splat(0),
    pub fn update(self: *EndpointHold, position: v.Vec3, destination: ?v.Vec3, waypoint: ?Waypoint, grounded: bool, now: i64) bool {
        const goal = destination orelse {
            self.since = null;
            return false;
        };
        const step = waypoint orelse {
            self.since = null;
            return false;
        };
        if (!grounded or step.jump or step.ladder or step.elevator or step.drop or v.length(v.subtract(position, step.point)) > 64 or v.length(v.subtract(position, goal)) < 96) {
            self.since = null;
            return false;
        }
        // Avoidance can keep the body circling a partial endpoint. Count
        // progress out of that local pocket, rather than each sidestep.
        if (self.since == null or now < self.since.? or v.length(v.subtract(position, self.position)) > 64 or v.length(v.subtract(goal, self.destination)) > 64 or v.length(v.subtract(step.point, self.point)) > 64) {
            self.* = .{ .since = now, .position = position, .destination = goal, .point = step.point };
            return false;
        }
        return now - self.since.? >= 1500;
    }
};

test "a stationary partial endpoint is distinct from progress and special traversal waits" {
    const t = std.testing;
    var hold: EndpointHold = .{};
    const position: v.Vec3 = .{ 0, 0, 24 };
    const goal: v.Vec3 = .{ 240, 0, 152 };
    const step: Waypoint = .{ .point = .{ 8, 0, 24 } };
    try t.expect(!hold.update(position, goal, step, true, 100));
    try t.expect(!hold.update(position, goal, step, true, 1500));
    try t.expect(hold.update(position, goal, step, true, 1600));
    const advanced: v.Vec3 = .{ 80, 0, 24 };
    const onward: Waypoint = .{ .point = .{ 88, 0, 24 } };
    try t.expect(!hold.update(advanced, goal, onward, true, 1650));
    try t.expect(hold.update(advanced, goal, onward, true, 3150));
    try t.expect(!hold.update(advanced, goal, .{ .point = onward.point, .elevator = true }, true, 3200));
    try t.expect(!hold.update(position, goal, step, false, 5000));
    try t.expect(!hold.update(position, position, step, true, 6000));
    try t.expect(!hold.update(position, goal, step, true, 7000));
    try t.expect(!hold.update(position, .{ 400, 0, 152 }, step, true, 8500));
    try t.expect(!hold.update(position, goal, step, true, 100));
}

test "sidesteps around a partial endpoint do not count as onward progress" {
    var hold: EndpointHold = .{};
    const goal: v.Vec3 = .{ -203, -309, -680 };
    const step: Waypoint = .{ .point = .{ -241, -496, -808 } };
    try std.testing.expect(!hold.update(.{ -212, -470, -808 }, goal, step, true, 100));
    try std.testing.expect(!hold.update(.{ -200, -486, -808 }, goal, step, true, 1100));
    try std.testing.expect(hold.update(.{ -210, -459, -808 }, goal, step, true, 1600));
    try std.testing.expect(!hold.update(.{ -173, -574, -856 }, goal, .{ .point = .{ -186, -608, -856 } }, true, 1700));
}
/// `lifts`: false leaves lift links out (a lift away that the traveller
/// cannot call, while a way round it exists).
pub const Request = struct {
    /// A recently reached polygon retained for a smaller hull beside the
    /// baked mesh boundary. Physical movement still qualifies every transfer.
    start_hint: i32 = 0,
    player: bool = false,
    allow_slime_escape: bool = false,
    lifts: bool = true,
    position: v.Vec3,
    destination: v.Vec3,
    slot: u16,
    /// Actual recovery hull: a narrow traveller can stand outside the area
    /// graph's wider expanded solids. Recovery still requires physical clearance.
    mins: v.Vec3 = .{ -15, -15, -24 },
    maxs: v.Vec3 = .{ 15, 15, 4 },
    /// Zero selects the engine's ordinary player collision mask.
    mask: u32 = 0,
};
pub const Service = struct {
    context: *anyopaque,
    next_fn: *const fn (*anyopaque, Request) anyerror!?Waypoint,
    /// Optional whole-route prediction for diagnostics: fills `points` with
    /// successive route positions and returns how many were written.
    predict_fn: ?*const fn (*anyopaque, Request, []v.Vec3) anyerror!usize = null,
    /// Far endpoints of upcoming jump/drop transfers, preserving their type.
    jumps_fn: ?*const fn (*anyopaque, Request, []Waypoint) anyerror!usize = null,
    /// Optional remaining route length (in units at running pace) from the
    /// request's position to its destination; null without a route.
    travel_fn: ?*const fn (*anyopaque, Request) anyerror!?f32 = null,
    pub fn next(self: Service, request: Request) !?Waypoint {
        return self.next_fn(self.context, request);
    }
    pub fn travel(self: Service, request: Request) !?f32 {
        const travel_fn = self.travel_fn orelse return null;
        return travel_fn(self.context, request);
    }
    pub fn predict(self: Service, request: Request, points: []v.Vec3) !usize {
        const predict_fn = self.predict_fn orelse return 0;
        return predict_fn(self.context, request, points);
    }
    pub fn jumps(self: Service, request: Request, points: []Waypoint) !usize {
        const jumps_fn = self.jumps_fn orelse return 0;
        return jumps_fn(self.context, request, points);
    }
};
pub const State = struct {
    destination: v.Vec3 = @splat(0),
    waypoint: ?Waypoint = null,
    refresh_ms: i64 = 0,
    progress_ms: i64 = 0,
    progress_position: v.Vec3 = @splat(0),
    blocked: bool = false,
    fleeing: bool = false,
    physical_until_ms: i64 = 0,
    physical_goal: v.Vec3 = @splat(0),
    physical_point: v.Vec3 = @splat(0),
    pub fn update(self: *State, service: Service, request: Request, now: i64) !?Waypoint {
        const changed = v.length(v.subtract(request.destination, self.destination)) > 48;
        if (changed) self.physical_until_ms = 0;
        // Horizontal: hopping in place against an obstruction is no progress.
        if (horizontalDistance(request.position, self.progress_position) > 8 or changed) {
            self.progress_position = request.position;
            self.progress_ms = now;
            self.blocked = false;
        } else if (now - self.progress_ms >= 750) {
            self.blocked = true;
        }
        const reached = if (self.waypoint) |point| (if (request.player) v.length(v.subtract(request.position, point.point)) else horizontalDistance(request.position, point.point)) < 16 else false;
        if (changed or reached or now >= self.refresh_ms) {
            self.destination = request.destination;
            self.waypoint = try service.next(request);
            self.refresh_ms = now + if (self.blocked) @as(i64, 200) else 400;
        }
        return self.waypoint;
    }
};
pub fn horizontalDistance(a: v.Vec3, b: v.Vec3) f32 {
    return @sqrt((a[0] - b[0]) * (a[0] - b[0]) + (a[1] - b[1]) * (a[1] - b[1]));
}
pub fn velocity(position: v.Vec3, destination: v.Vec3, speed: f32, delta: f32) v.Vec3 {
    var direction = v.subtract(destination, position);
    direction[2] = 0;
    const distance = v.length(direction);
    if (distance < 0.01 or delta <= 0) return @splat(0);
    return v.scale(direction, @min(speed, distance / delta) / distance);
}
test "navigation selection rejects ambiguous and unsafe asset names" {
    try std.testing.expectEqualStrings("e1m1c-normal", try selection("dk3_navigation 1 easy e1m1c normal e1m1c-normal hard e1m1c-hard", .normal));
    try std.testing.expectError(error.DuplicateNavigationMode, selection("dk3_navigation 1 dm a dm b", .dm));
    try std.testing.expectError(error.NavigationName, selection("dk3_navigation 1 dm ../a", .dm));
    try std.testing.expectError(error.MissingNavigationMode, selection("dk3_navigation 1 dm a", .hard));
}
test "route invalidation follows progress, goal changes and endpoint arrival" {
    const Fake = struct {
        calls: usize = 0,
        fn next(raw: *anyopaque, request: Request) !?Waypoint {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return .{ .point = request.destination };
        }
    };
    var fake: Fake = .{};
    const service: Service = .{ .context = &fake, .next_fn = Fake.next };
    var state: State = .{};
    const request: Request = .{ .position = @splat(0), .destination = .{ 100, 0, 0 }, .slot = 3 };
    _ = try state.update(service, request, 0);
    _ = try state.update(service, request, 100);
    try std.testing.expectEqual(@as(usize, 1), fake.calls);
    _ = try state.update(service, request, 800);
    try std.testing.expect(state.blocked);
    _ = try state.update(service, .{ .position = .{ 90, 0, 0 }, .destination = request.destination, .slot = 3 }, 850);
    try std.testing.expect(!state.blocked);
    try std.testing.expectEqual(@as(usize, 3), fake.calls);
    try std.testing.expectApproxEqAbs(@as(f32, 20), velocity(.{ 99, 0, 0 }, request.destination, 300, 0.05)[0], 0.001);
}
