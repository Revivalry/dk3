// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Bounded landing prediction through the actual movement motor.
const std = @import("std");
const move = @import("player_move.zig");
const slide = @import("../../core/domain/slide.zig");
const collision = @import("../../core/domain/collision.zig");
const v = @import("../../core/domain/vector.zig");
pub const Landing = struct { safe: bool, position: v.Vec3 };
pub const Bounds = @import("../../core/domain/navigation_input.zig").Bounds;
pub const Field = struct {
    point: v.Vec3,
    radius: f32,
    bounds: ?Bounds = null,
    /// Raw contact volume, before expansion by the moving body's current hull.
    contact: ?Bounds = null,
    pub fn forHull(self: Field, mins: v.Vec3, maxs: v.Vec3) Field {
        var result = self;
        if (self.contact) |box| result.bounds = .{ .mins = v.subtract(v.subtract(box.mins, maxs), @splat(1)), .maxs = v.add(v.subtract(box.maxs, mins), @splat(1)) };
        return result;
    }
    fn distance(self: Field, point: v.Vec3) f32 {
        const box = self.bounds orelse return v.length(v.subtract(point, self.point)) - self.radius;
        var outside: v.Vec3 = @splat(0);
        var inside = std.math.inf(f32);
        for (0..3) |axis| {
            outside[axis] = @max(box.mins[axis] - point[axis], @max(point[axis] - box.maxs[axis], 0));
            inside = @min(inside, @min(point[axis] - box.mins[axis], box.maxs[axis] - point[axis]));
        }
        return if (v.length(outside) > 0) v.length(outside) else -inside;
    }
    fn crosses(self: Field, start: v.Vec3, end: v.Vec3) bool {
        if (self.bounds) |box| {
            var enter: f32 = 0;
            var leave: f32 = 1;
            for (0..3) |axis| {
                const delta = end[axis] - start[axis];
                if (@abs(delta) < 0.0001) {
                    if (start[axis] <= box.mins[axis] or start[axis] >= box.maxs[axis]) return false;
                } else {
                    const a = (box.mins[axis] - start[axis]) / delta;
                    const b = (box.maxs[axis] - start[axis]) / delta;
                    enter = @max(enter, @min(a, b));
                    leave = @min(leave, @max(a, b));
                    if (enter >= leave) return false;
                }
            }
            return true;
        }
        const delta = v.subtract(end, start);
        const length2 = v.dot(delta, delta);
        const fraction = if (length2 > 0.0001) std.math.clamp(v.dot(v.subtract(self.point, start), delta) / length2, 0, 1) else 0;
        return self.distance(v.add(start, v.scale(delta, fraction))) < 0;
    }
};
pub const Walk = struct { safe: bool = false, position: v.Vec3, velocity: v.Vec3 = @splat(0), player: move.Player = .{}, normal: f32 = 0, blocking_field: ?usize = null, reason: enum { range, support, drop, liquid, volume, field, budget, reached } = .range };
pub fn walkCommand(position: v.Vec3, destination: v.Vec3, time_ms: i64, speed: f32) move.Command {
    const difference = v.subtract(destination, position);
    const across = @sqrt(difference[0] * difference[0] + difference[1] * difference[1]);
    const magnitude = std.math.clamp(across / @max(8, speed * 0.15) * 127, 1, 127);
    return .{ .time_ms = time_ms, .angles = .{ 0, std.math.atan2(difference[1], difference[0]) * 180 / std.math.pi, 0 }, .forward = if (across > 0.05) @intFromFloat(magnitude) else 0 };
}
pub fn walkInput(position: v.Vec3, destination: v.Vec3, time_ms: i64, parameters: move.Parameters, service: collision.Collision) !move.Command {
    var input = walkCommand(position, destination, time_ms, parameters.speed);
    if (try @import("../../core/domain/navigation_input.zig").crouch(service, position, destination, parameters.mins, parameters.maxs, parameters.slot, parameters.mask)) input.up = -127;
    return input;
}

/// Keep a qualified ground stroke while facing elsewhere. The player's input
/// scale depends on the largest axis and on crouch/jump, not vector length
/// alone; solve for the same horizontal wish speed before integer encoding.
pub fn walkFacing(input: move.Command, angles: v.Vec3) move.Command {
    var result = input;
    result.angles = angles;
    const forward: f32 = @floatFromInt(input.forward);
    const right: f32 = @floatFromInt(input.right);
    const up: f32 = @floatFromInt(input.up);
    const length = @sqrt(forward * forward + right * right);
    if (length == 0) return result;
    const before = v.basis(.{ 0, input.angles[1], 0 });
    const direction = v.scale(v.add(v.scale(before.forward, forward), v.scale(before.right, right)), 1 / length);
    const after = v.basis(.{ 0, angles[1], 0 });
    const x = v.dot(direction, after.forward);
    const y = v.dot(direction, after.right);
    const largest = @max(@abs(x), @abs(y));
    const wanted = @max(@abs(forward), @abs(right), @abs(up)) * length / @sqrt(length * length + up * up);
    var low: f32 = 0;
    var high: f32 = 127 / largest;
    for (0..24) |_| {
        const trial = (low + high) / 2;
        const speed = @max(trial * largest, @abs(up)) * trial / @sqrt(trial * trial + up * up);
        if (speed < wanted) low = trial else high = trial;
    }
    result.forward = @intFromFloat(std.math.clamp(@round(x * high), -127, 127));
    result.right = @intFromFloat(std.math.clamp(@round(y * high), -127, 127));
    return result;
}

test "bounded walking view preserves actual motor displacement including diagonal and crouch input scaling" {
    const Floor = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            const a = request.start[2] + request.mins[2];
            const b = request.end[2] + request.mins[2];
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var context: u8 = 0;
    const service: collision.Collision = .{ .context = &context, .trace_fn = Floor.trace, .contents_fn = Floor.contents };
    const parameters: move.Parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .speed = 320, .snap_velocity = false };
    for ([_]f32{ 0, 36, 90, 143, 180, 359 }) |yaw| for ([_]i8{ 7, 64, 127 }) |pace| for ([_]i8{ 0, -127 }) |up| {
        const input: move.Command = .{ .time_ms = 1000, .angles = .{ 0, 23, 0 }, .forward = pace, .up = up };
        const facing = walkFacing(input, .{ 0, yaw, 0 });
        var original_player: move.Player = .{ .command_ms = 950 };
        var turned_player = original_player;
        var original: slide.State = .{ .position = .{ 0, 0, 24 }, .velocity = @splat(0) };
        var turned = original;
        _ = try move.run(&original_player, &original, input, parameters, service);
        _ = try move.run(&turned_player, &turned, facing, parameters, service);
        try std.testing.expect(v.length(v.subtract(original.position, turned.position)) < 0.15);
        try std.testing.expect(v.length(v.subtract(original.velocity, turned.velocity)) < 2);
        try std.testing.expectEqual(input.up, facing.up);
        try std.testing.expectEqual(yaw, facing.angles[1]);
    };
}

/// A local corridor must work through the real motor, including acceleration,
/// steps and gravity. The caller supplies its actual motor parameters and
/// forbidden trigger volumes; prediction never commits a pose.
pub fn walk(player: move.Player, initial: slide.State, destination: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, volumes: []const Bounds, fields: []const Field) !Walk {
    return walkArrival(player, initial, destination, parameters, service, forbidden, volumes, fields, null);
}
fn walkArrival(player: move.Player, initial: slide.State, destination: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, volumes: []const Bounds, fields: []const Field, arrival: ?v.Vec3) !Walk {
    var result: Walk = .{ .position = initial.position };
    const span = v.length(v.subtract(destination, initial.position));
    if (span > 320 or parameters.speed <= 0) return result;
    var state = player;
    var motion = initial;
    const first_ms = state.command_ms + 50;
    const ticks: usize = @intFromFloat(@min(100, @ceil(span / (parameters.speed * 0.025)) + @as(f32, if (arrival != null) 32 else 12)));
    for (0..ticks) |tick| {
        const before = motion.position;
        var body_maxs = parameters.maxs;
        if (state.ducked) body_maxs[2] = 4;
        const terminal = v.subtract(arrival orelse destination, before);
        const terminal_span = @sqrt(terminal[0] * terminal[0] + terminal[1] * terminal[1]);
        if (terminal_span <= @as(f32, if (arrival != null) 16 else 2) and @abs(terminal[2]) <= 24) {
            var clear = true;
            for (fields) |field| if (field.forHull(parameters.mins, body_maxs).distance(before) < 0) {
                clear = false;
            };
            if (try service.contents(v.add(before, .{ 0, 0, parameters.mins[2] + 1 }), parameters.slot) & forbidden != 0) return .{ .position = before, .reason = .liquid };
            const support = try service.trace(.{ .start = before, .end = v.add(before, .{ 0, 0, -2 }), .mins = parameters.mins, .maxs = body_maxs, .slot = parameters.slot, .mask = parameters.mask });
            if (clear and !support.start_solid and !support.all_solid and support.fraction < 1 and support.normal[2] >= 0.7) return .{ .safe = true, .position = before, .velocity = motion.velocity, .player = state, .reason = .reached };
        }
        const input = try walkInput(before, destination, first_ms + @as(i64, @intCast(tick)) * 50, parameters, service);
        const moved = try move.run(&state, &motion, input, parameters, service);
        result.position = motion.position;
        result.reason = .drop;
        if (before[2] - motion.position[2] > 32 or initial.position[2] - motion.position[2] > 32) return result;
        const support = try service.trace(.{ .start = motion.position, .end = v.add(motion.position, .{ 0, 0, -32.25 }), .mins = moved.mins, .maxs = moved.maxs, .slot = parameters.slot, .mask = parameters.mask });
        result.reason = .support;
        result.normal = support.normal[2];
        // A transient bevel contact need not be a standing floor. Only a
        // complete motor rollout ending on walkable support authorizes it.
        const climbing = support.normal[2] > 0.15;
        if (support.start_solid or support.all_solid or support.fraction == 1 or (support.normal[2] < 0.7 and !climbing)) return result;
        result.reason = .liquid;
        if (try service.contents(v.add(support.end, .{ 0, 0, parameters.mins[2] + 1 }), parameters.slot) & forbidden != 0) return result;
        result.reason = .volume;
        for (volumes) |box| {
            var overlaps = true;
            for (0..3) |axis| if (@max(before[axis], motion.position[axis]) + moved.maxs[axis] <= box.mins[axis] or @min(before[axis], motion.position[axis]) + moved.mins[axis] >= box.maxs[axis]) {
                overlaps = false;
            };
            if (overlaps) return result;
        }
        result.reason = .field;
        for (fields, 0..) |source, index| {
            const field = source.forHull(moved.mins, moved.maxs);
            const initial_distance = field.distance(initial.position);
            // A body already in a contact field must be able to leave it.
            // It may never move closer to the source along that escape.
            if (field.crosses(before, motion.position) and (initial_distance >= 0 or field.distance(before) < initial_distance - 0.01 or field.distance(motion.position) < field.distance(before) - 0.01)) {
                result.blocking_field = index;
                return result;
            }
        }
    }
    result.reason = .budget;
    return result;
}

/// Find a short physical detour around persistent contact fields. Both legs
/// run the same motor and carry predicted velocity through the turn. The
/// final support must remain within the ordinary navigation arrival radius.
pub fn route(player: move.Player, initial: slide.State, destination: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, volumes: []const Bounds, fields: []const Field) !?v.Vec3 {
    const direct = try walk(player, initial, destination, parameters, service, forbidden, volumes, fields);
    if (direct.safe) return destination;
    if (direct.reason != .field) return null;
    const direction = v.normalize(.{ destination[0] - initial.position[0], destination[1] - initial.position[1], 0 });
    const across: v.Vec3 = .{ -direction[1], direction[0], 0 };
    var best: ?v.Vec3 = null;
    var cost = std.math.inf(f32);
    for ([_]v.Vec3{ @splat(0), .{ 16, 0, 0 }, .{ -16, 0, 0 }, .{ 0, 16, 0 }, .{ 0, -16, 0 }, v.scale(direction, 16), v.scale(direction, -16), v.scale(across, 16), v.scale(across, -16) }) |offset| {
        const end = v.add(destination, offset);
        const straight = try walkArrival(player, initial, end, parameters, service, forbidden, volumes, fields, destination);
        if (straight.safe and v.length(v.subtract(straight.position, destination)) <= 16) return end;
        const middle = v.scale(v.add(initial.position, end), 0.5);
        var corners: [10]v.Vec3 = undefined;
        var corner_count: usize = 6;
        for ([_]f32{ 48, -48, 80, -80, 112, -112 }, corners[0..6]) |width, *corner| corner.* = v.add(middle, v.scale(across, width));
        if (direct.blocking_field) |index| if (fields[index].bounds) |box| {
            for ([_][2]f32{ .{ box.mins[0] - 8, box.mins[1] - 8 }, .{ box.mins[0] - 8, box.maxs[1] + 8 }, .{ box.maxs[0] + 8, box.mins[1] - 8 }, .{ box.maxs[0] + 8, box.maxs[1] + 8 } }) |point| {
                corners[corner_count] = .{ point[0], point[1], middle[2] };
                corner_count += 1;
            }
        };
        for (corners[0..corner_count]) |corner| {
            const rank = v.length(v.subtract(corner, initial.position)) + v.length(v.subtract(end, corner));
            if (rank >= cost) continue;
            const first = try walk(player, initial, corner, parameters, service, forbidden, volumes, fields);
            if (!first.safe) continue;
            const second = try walkArrival(first.player, .{ .position = first.position, .velocity = first.velocity }, end, parameters, service, forbidden, volumes, fields, destination);
            if (!second.safe or v.length(v.subtract(second.position, destination)) > 16) continue;
            best = corner;
            cost = rank;
        }
    }
    return best;
}

pub fn landing(player: move.Player, initial: slide.State, command: move.Command, parameters: move.Parameters, service: collision.Collision, forbidden: u32) !Landing {
    var state = player;
    var motion = initial;
    state.command_ms = command.time_ms - 50;
    var departed = state.ground_entity == 2047;
    var resting: usize = 0;
    for (0..28) |tick| {
        var input = command;
        input.time_ms += @as(i64, @intCast(tick)) * 50;
        // Holding jump is one takeoff; it must not invent another after landing.
        if (tick > 0) input.up = 0;
        // A touchdown is safe only if ordinary braking can keep the body
        // on that surface. A single transient ledge contact is insufficient.
        if (departed and resting > 0) {
            input.forward = 0;
            input.right = 0;
        }
        _ = try move.run(&state, &motion, input, parameters, service);
        const feet = v.add(motion.position, .{ 0, 0, parameters.mins[2] + 1 });
        if (try service.contents(feet, parameters.slot) & forbidden != 0) return .{ .safe = false, .position = motion.position };
        departed = departed or state.ground_entity == 2047;
        resting = if (state.ground_entity != 2047) resting + 1 else 0;
        if (resting >= 4) return .{ .safe = true, .position = motion.position };
    }
    return .{ .safe = false, .position = motion.position };
}

/// Keep a safe proposed takeoff/air stroke. Otherwise compare physical braking,
/// cancelling a takeoff and lateral strokes; no simulated pose is committed.
pub fn protect(player: move.Player, motion: slide.State, proposed: move.Command, parameters: move.Parameters, service: collision.Collision, forbidden: u32, goal: ?v.Vec3) !move.Command {
    // All alternatives observe the same uncommitted world and probe ownership.
    // Stuck motors otherwise repeat the complete separating-plane search for
    // each future tick and alternative, even at identical positions.
    var memo: @import("../../core/domain/collision_memo.zig").Memo = .{ .backend = service };
    const queries = memo.service();
    return protectQueries(player, motion, proposed, parameters, queries, forbidden, goal);
}

fn protectQueries(player: move.Player, motion: slide.State, proposed: move.Command, parameters: move.Parameters, queries: collision.Collision, forbidden: u32, goal: ?v.Vec3) !move.Command {
    if ((try landing(player, motion, proposed, parameters, queries, forbidden)).safe) return proposed;
    var candidates: [6]move.Command = @splat(proposed);
    for (&candidates) |*input| input.up = 0;
    const axes = v.basis(.{ 0, proposed.angles[1], 0 });
    const reverse = v.normalize(.{ -motion.velocity[0], -motion.velocity[1], 0 });
    candidates[0].forward = @intFromFloat(std.math.clamp(v.dot(reverse, axes.forward) * 127, -127, 127));
    candidates[0].right = @intFromFloat(std.math.clamp(v.dot(reverse, axes.right) * 127, -127, 127));
    candidates[1].forward = 0;
    candidates[1].right = 0;
    candidates[2].forward = 0;
    candidates[2].right = 127;
    candidates[3].forward = 0;
    candidates[3].right = -127;
    candidates[4].forward = @intCast(std.math.clamp(-@as(i16, proposed.forward), -127, 127));
    candidates[4].right = @intCast(std.math.clamp(-@as(i16, proposed.right), -127, 127));
    var best = candidates[0];
    var score = std.math.inf(f32);
    for (candidates) |input| {
        const result = try landing(player, motion, input, parameters, queries, forbidden);
        if (!result.safe) continue;
        const cost = v.length(v.subtract(result.position, goal orelse motion.position));
        if (cost < score) {
            best = input;
            score = cost;
        }
    }
    return best;
}

test "overlapped landing alternatives retain the command while reusing identical sweeps" {
    const Blocked = struct {
        calls: usize = 0,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return .{ .fraction = 0, .end = request.start, .normal = @splat(0), .start_solid = true, .all_solid = true };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var blocked: Blocked = .{};
    const service: collision.Collision = .{ .context = &blocked, .trace_fn = Blocked.trace, .contents_fn = Blocked.contents };
    const player: move.Player = .{ .command_ms = 950 };
    const motion: slide.State = .{ .position = .{ 0, 0, 48 }, .velocity = .{ 160, 0, 0 } };
    const input: move.Command = .{ .time_ms = 1000, .angles = @splat(0), .forward = 127 };
    const parameters: move.Parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .speed = 160, .snap_velocity = false };
    const expected = try protectQueries(player, motion, input, parameters, service, 2, null);
    const original_calls = blocked.calls;
    blocked.calls = 0;
    const actual = try protect(player, motion, input, parameters, service, 2, null);
    try std.testing.expectEqualDeep(expected, actual);
    try std.testing.expect(blocked.calls * 4 < original_calls);
}

test "air steering brakes back onto a platform instead of landing in a harmful pit" {
    const Floor = struct {
        edge: f32,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const height: f32 = if (request.end[0] > self.edge) -128 else 0;
            const a = request.start[2] + request.mins[2] - height;
            const b = request.end[2] + request.mins[2] - height;
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
        }
        fn contents(raw: *anyopaque, point: v.Vec3, _: u16) !u32 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            return if (point[0] > self.edge and point[2] < -8) 2 else 0;
        }
    };
    // Braking settles near x68; the recoverable fixture must have enough
    // floor for contact and stopping, while the original stroke falls off.
    var context: Floor = .{ .edge = 80 };
    const service: collision.Collision = .{ .context = &context, .trace_fn = Floor.trace, .contents_fn = Floor.contents };
    const parameters: move.Parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .speed = 160, .snap_velocity = false };
    const player: move.Player = .{ .command_ms = 950 };
    const motion: slide.State = .{ .position = .{ 0, 0, 48 }, .velocity = .{ 160, 0, 100 } };
    const input: move.Command = .{ .time_ms = 1000, .angles = @splat(0), .forward = 127 };
    try std.testing.expect(!(try landing(player, motion, input, parameters, service, 2)).safe);
    const guarded = try protect(player, motion, input, parameters, service, 2, .{ 160, 0, 24 });
    try std.testing.expect((try landing(player, motion, guarded, parameters, service, 2)).safe);
    try std.testing.expect(guarded.forward < 0);
    // A narrower platform cannot be recovered with this velocity and the
    // real air acceleration. Prediction must not invent a safe landing.
    context.edge = 48;
    const too_late = try protect(player, motion, input, parameters, service, 2, .{ 160, 0, 24 });
    try std.testing.expect(!(try landing(player, motion, too_late, parameters, service, 2)).safe);
}

test "contact fields use the actual body-space box and admit a physically clear detour" {
    const Floor = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            const a = request.start[2] + request.mins[2];
            const b = request.end[2] + request.mins[2];
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var fixture: u8 = 0;
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Floor.trace, .contents_fn = Floor.contents };
    const parameters: move.Parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .speed = 128, .mins = .{ -8, -8, -10 }, .maxs = .{ 8, 8, 4 }, .snap_velocity = false };
    const player: move.Player = .{ .command_ms = 950, .ground_entity = 2046 };
    const motion: slide.State = .{ .position = .{ 0, 0, 10.125 }, .velocity = @splat(0) };
    const goal: v.Vec3 = .{ 128, 0, 10.125 };
    var fields = [_]Field{.{ .point = .{ 64, 0, 18 }, .radius = 32, .bounds = .{ .mins = .{ 55, -9, 13 }, .maxs = .{ 73, 9, 29 } } }};
    try std.testing.expect((try walk(player, motion, goal, parameters, service, 2, &.{}, &fields)).safe);
    fields[0] = .{ .point = .{ 64, 0, 12 }, .radius = 32, .bounds = .{ .mins = .{ 55, -9, 7 }, .maxs = .{ 73, 9, 23 } } };
    try std.testing.expect(!(try walk(player, motion, goal, parameters, service, 2, &.{}, &fields)).safe);
    const corner = (try route(player, motion, goal, parameters, service, 2, &.{}, &fields)).?;
    try std.testing.expect(@abs(corner[1]) > 9);
    try std.testing.expect((try walk(player, motion, corner, parameters, service, 2, &.{}, &fields)).safe);
}
