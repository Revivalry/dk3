// SPDX-License-Identifier: GPL-2.0-or-later
//! Differential command replays against bundled GPL movement, using identical traces.
const std = @import("std");
const abi = @import("../engine/abi.zig");
const c = abi.c;
const bridge = @import("../mechanics/player_state.zig");
const move = @import("../mechanics/domain/player_move.zig");
const collision = @import("../core/domain/collision.zig");
const v = @import("../core/domain/vector.zig");
extern fn reference_move(*c.playerState_t, c.usercmd_t, *const fn ([*c]c.trace_t, [*c]const f32, [*c]const f32, [*c]const f32, [*c]const f32, c_int, c_int) callconv(.c) void, *const fn ([*c]const f32, c_int) callconv(.c) c_int) void;
fn plane(start: v.Vec3, mins: v.Vec3, end: v.Vec3) collision.Trace {
    const a = start[2] + mins[2];
    const b = end[2] + mins[2];
    if (a < 0) return .{ .fraction = 0, .end = start, .normal = .{ 0, 0, 1 }, .start_solid = true, .all_solid = b < 0, .entity = 2046 };
    if (b >= 0) return .{ .fraction = 1, .end = end, .normal = .{ 0, 0, 1 } };
    const fraction = a / (a - b);
    return .{ .fraction = fraction, .end = v.add(start, v.scale(v.add(end, v.scale(start, -1)), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
}
fn referenceTrace(out: [*c]c.trace_t, start: [*c]const f32, mins: [*c]const f32, _: [*c]const f32, end: [*c]const f32, _: c_int, _: c_int) callconv(.c) void {
    const hit = plane(start[0..3].*, mins[0..3].*, end[0..3].*);
    out[0] = std.mem.zeroes(c.trace_t);
    out[0].fraction = hit.fraction;
    out[0].endpos = hit.end;
    out[0].plane.normal = hit.normal;
    out[0].allsolid = @intFromBool(hit.all_solid);
    out[0].startsolid = @intFromBool(hit.start_solid);
    out[0].entityNum = hit.entity;
}
var water_surface: ?f32 = null;
fn referenceContents(point: [*c]const f32, _: c_int) callconv(.c) c_int {
    return if (water_surface) |surface| (if (point[2] < surface) c.CONTENTS_WATER else 0) else 0;
}
fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
    return plane(request.start, request.mins, request.end);
}
fn contents(_: *anyopaque, point: v.Vec3, _: u16) !u32 {
    return @intCast(referenceContents(&point, 0));
}
const WaterLedge = struct {
    upper_contents: u32,
    fn sample(raw: *anyopaque, point: v.Vec3, _: u16) !u32 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (point[0] >= 20) return if (point[2] < 8) c.CONTENTS_SOLID else self.upper_contents;
        return if (point[2] < 16) c.CONTENTS_WATER else 0;
    }
    fn openTrace(_: *anyopaque, request: collision.Request) !collision.Trace {
        return .{ .fraction = 1, .end = request.end, .normal = .{ 0, 0, 1 } };
    }
};
const SubmergedStep = struct {
    height: f32,
    ladder_face: bool = false,
    ceiling: ?f32 = null,
    fn traceStep(raw: *anyopaque, request: collision.Request) !collision.Trace {
        const self: *@This() = @ptrCast(@alignCast(raw));
        var hit = self.stepOnly(request);
        if (self.ladder_face and hit.normal[0] < -0.5) hit.ladder = true;
        if (self.ceiling) |ceiling| {
            const a = ceiling - request.start[2] - request.maxs[2];
            const b = ceiling - request.end[2] - request.maxs[2];
            if (a < 0) return .{ .fraction = 0, .end = request.start, .normal = @splat(0), .start_solid = true, .all_solid = b < 0, .entity = 2046 };
            if (b < 0 and b < a) {
                const fraction = @max(0, (a - 0.001) / (a - b));
                if (fraction < hit.fraction) hit = .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, -1 }, .entity = 2046 };
            }
        }
        return hit;
    }
    fn stepOnly(self: *const @This(), request: collision.Request) collision.Trace {
        var hit = plane(request.start, request.mins, request.end);
        // A raised half-floor: x >= 64, z <= height, expanded by the hull.
        const starts = [2]f32{ 64 - request.maxs[0] - request.start[0], request.start[2] + request.mins[2] - self.height };
        const ends = [2]f32{ 64 - request.maxs[0] - request.end[0], request.end[2] + request.mins[2] - self.height };
        var enter: f32 = 0;
        var leave: f32 = 1;
        var normal: v.Vec3 = @splat(0);
        var inside = true;
        for (starts, ends, 0..) |a, b, axis| {
            if (a > 0) inside = false;
            if (a > 0 and b >= a) return hit;
            if (a <= 0 and b <= 0) continue;
            if (a > b) {
                const fraction = @max(0, (a - 0.001) / (a - b));
                if (fraction >= enter) {
                    enter = fraction;
                    normal = if (axis == 0) .{ -1, 0, 0 } else .{ 0, 0, 1 };
                }
            } else leave = @min(leave, (a + 0.001) / (a - b));
        }
        if (inside) return .{ .fraction = 0, .end = request.start, .normal = @splat(0), .start_solid = true, .all_solid = ends[0] <= 0 and ends[1] <= 0, .entity = 2046 };
        if (enter <= leave and enter < hit.fraction) hit = .{ .fraction = enter, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), enter)), .normal = normal, .entity = 2046 };
        return hit;
    }
    fn water(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
        return c.CONTENTS_WATER;
    }
};
test "crouched ladder dismount steps into a low duct without crossing a solid wall" {
    var parameters = bridge.parameters(0);
    parameters.fixed_ms = 16;
    parameters.snap_velocity = false;
    for ([_]bool{ false, true }) |strafe| for ([_]bool{ false, true }) |blocked| {
        var fixture: SubmergedStep = .{ .height = if (blocked) 256 else 48, .ladder_face = true, .ceiling = if (blocked) null else 84 };
        const service: collision.Collision = .{ .context = &fixture, .trace_fn = SubmergedStep.traceStep, .contents_fn = IcePlane.dry };
        var player: move.Player = .{};
        var motion: @import("../core/domain/slide.zig").State = .{ .position = .{ 48, 0, 66 }, .velocity = @splat(0) };
        for (1..65) |frame| _ = try move.run(&player, &motion, .{
            .time_ms = @intCast(frame * 16),
            .angles = .{ 0, if (strafe) 90 else 0, 0 },
            .forward = if (strafe) 0 else 127,
            .right = if (strafe) 127 else 0,
            .up = -127,
        }, parameters, service);
        if (blocked) {
            try std.testing.expect(motion.position[0] <= 49.01);
            try std.testing.expect(motion.position[2] < 66);
        } else {
            try std.testing.expect(motion.position[0] > 64);
            try std.testing.expectApproxEqAbs(@as(f32, 72), motion.position[2], 0.1);
            try std.testing.expect(player.ducked);
        }
    };
}
const IcePlane = struct {
    slope: bool = false,
    icy: bool = true,
    fn dry(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
        return 0;
    }
    fn sweep(raw: *anyopaque, request: collision.Request) !collision.Trace {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (!self.slope) {
            var hit = plane(request.start, request.mins, request.end);
            hit.slick = self.icy;
            return hit;
        }
        const a = request.start[2] - request.start[1] + request.mins[2] - request.maxs[1];
        const b = request.end[2] - request.end[1] + request.mins[2] - request.maxs[1];
        const normal: v.Vec3 = .{ 0, -@sqrt(@as(f32, 0.5)), @sqrt(@as(f32, 0.5)) };
        if (a < -0.001) return .{ .fraction = 0, .end = request.start, .normal = normal, .start_solid = true, .all_solid = b < -0.001, .entity = 2046, .slick = self.icy };
        if (b >= 0 or b >= a) return .{ .fraction = 1, .end = request.end, .normal = normal };
        const fraction = @max(0, (a - 0.001) / (a - b));
        return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = normal, .entity = 2046, .slick = self.icy };
    }
};
test "authored ice supports low-speed footing on slopes and preserves a fast slide" {
    var parameters = bridge.parameters(0);
    parameters.fixed_ms = 16;
    parameters.snap_velocity = false;
    var fixture: IcePlane = .{ .slope = true };
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = IcePlane.sweep, .contents_fn = IcePlane.dry };
    var player: move.Player = .{};
    var motion: @import("../core/domain/slide.zig").State = .{ .position = .{ 0, 0, 39.125 }, .velocity = @splat(0) };
    for (1..33) |frame| _ = try move.run(&player, &motion, .{ .time_ms = @intCast(frame * 16), .angles = .{ 0, 90, 0 } }, parameters, service);
    try std.testing.expect(v.length(motion.velocity) < 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), motion.position[1], 0.01);
    for (33..65) |frame| _ = try move.run(&player, &motion, .{ .time_ms = @intCast(frame * 16), .angles = .{ 0, 90, 0 }, .forward = 127 }, parameters, service);
    try std.testing.expect(motion.position[1] > 20 and motion.position[2] > 59);
    try std.testing.expectEqual(@as(u16, 2046), player.ground_entity);
    fixture.slope = false;
    for ([_]f32{ 100, 300 }) |speed| {
        player = .{};
        motion = .{ .position = .{ 0, 0, 24.125 }, .velocity = .{ speed, 0, 0 } };
        for (1..65) |frame| _ = try move.run(&player, &motion, .{ .time_ms = @intCast(frame * 16), .angles = @splat(0) }, parameters, service);
        if (speed < 170) try std.testing.expect(motion.position[0] < 15) else try std.testing.expect(motion.position[0] > 250);
    }
}
test "a crouched swimmer crosses a submerged sill but cannot climb a high wall" {
    for ([_]f32{ 8, 24 }) |height| {
        var fixture: SubmergedStep = .{ .height = height };
        var player: move.Player = .{};
        var motion: @import("../core/domain/slide.zig").State = .{ .position = .{ 0, 0, 24.125 }, .velocity = @splat(0) };
        var parameters = bridge.parameters(0);
        parameters.fixed_ms = 16;
        parameters.snap_velocity = false;
        const service: collision.Collision = .{ .context = &fixture, .trace_fn = SubmergedStep.traceStep, .contents_fn = SubmergedStep.water };
        for (1..126) |frame| _ = try move.run(&player, &motion, .{ .time_ms = @intCast(frame * 16), .angles = @splat(0), .forward = 127, .up = -127 }, parameters, service);
        try std.testing.expectEqual(@as(u2, 3), player.water_level);
        if (height == 8) {
            try std.testing.expect(motion.position[0] > 100);
            try std.testing.expect(motion.position[2] + parameters.mins[2] >= height);
        } else try std.testing.expect(motion.position[0] < 50);
    }
}
test "water exit accepts detail monster clips while solid player clips and bodies block" {
    for ([_]u32{ 0, c.CONTENTS_DETAIL | c.CONTENTS_MONSTERCLIP, c.CONTENTS_WATER, c.CONTENTS_TRIGGER, c.CONTENTS_AREAPORTAL, c.CONTENTS_SOLID, c.CONTENTS_PLAYERCLIP, c.CONTENTS_BODY }) |upper| {
        var ledge: WaterLedge = .{ .upper_contents = upper };
        var player: move.Player = .{};
        var motion: @import("../core/domain/slide.zig").State = .{ .position = @splat(0), .velocity = @splat(0) };
        var parameters = bridge.parameters(0);
        parameters.fixed_ms = 16;
        parameters.snap_velocity = false;
        _ = try move.run(&player, &motion, .{ .time_ms = 16, .angles = @splat(0), .forward = 127, .up = 127 }, parameters, .{ .context = &ledge, .trace_fn = WaterLedge.openTrace, .contents_fn = WaterLedge.sample });
        const blocked = upper & parameters.mask != 0;
        try std.testing.expectEqual(!blocked, player.timer == .water_jump);
        if (blocked) try std.testing.expect(motion.velocity[2] < 100) else {
            try std.testing.expect(motion.position[2] > 4);
            try std.testing.expect(motion.velocity[2] > 300);
        }
    }
}
test "walking swimming diagonal crouch jump and gravity follow bundled movement" {
    var context: u8 = 0;
    defer water_surface = null;
    for ([_]?f32{ null, 16, 80 }) |surface| {
        water_surface = surface;
        for ([_]i8{ 0, 127 }) |strafe| {
            var reference = std.mem.zeroes(c.playerState_t);
            reference.origin = .{ 0, 0, 24 };
            reference.stats[c.STAT_HEALTH] = 100;
            reference.speed = 320;
            reference.gravity = 800;
            reference.groundEntityNum = c.ENTITYNUM_NONE;
            reference.viewheight = 22;
            var player = bridge.read(&reference);
            var motion: @import("../core/domain/slide.zig").State = .{ .position = reference.origin, .velocity = reference.velocity };
            var delta: [3]i32 = @splat(0);
            for (0..240) |frame| {
                var cmd = std.mem.zeroes(c.usercmd_t);
                cmd.serverTime = @intCast((frame + 1) * 16);
                cmd.forwardmove = if (frame < 180) 127 else 0;
                cmd.rightmove = strafe;
                cmd.upmove = if (frame >= 40 and frame < 80) -127 else if (frame >= 100 and frame < 120) 127 else 0;
                reference_move(&reference, cmd, referenceTrace, referenceContents);
                _ = try move.run(&player, &motion, bridge.command(cmd, &delta), bridge.parameters(0), .{ .context = &context, .trace_fn = trace, .contents_fn = contents });
                for (0..3) |axis| {
                    if (@abs(reference.origin[axis] - motion.position[axis]) > 0.05 or @abs(reference.velocity[axis] - motion.velocity[axis]) > 0.05)
                        std.debug.print("movement mismatch frame={d} strafe={d} axis={d} reference={d}/{d} zig={d}/{d}\n", .{ frame, strafe, axis, reference.origin[axis], reference.velocity[axis], motion.position[axis], motion.velocity[axis] });
                    try std.testing.expectApproxEqAbs(reference.origin[axis], motion.position[axis], 0.05);
                    try std.testing.expectApproxEqAbs(reference.velocity[axis], motion.velocity[axis], 0.05);
                }
                try std.testing.expectEqual(reference.viewheight, @as(i32, @intFromFloat(player.view_height)));
            }
        }
    }
}

test "companion hull and authored jump survive crouch stand and water sampling" {
    var context: u8 = 0;
    defer water_surface = null;
    water_surface = null;
    const service: collision.Collision = .{ .context = &context, .trace_fn = trace, .contents_fn = contents };
    var parameters = bridge.parameters(64);
    parameters.mins = .{ -12, -12, -24 };
    parameters.maxs = .{ 12, 12, 30 };
    parameters.jump_speed = 350;
    parameters.snap_velocity = false;
    var motor: move.Player = .{};
    var motion: @import("../core/domain/slide.zig").State = .{ .position = .{ 0, 0, 24 }, .velocity = @splat(0) };
    const crouched = try move.run(&motor, &motion, .{ .time_ms = 16, .angles = @splat(0), .up = -127 }, parameters, service);
    try std.testing.expect(motor.ducked);
    try std.testing.expectEqual(@as(f32, 4), crouched.maxs[2]);
    try std.testing.expectEqual(@as(f32, 12), crouched.maxs[0]);
    const upright = try move.run(&motor, &motion, .{ .time_ms = 32, .angles = @splat(0) }, parameters, service);
    try std.testing.expect(!motor.ducked);
    try std.testing.expectEqual(parameters.maxs, upright.maxs);
    _ = try move.run(&motor, &motion, .{ .time_ms = 48, .angles = @splat(0), .up = 127 }, parameters, service);
    try std.testing.expect(motor.jump_held and motor.ground_entity == c.ENTITYNUM_NONE);
    try std.testing.expect(motion.velocity[2] > 330); // The former ground motor forced 270.
    water_surface = 128;
    _ = try move.run(&motor, &motion, .{ .time_ms = 64, .angles = @splat(0), .forward = 127 }, parameters, service);
    try std.testing.expectEqual(@as(u2, 3), motor.water_level);
    try std.testing.expectEqual(@as(u32, c.CONTENTS_WATER), motor.water_type);
}

test "support catching a stationary falling player cannot turn overclip into a jump" {
    var context: u8 = 0;
    defer water_surface = null;
    water_surface = null;
    const service: collision.Collision = .{ .context = &context, .trace_fn = trace, .contents_fn = contents };
    for ([_]f32{ -79, -240 }) |fall_speed| {
        var player: move.Player = .{};
        var motion: @import("../core/domain/slide.zig").State = .{ .position = .{ 0, 0, 24.125 }, .velocity = .{ 0, 0, fall_speed } };
        for (1..11) |step| {
            _ = try move.run(&player, &motion, .{ .time_ms = @intCast(step * 16), .angles = @splat(0) }, bridge.parameters(0), service);
            try std.testing.expectEqual(@as(u16, c.ENTITYNUM_WORLD), player.ground_entity);
            try std.testing.expectEqual(@as(f32, 0), motion.velocity[2]);
            try std.testing.expectApproxEqAbs(@as(f32, 24.125), motion.position[2], 0.001);
        }
    }
}

fn conveyorTrace(_: *anyopaque, request: collision.Request) !collision.Trace {
    var hit = plane(request.start, request.mins, request.end);
    if (hit.fraction < 1) hit.contents = c.CONTENTS_SOLID | c.CONTENTS_PLAYERCLIP | c.CONTENTS_DK3_CURRENT_90;
    return hit;
}
fn currentContents(point: v.Vec3) u32 {
    return if (point[2] < 200) c.CONTENTS_WATER | c.CONTENTS_DK3_CURRENT_180 else 0;
}
fn currentWater(_: *anyopaque, point: v.Vec3, _: u16) !u32 {
    return currentContents(point);
}
test "conveyor floors carry an idle walker and water currents an idle swimmer" {
    var context: u8 = 0;
    var parameters = bridge.parameters(0);
    parameters.fixed_ms = 16;
    // Gold PM_AddCurrents: 100 u/s wish along CURRENT_90 (+y) under friction.
    var player: move.Player = .{};
    var motion: @import("../core/domain/slide.zig").State = .{ .position = .{ 0, 0, 24 }, .velocity = @splat(0) };
    _ = try move.run(&player, &motion, .{ .time_ms = 1000, .angles = @splat(0) }, parameters, .{ .context = &context, .trace_fn = conveyorTrace, .contents_fn = contents });
    try std.testing.expect(player.ground_entity != 2047);
    try std.testing.expect(motion.velocity[1] > 80 and motion.velocity[1] <= 100 and @abs(motion.velocity[0]) < 0.01);
    try std.testing.expect(motion.position[1] > 40);
    // Deep in a CURRENT_180 (-x) volume the swimmer drifts west.
    player = .{};
    motion = .{ .position = .{ 0, 0, 100 }, .velocity = @splat(0) };
    _ = try move.run(&player, &motion, .{ .time_ms = 1000, .angles = @splat(0) }, parameters, .{ .context = &context, .trace_fn = trace, .contents_fn = currentWater });
    try std.testing.expectEqual(@as(u2, 3), player.water_level);
    try std.testing.expect(motion.velocity[0] < -100 and motion.position[0] < -50);
}
