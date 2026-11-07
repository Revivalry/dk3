// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: debris. Authored launched brush debris uses a delayed hull expansion and finite motion.
/// The world-control states this class owns, by saved tag (control_classes.zig).
pub const controls = .{.{ .tag = "debris", .State = State }};
const std = @import("std");
const v = @import("../../../../core/domain/vector.zig");
pub const gravity: f32 = 800;
pub const Forecast = struct { point: v.Vec3, eta: f32, radius: f32, field: bool = true };
/// Short ballistic chords bound the gravity sag to one unit. Relative motion
/// includes the observer, so a fragment crossing the planned run is a threat.
pub fn forecast(position: v.Vec3, velocity: v.Vec3, observer: v.Vec3, observer_velocity: v.Vec3, radius: f32) ?Forecast {
    var best_distance: f32 = std.math.inf(f32);
    var best: Forecast = .{ .point = position, .eta = 0, .radius = radius };
    var previous = position;
    var relative = v.subtract(position, observer);
    for (1..17) |step| {
        const time = @as(f32, @floatFromInt(step)) * 0.1;
        var point = v.add(position, v.scale(velocity, time));
        point[2] -= 0.5 * gravity * time * time;
        const next = v.subtract(point, v.add(observer, v.scale(observer_velocity, time)));
        const delta = v.subtract(next, relative);
        const length2 = v.dot(delta, delta);
        const fraction = if (length2 > 0) std.math.clamp(-v.dot(relative, delta) / length2, 0, 1) else 0;
        const nearest = v.add(relative, v.scale(delta, fraction));
        const distance = v.dot(nearest, nearest);
        if (distance < best_distance) {
            best_distance = distance;
            best.point = v.add(previous, v.scale(v.subtract(point, previous), fraction));
            best.eta = time - 0.1 + fraction * 0.1;
        }
        previous = point;
        relative = next;
    }
    return if (best_distance <= (radius + 32) * (radius + 32)) best else null;
}
pub const render_tag = 10034;
pub const State = struct {
    visible: bool = false,
    initialized: bool = false,
    active: bool = false,
    stopped: bool = false,
    flags: u32 = 0,
    owner: u32 = 0,
    activator: u32 = 0,
    destination: [3]f32 = @splat(0),
    spin: [3]f32 = @splat(0),
    parameters: @import("../../../../core/domain/audio.zig").Parameters = .{},
    water: bool = false,
    next_ms: i64 = 0,
    started_ms: i64 = 0,
    stepped_ms: i64 = 0,
    expand_ms: ?i64 = null,
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.shift(&self.next_ms);
        try clock.shift(&self.started_ms);
        try clock.shift(&self.stepped_ms);
        try clock.deadline(&self.expand_ms);
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.fields(self, .{ "owner", "activator" });
    }
};
/// The class samples descending flight in 100 ms intervals and uses full distance.
pub fn forwardSpeed(start_z: f32, target_z: f32, distance: f32, upward: f32) !f32 {
    if (!std.math.isFinite(start_z) or !std.math.isFinite(target_z) or !std.math.isFinite(distance) or !std.math.isFinite(upward) or distance < 0) return error.InvalidDebrisFlight;
    for (2..16384) |tick| {
        const time = @as(f32, @floatFromInt(tick)) * 0.1;
        if (upward - gravity * time < 0 and start_z + upward * time - 0.5 * gravity * time * time <= target_z) return distance / time;
    }
    return error.InvalidDebrisFlight;
}
pub fn contact(velocity: [3]f32, normal: [3]f32) [3]f32 {
    var dot: f32 = 0;
    for (velocity, normal) |speed, axis| dot += speed * axis;
    var result: [3]f32 = undefined;
    for (&result, velocity, normal) |*value, speed, axis| {
        value.* = speed - axis * dot * 1.5;
        if (@abs(value.*) < 0.1) value.* = 0;
    }
    return result;
}
test "targeted debris uses descending sample and bounce retains tangential motion" {
    const t = std.testing;
    try t.expectApproxEqAbs(@as(f32, 1000), try forwardSpeed(0, 0, 1000, 400), 0.001);
    try t.expectApproxEqAbs(@as(f32, 500), try forwardSpeed(0, -800, 1000, 400), 0.001);
    try t.expectEqual([3]f32{ 50, 20, 40 }, contact(.{ 50, 20, -80 }, .{ 0, 0, 1 }));
    try t.expectEqual([3]f32{ 50, 20, -80 }, contact(.{ -100, 20, -80 }, .{ 1, 0, 0 }));
}
test "debris forecast includes ballistic drop and observer motion" {
    const t = std.testing;
    const falling = forecast(.{ 0, 0, 100 }, .{ 200, 0, 0 }, .{ 100, 0, 0 }, @splat(0), 48).?;
    try t.expectApproxEqAbs(@as(f32, 0.5), falling.eta, 0.001);
    try t.expectApproxEqAbs(@as(f32, 100), falling.point[0], 0.001);
    const crossing = forecast(.{ 0, 0, 100 }, @splat(0), .{ 100, 0, 0 }, .{ -200, 0, 0 }, 48).?;
    try t.expectApproxEqAbs(@as(f32, 0.5), crossing.eta, 0.001);
    try t.expect(forecast(.{ 0, 0, 100 }, .{ -200, 0, 0 }, .{ 500, 0, 0 }, @splat(0), 48) == null);
}
