// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Bounded landing prediction through the actual movement motor.
const std = @import("std");
const move = @import("player_move.zig");
const slide = @import("../../core/domain/slide.zig");
const collision = @import("../../core/domain/collision.zig");
const v = @import("../../core/domain/vector.zig");
pub const Landing = struct { safe: bool, position: v.Vec3 };
/// A rising transfer must leave less than one ordinary step to its landing.
/// The usual vertical tolerance alone admits landing back below a 24-unit lip.
pub fn landingHeight(start: f32, destination: f32, landed: f32) bool {
    return @abs(landed - destination) <= 24 and (destination <= start + 18 or landed >= destination - 8);
}
/// A jump uses the same feedback stroke during qualification and execution.
/// Brake near the destination instead of carrying a full run off a narrow lip.
pub fn jumpInput(motion: slide.State, destination: v.Vec3, time_ms: i64, launch: bool, crouch: bool) move.Command {
    const delta = v.subtract(destination, motion.position);
    const flat: v.Vec3 = .{ motion.velocity[0], motion.velocity[1], 0 };
    const speed = v.length(flat);
    const brake = !launch and v.dot(flat, delta) > 0 and @sqrt(delta[0] * delta[0] + delta[1] * delta[1]) < speed * 0.2;
    // Correct the predicted overshoot in both axes. Reversing velocity alone
    // cancels the lateral alignment still needed to reach a narrow landing.
    const toward = if (brake) v.subtract(.{ delta[0], delta[1], 0 }, v.scale(flat, 0.3)) else delta;
    return .{ .time_ms = time_ms, .angles = .{ 0, std.math.atan2(toward[1], toward[0]) * 180 / std.math.pi, 0 }, .forward = 127, .up = if (launch) 127 else if (crouch) -127 else 0 };
}

/// Track a sampled moving landing at the remaining ballistic arrival time.
/// Correct the landing error left by current momentum before the body reaches
/// the lip; a distance-only brake can start after air control can recover.
pub fn landingInput(motion: slide.State, destination: v.Vec3, seconds: f32, time_ms: i64, crouch: bool) move.Command {
    const remaining = std.math.clamp(seconds, 0.05, 2);
    const delta = v.subtract(destination, motion.position);
    const correction: v.Vec3 = .{ delta[0] - motion.velocity[0] * remaining, delta[1] - motion.velocity[1] * remaining, 0 };
    return .{ .time_ms = time_ms, .angles = .{ 0, std.math.atan2(correction[1], correction[0]) * 180 / std.math.pi, 0 }, .forward = if (v.length(correction) > 0.5) 127 else 0, .up = if (crouch) -127 else 0 };
}

test "remaining flight time brakes an inertial landing before a distance-only stroke overshoots" {
    const Fixture = struct {
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
        fn land(corrected: bool) !f32 {
            var context: u8 = 0;
            const service: collision.Collision = .{ .context = &context, .trace_fn = trace, .contents_fn = contents };
            const parameters: move.Parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .speed = 320, .gravity = 800, .mins = .{ -15, -15, -24 }, .maxs = .{ 15, 15, 32 }, .snap_velocity = false };
            var player: move.Player = .{ .command_ms = 1000 };
            var motion: slide.State = .{ .position = .{ 0, 0, 64 }, .velocity = .{ 400, 0, 0 } };
            const goal: v.Vec3 = .{ 104, 0, 24 };
            for (0..20) |_| {
                const discriminant = motion.velocity[2] * motion.velocity[2] + 2 * parameters.gravity * (motion.position[2] - goal[2]);
                const remaining = (motion.velocity[2] + @sqrt(@max(0, discriminant))) / parameters.gravity;
                const input = if (corrected) landingInput(motion, goal, remaining, player.command_ms + 50, false) else jumpInput(motion, goal, player.command_ms + 50, false, false);
                _ = try move.run(&player, &motion, input, parameters, service);
                if (player.ground_entity != 2047) return motion.position[0];
            }
            return error.NoLanding;
        }
    };
    const before = try Fixture.land(false);
    const after = try Fixture.land(true);
    if (@abs(after - 104) > 16 or @abs(before - 104) <= 16) std.debug.print("inertial landing: before={d} after={d}\n", .{ before, after });
    try std.testing.expect(@abs(after - 104) <= 16);
    try std.testing.expect(@abs(before - 104) > 16);
    try std.testing.expectEqual(@as(i8, 0), landingInput(.{ .position = @splat(0), .velocity = .{ 400, 0, 0 } }, .{ 200, 0, 0 }, 0.5, 1000, false).forward);
}

/// Qualify a complete jump and stopped landing with the traveller's motor.
/// A harmless landing on a lower floor does not qualify the requested ledge.
pub fn jumpArrival(player: move.Player, initial: slide.State, destination: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, volumes: []const Bounds, crouch: bool) !Landing {
    return jumpFrames(player, initial, destination, parameters, service, forbidden, volumes, crouch, &.{});
}
pub const JumpFrame = struct { valid: bool = false, time_ms: i64 = 0, position: v.Vec3 = @splat(0), velocity: v.Vec3 = @splat(0), ground: u16 = 2047, input: move.Command = .{ .time_ms = 0, .angles = @splat(0) } };
/// Optional read-only trajectory evidence for comparing prediction to live input.
pub fn jumpFrames(player: move.Player, initial: slide.State, destination: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, volumes: []const Bounds, crouch: bool, frames: []JumpFrame) !Landing {
    var state = player;
    var motion = initial;
    var departed = false;
    var resting: usize = 0;
    for (0..32) |tick| {
        const before = motion.position;
        var input = jumpInput(motion, destination, player.command_ms + @as(i64, @intCast(tick + 1)) * 50, tick == 0, crouch);
        if (departed and resting > 0) {
            input.forward = 0;
            input.right = 0;
        }
        const moved = try move.run(&state, &motion, input, parameters, service);
        if (tick < frames.len) frames[tick] = .{ .valid = true, .time_ms = state.command_ms, .position = motion.position, .velocity = motion.velocity, .ground = state.ground_entity, .input = input };
        for (volumes) |box| {
            var overlaps = true;
            for (0..3) |axis| if (@max(before[axis], motion.position[axis]) + moved.maxs[axis] <= box.mins[axis] or @min(before[axis], motion.position[axis]) + moved.mins[axis] >= box.maxs[axis]) {
                overlaps = false;
            };
            if (overlaps) return .{ .safe = false, .position = motion.position };
        }
        if (try service.contents(v.add(motion.position, .{ 0, 0, parameters.mins[2] + 1 }), parameters.slot) & forbidden != 0) return .{ .safe = false, .position = motion.position };
        departed = departed or state.ground_entity == 2047;
        resting = if (state.ground_entity != 2047 and motion.velocity[2] <= 0) resting + 1 else 0;
        if (departed and resting >= 4) return .{ .safe = landingHeight(initial.position[2], destination[2], motion.position[2]) and @import("../../core/domain/navigation.zig").horizontalDistance(motion.position, destination) <= 40, .position = motion.position };
    }
    return .{ .safe = false, .position = motion.position };
}
pub const Bounds = @import("../../core/domain/navigation_input.zig").Bounds;
test "a jump onto a raised floor cannot qualify by landing below its lip" {
    try std.testing.expect(!landingHeight(1928, 1952, 1928.125));
    try std.testing.expect(landingHeight(1928, 1952, 1952.125));
    try std.testing.expect(landingHeight(1928, 1952, 1948));
    try std.testing.expect(landingHeight(64, 64, 64.125));
    try std.testing.expect(landingHeight(128, 64, 64.125));
    try std.testing.expect(!landingHeight(64, 64, 98));
}
pub const Field = struct {
    /// Match the collision world's surface separation rather than adding a
    /// whole unit to a point contact's already body-expanded bounds.
    pub const contact_margin: f32 = 0.125;
    point: v.Vec3,
    radius: f32,
    bounds: ?Bounds = null,
    /// Raw contact volume, before expansion by the moving body's current hull.
    contact: ?Bounds = null,
    pub fn forHull(self: Field, mins: v.Vec3, maxs: v.Vec3) Field {
        var result = self;
        if (self.contact) |box| result.bounds = .{ .mins = v.subtract(v.subtract(box.mins, maxs), @splat(contact_margin)), .maxs = v.add(v.subtract(box.maxs, mins), @splat(contact_margin)) };
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
    return walkArrival(player, initial, destination, parameters, service, forbidden, volumes, fields, null, 32, false, 24);
}
/// A route explicitly descending a ledge may admit a bounded small drop.
/// Liquids, trigger volumes, motor support and stopped arrival remain checked.
pub fn walkDrop(player: move.Player, initial: slide.State, destination: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, volumes: []const Bounds, fields: []const Field, max_drop: f32) !Walk {
    return walkArrival(player, initial, destination, parameters, service, forbidden, volumes, fields, null, std.math.clamp(max_drop, 32, 64), false, 24);
}
/// Qualify the normal navigation arrival disk, rather than a precise takeoff.
/// The feedback stroke and all support/contact checks remain the same.
pub fn walkNearDrop(player: move.Player, initial: slide.State, destination: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, volumes: []const Bounds, fields: []const Field, max_drop: f32) !Walk {
    return walkArrival(player, initial, destination, parameters, service, forbidden, volumes, fields, destination, std.math.clamp(max_drop, 32, 64), true, 24);
}
/// Qualify a supported stance on the requested tread. A navigation arrival
/// disk alone can accept the preceding stair before the motor moves at all.
pub fn walkFootingDrop(player: move.Player, initial: slide.State, destination: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, volumes: []const Bounds, fields: []const Field, max_drop: f32) !Walk {
    return walkArrival(player, initial, destination, parameters, service, forbidden, volumes, fields, destination, std.math.clamp(max_drop, 32, 64), false, 8);
}
/// Reach a takeoff without braking to a stop there. The returned state carries
/// the real running velocity into a subsequent jump qualification.
pub fn walkThrough(player: move.Player, initial: slide.State, takeoff: v.Vec3, direction: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, volumes: []const Bounds) !Walk {
    return walkArrival(player, initial, v.add(takeoff, v.scale(direction, 48)), parameters, service, forbidden, volumes, &.{}, takeoff, 32, false, 24);
}
fn walkArrival(player: move.Player, initial: slide.State, destination: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, volumes: []const Bounds, fields: []const Field, arrival: ?v.Vec3, max_drop: f32, swimming_arrival: bool, arrival_height: f32) !Walk {
    var result: Walk = .{ .position = initial.position };
    const span = v.length(v.subtract(destination, initial.position));
    if (span > 320 or parameters.speed <= 0) return result;
    var state = player;
    var motion = initial;
    var grounded_z = initial.position[2];
    var supported_z = initial.position[2];
    var stair_support = player.ground_entity != 2047;
    const first_ms = state.command_ms + 50;
    // A short lateral correction can first need to shed running momentum.
    // Distance alone must not give it less time than a longer straight walk.
    const ticks: usize = @intFromFloat(@min(100, @max(32, @ceil(span / (parameters.speed * 0.025)) + @as(f32, if (arrival != null) 32 else 12))));
    for (0..ticks) |tick| {
        const before = motion.position;
        var body_maxs = parameters.maxs;
        if (state.ducked) body_maxs[2] = 4;
        const terminal = v.subtract(arrival orelse destination, before);
        const terminal_span = @sqrt(terminal[0] * terminal[0] + terminal[1] * terminal[1]);
        if (terminal_span <= @as(f32, if (arrival != null) 16 else 2) and @abs(terminal[2]) <= arrival_height) {
            var clear = true;
            for (fields) |field| if (field.forHull(parameters.mins, body_maxs).distance(before) < 0) {
                clear = false;
            };
            if (try service.contents(v.add(before, .{ 0, 0, parameters.mins[2] + 1 }), parameters.slot) & forbidden != 0) return .{ .position = before, .reason = .liquid };
            const support = try service.trace(.{ .start = before, .end = v.add(before, .{ 0, 0, -2 }), .mins = parameters.mins, .maxs = body_maxs, .slot = parameters.slot, .mask = parameters.mask });
            // A wading path can end afloat over its shallow supporting floor.
            // Navigation may arrive there; a running jump takeoff may not.
            const swimming = swimming_arrival and state.water_level >= 2;
            if (clear and (swimming or (!support.start_solid and !support.all_solid and support.fraction < 1 and support.normal[2] >= 0.7))) return .{ .safe = true, .position = before, .velocity = motion.velocity, .player = state, .reason = .reached };
        }
        const input = try walkInput(before, destination, first_ms + @as(i64, @intCast(tick)) * 50, parameters, service);
        const moved = try move.run(&state, &motion, input, parameters, service);
        result.position = motion.position;
        result.reason = .drop;
        if (before[2] - motion.position[2] > max_drop or grounded_z - motion.position[2] > max_drop) return result;
        const support = try service.trace(.{ .start = motion.position, .end = v.add(motion.position, .{ 0, 0, -max_drop - 0.25 }), .mins = moved.mins, .maxs = moved.maxs, .slot = parameters.slot, .mask = parameters.mask });
        result.reason = .support;
        result.normal = support.normal[2];
        // A transient bevel contact need not be a standing floor. Only a
        // complete motor rollout ending on walkable support authorizes it.
        const climbing = support.normal[2] > 0.15;
        if (support.start_solid or support.all_solid or support.fraction == 1 or (support.normal[2] < 0.7 and !climbing)) return result;
        // Keep continuous stair-height support while descending. The motor
        // can briefly be airborne over successive treads. Once support falls
        // farther away, retain the entire fall until actual ground contact;
        // seeing the bottom of a deep drop later must not renew its budget.
        stair_support = stair_support and supported_z - support.end[2] <= 22 and support.normal[2] >= 0.7;
        supported_z = support.end[2];
        if (state.ground_entity != 2047 and support.normal[2] >= 0.7) stair_support = true;
        if (stair_support) grounded_z = motion.position[2];
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
        const straight = try walkArrival(player, initial, end, parameters, service, forbidden, volumes, fields, destination, 32, false, 24);
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
            const second = try walkArrival(first.player, .{ .position = first.position, .velocity = first.velocity }, end, parameters, service, forbidden, volumes, fields, destination, 32, false, 24);
            if (!second.safe or v.length(v.subtract(second.position, destination)) > 16) continue;
            best = corner;
            cost = rank;
        }
    }
    return best;
}

pub fn landing(player: move.Player, initial: slide.State, command: move.Command, parameters: move.Parameters, service: collision.Collision, forbidden: u32) !Landing {
    return landingDrop(player, initial, command, parameters, service, forbidden, std.math.inf(f32));
}
/// Forecast an uncommitted impulse with the same motor and braking as travel.
/// A safe floor far below does not preserve the firing stand's route.
pub fn impulseLanding(player: move.Player, initial: slide.State, command: move.Command, impulse: v.Vec3, parameters: move.Parameters, service: collision.Collision, forbidden: u32, max_drop: f32) !Landing {
    var kicked = initial;
    kicked.velocity = v.add(kicked.velocity, impulse);
    return landingDrop(player, kicked, command, parameters, service, forbidden, max_drop);
}
fn landingDrop(player: move.Player, initial: slide.State, command: move.Command, parameters: move.Parameters, service: collision.Collision, forbidden: u32, max_drop: f32) !Landing {
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
        // A grounded walking command lasts one motor frame before replanning.
        // Forecast stopping after that stride, rather than a held run down
        // several additional stair treads beyond the requested drop.
        if ((tick > 0 and player.ground_entity != 2047 and command.up <= 0) or (departed and resting > 0)) {
            input.forward = 0;
            input.right = 0;
        }
        _ = try move.run(&state, &motion, input, parameters, service);
        if (initial.position[2] - motion.position[2] > max_drop) return .{ .safe = false, .position = motion.position };
        const feet = v.add(motion.position, .{ 0, 0, parameters.mins[2] + 1 });
        if (try service.contents(feet, parameters.slot) & forbidden != 0) return .{ .safe = false, .position = motion.position };
        departed = departed or state.ground_entity == 2047;
        resting = if (state.ground_entity != 2047) resting + 1 else 0;
        // No input is a request to stop. Transient ground contacts while
        // coasting over stair facets do not prove that this stance can hold.
        const stopping = command.forward == 0 and command.right == 0;
        if (resting >= 4 and (!stopping or @sqrt(motion.velocity[0] * motion.velocity[0] + motion.velocity[1] * motion.velocity[1]) <= 48)) return .{ .safe = true, .position = motion.position };
    }
    return .{ .safe = false, .position = motion.position };
}

/// Keep a safe proposed takeoff/air stroke. Otherwise compare physical braking,
/// cancelling a takeoff and lateral strokes; no simulated pose is committed.
pub fn protect(player: move.Player, motion: slide.State, proposed: move.Command, parameters: move.Parameters, service: collision.Collision, forbidden: u32, goal: ?v.Vec3) !move.Command {
    return protectDrop(player, motion, proposed, parameters, service, forbidden, goal, std.math.inf(f32));
}
/// A follower's raised approach must retain its floor, even when the lower
/// landing would cause no damage. Authored descents supply their own allowance.
pub fn protectDrop(player: move.Player, motion: slide.State, proposed: move.Command, parameters: move.Parameters, service: collision.Collision, forbidden: u32, goal: ?v.Vec3, max_drop: f32) !move.Command {
    // All alternatives observe the same uncommitted world and probe ownership.
    // Stuck motors otherwise repeat the complete separating-plane search for
    // each future tick and alternative, even at identical positions.
    var memo: @import("../../core/domain/collision_memo.zig").Memo = .{ .backend = service };
    const queries = memo.service();
    return protectQueriesDrop(player, motion, proposed, parameters, queries, forbidden, goal, max_drop);
}

test "a stopped command cannot admit a coasting ledge contact as a settled landing" {
    const Floor = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            const height: f32 = if (request.end[0] <= 80) 0 else -256;
            const a = request.start[2] + request.mins[2] - height;
            const b = request.end[2] + request.mins[2] - height;
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
        }
        fn contents(_: *anyopaque, point: v.Vec3, _: u16) !u32 {
            return if (point[0] > 80 and point[2] < -8) 2 else 0;
        }
        fn dryContents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var context: u8 = 0;
    const service: collision.Collision = .{ .context = &context, .trace_fn = Floor.trace, .contents_fn = Floor.contents };
    const parameters: move.Parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .speed = 300, .snap_velocity = false };
    const player: move.Player = .{ .command_ms = 950, .ground_entity = 2046, .timer = .knockback, .timer_ms = 500 };
    const motion: slide.State = .{ .position = .{ 0, 0, 24 }, .velocity = .{ 200, 0, 0 } };
    const stopped: move.Command = .{ .time_ms = 1000, .angles = @splat(0) };
    try std.testing.expect(!(try landing(player, motion, stopped, parameters, service, 2)).safe);
    const guarded = try protect(player, motion, stopped, parameters, service, 2, motion.position);
    try std.testing.expect(guarded.forward < 0);
    try std.testing.expect((try landing(player, motion, guarded, parameters, service, 2)).safe);
    // A harmless floor a storey below is still the wrong navigation landing.
    var dry = service;
    dry.contents_fn = Floor.dryContents;
    const falling: slide.State = .{ .position = .{ 100, 0, 80 }, .velocity = @splat(0) };
    const airborne: move.Player = .{ .command_ms = 950 };
    try std.testing.expect((try landing(airborne, falling, stopped, parameters, dry, 0)).safe);
    try std.testing.expect(!(try landingDrop(airborne, falling, stopped, parameters, dry, 0, 32)).safe);
    // A launch kick can leave a harmless but much lower floor. Qualification
    // must distinguish that lost firing stand from a kick across broad floor.
    const still: slide.State = .{ .position = .{ 70, 0, 24 }, .velocity = @splat(0) };
    try std.testing.expect(!(try impulseLanding(.{ .command_ms = 950, .ground_entity = 2046 }, still, stopped, .{ 400, 0, 0 }, parameters, dry, 0, 48)).safe);
    const wide: slide.State = .{ .position = .{ -256, 0, 24 }, .velocity = @splat(0) };
    try std.testing.expect((try impulseLanding(.{ .command_ms = 950, .ground_entity = 2046 }, wide, stopped, .{ 400, 0, 0 }, parameters, dry, 0, 48)).safe);
}

fn protectQueries(player: move.Player, motion: slide.State, proposed: move.Command, parameters: move.Parameters, queries: collision.Collision, forbidden: u32, goal: ?v.Vec3) !move.Command {
    return protectQueriesDrop(player, motion, proposed, parameters, queries, forbidden, goal, std.math.inf(f32));
}
fn protectQueriesDrop(player: move.Player, motion: slide.State, proposed: move.Command, parameters: move.Parameters, queries: collision.Collision, forbidden: u32, goal: ?v.Vec3, max_drop: f32) !move.Command {
    if ((try landingDrop(player, motion, proposed, parameters, queries, forbidden, max_drop)).safe) return proposed;
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
        const result = try landingDrop(player, motion, input, parameters, queries, forbidden, max_drop);
        if (!result.safe) continue;
        const cost = v.length(v.subtract(result.position, goal orelse motion.position));
        if (cost < score) {
            best = input;
            score = cost;
        }
    }
    return best;
}

test "a walking stride brakes on descending stairs without forecasting a held run down the flight" {
    const Stairs = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            const height = -16 * @max(0, @floor(request.end[0] / 16));
            const a = request.start[2] + request.mins[2] - height;
            const b = request.end[2] + request.mins[2] - height;
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var context: u8 = 0;
    const service: collision.Collision = .{ .context = &context, .trace_fn = Stairs.trace, .contents_fn = Stairs.contents };
    const parameters: move.Parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .speed = 200, .snap_velocity = false };
    const player: move.Player = .{ .command_ms = 950, .ground_entity = 2046 };
    const motion: slide.State = .{ .position = .{ 0, 0, 24.125 }, .velocity = @splat(0) };
    const command: move.Command = .{ .time_ms = 1000, .angles = @splat(0), .forward = 127 };
    try std.testing.expect((try landingDrop(player, motion, command, parameters, service, 2, 24)).safe);
    const tread: v.Vec3 = .{ 24, 0, 8.125 };
    const nearby = try walkNearDrop(player, motion, tread, parameters, service, 2, &.{}, &.{}, 32);
    try std.testing.expect(nearby.safe and nearby.position[2] == motion.position[2]);
    const footing = try walkFootingDrop(player, motion, tread, parameters, service, 2, &.{}, &.{}, 32);
    try std.testing.expect(footing.safe and footing.position[2] < motion.position[2] - 8);
    // Momentum still has to stop within the same descent budget.
    var fast = motion;
    fast.velocity = .{ 300, 0, 0 };
    try std.testing.expect(!(try landingDrop(player, fast, command, parameters, service, 2, 24)).safe);
}

test "normal ground arrival can stop on supported footing inside its disk without crossing a hazard" {
    const Floor = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            const height: f32 = if (request.end[0] < 96) 0 else -128;
            const a = request.start[2] + request.mins[2] - height;
            const b = request.end[2] + request.mins[2] - height;
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
    const parameters: move.Parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .speed = 128, .snap_velocity = false };
    const player: move.Player = .{ .command_ms = 950, .ground_entity = 2046 };
    const initial: slide.State = .{ .position = .{ 0, 0, 24.125 }, .velocity = @splat(0) };
    const goal: v.Vec3 = .{ 100, 0, 24.125 };
    const near = try walkNearDrop(player, initial, goal, parameters, service, 2, &.{}, &.{}, 32);
    try std.testing.expect(near.safe and near.position[0] >= 84 and near.position[0] < 96);
    try std.testing.expect(!(try walkDrop(player, initial, goal, parameters, service, 2, &.{}, &.{}, 32)).safe);
    const hazard = [_]Bounds{.{ .mins = .{ 48, -32, 0 }, .maxs = .{ 56, 32, 128 } }};
    try std.testing.expect(!(try walkNearDrop(player, initial, goal, parameters, service, 2, &hazard, &.{}, 32)).safe);
    var swimmer = player;
    swimmer.water_level = 2;
    const afloat: slide.State = .{ .position = .{ 100, 0, 40 }, .velocity = @splat(0) };
    try std.testing.expect((try walkNearDrop(swimmer, afloat, goal, parameters, service, 2, &.{}, &.{}, 32)).safe);
    try std.testing.expect(!(try walkDrop(swimmer, afloat, goal, parameters, service, 2, &.{}, &.{}, 32)).safe);
}

test "local jumps require the requested ledge and reject harmless lower-floor landings" {
    const Floor = struct {
        landing_height: f32 = 0,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const height: f32 = if (request.end[0] < 48) 0 else if (request.end[0] >= 144) self.landing_height else -160;
            const a = request.start[2] + request.mins[2] - height;
            const b = request.end[2] + request.mins[2] - height;
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var fixture: Floor = .{};
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Floor.trace, .contents_fn = Floor.contents };
    const parameters: move.Parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .speed = 300, .snap_velocity = false };
    const player: move.Player = .{ .command_ms = 950, .ground_entity = 2046 };
    const motion: slide.State = .{ .position = .{ 0, 0, 24.125 }, .velocity = .{ 280, 0, 0 } };
    const target: v.Vec3 = .{ 180, 0, 24.125 };
    const crossing: slide.State = .{ .position = motion.position, .velocity = .{ 0, -225, 0 } };
    try std.testing.expect((try walk(player, crossing, .{ 32, 0, 24.125 }, parameters, service, 2, &.{}, &.{})).safe);
    const runup = try walkThrough(player, motion, .{ 32, 0, 24.125 }, .{ 1, 0, 0 }, parameters, service, 2, &.{});
    try std.testing.expect(runup.safe and runup.velocity[0] > 200);
    try std.testing.expect(runup.player.command_ms > player.command_ms);
    try std.testing.expect(!(try walkThrough(player, motion, .{ 100, 0, 24.125 }, .{ 1, 0, 0 }, parameters, service, 2, &.{})).safe);
    try std.testing.expect((try jumpArrival(player, motion, target, parameters, service, 2, &.{}, false)).safe);
    fixture.landing_height = -128;
    try std.testing.expect(!(try jumpArrival(player, motion, target, parameters, service, 2, &.{}, false)).safe);
    fixture.landing_height = 0;
    const hazard = [_]Bounds{.{ .mins = .{ 65, -32, 0 }, .maxs = .{ 120, 32, 128 } }};
    try std.testing.expect(!(try jumpArrival(player, motion, target, parameters, service, 2, &hazard, false)).safe);
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

test "typed small descents retain motor and hazard checks without authorizing deep drops" {
    const Floor = struct {
        depth: f32 = 40,
        harmful: bool = false,
        shallow_water: bool = false,
        stairs: bool = false,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const height: f32 = if (self.stairs) -@floor(@max(0, request.end[0]) / 32) * 16 else if (request.end[0] < 48) 0 else -self.depth;
            const a = request.start[2] + request.mins[2] - height;
            const b = request.end[2] + request.mins[2] - height;
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
        }
        fn contents(raw: *anyopaque, point: v.Vec3, _: u16) !u32 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (self.harmful and point[0] >= 48) return 2;
            return if (self.shallow_water and point[0] >= 48 and point[2] < -34) 4 else 0;
        }
    };
    var fixture: Floor = .{};
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Floor.trace, .contents_fn = Floor.contents };
    const parameters: move.Parameters = .{ .slot = 0, .mask = 1, .water_mask = 4, .solid_mask = 1, .speed = 128, .mins = .{ -8, -8, -10 }, .maxs = .{ 8, 8, 4 }, .snap_velocity = false };
    const player: move.Player = .{ .command_ms = 0, .ground_entity = 2046 };
    const motion: slide.State = .{ .position = .{ 0, 0, 10.125 }, .velocity = @splat(0) };
    const goal: v.Vec3 = .{ 128, 0, -29.875 };
    try std.testing.expect(!(try walk(player, motion, goal, parameters, service, 2, &.{}, &.{})).safe);
    try std.testing.expect((try walkDrop(player, motion, goal, parameters, service, 2, &.{}, &.{}, 64)).safe);
    fixture.harmful = true;
    try std.testing.expect(!(try walkDrop(player, motion, goal, parameters, service, 2, &.{}, &.{}, 64)).safe);
    fixture.harmful = false;
    fixture.shallow_water = true;
    try std.testing.expect((try walkDrop(player, motion, goal, parameters, service, 2, &.{}, &.{}, 64)).safe);
    try std.testing.expect(!(try walkDrop(player, motion, goal, parameters, service, 6, &.{}, &.{}, 64)).safe);
    fixture.shallow_water = false;
    fixture.stairs = true;
    const stair_walk = try walk(player, motion, .{ 144, 0, -53.875 }, parameters, service, 2, &.{}, &.{});
    if (!stair_walk.safe) std.debug.print("stair walk: reason={s} position={any}\n", .{ @tagName(stair_walk.reason), stair_walk.position });
    try std.testing.expect(stair_walk.safe);
    fixture.stairs = false;
    fixture.depth = 128;
    try std.testing.expect(!(try walkDrop(player, motion, .{ 128, 0, -117.875 }, parameters, service, 2, &.{}, &.{}, 1000)).safe);
}
test "contact fields use the actual body-space box and admit a physically clear detour" {
    const contact: Field = .{ .point = @splat(0), .radius = 32, .contact = .{ .mins = @splat(0), .maxs = @splat(0) } };
    const expanded = contact.forHull(@splat(-16), @splat(16));
    // Physical contact and the collision tolerance remain forbidden. A
    // quarter-unit separation must not acquire an extra unit of obstruction.
    try std.testing.expect(expanded.distance(.{ 16, 0, 0 }) < 0);
    try std.testing.expect(expanded.distance(.{ 16.25, 0, 0 }) > 0);
    try std.testing.expect(expanded.crosses(.{ 20, 0, 0 }, .{ 16, 0, 0 }));
    try std.testing.expect(!expanded.crosses(.{ 20, 0, 0 }, .{ 16.25, 0, 0 }));
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
