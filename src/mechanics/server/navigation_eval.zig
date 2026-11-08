// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Frozen local navigation trials against real map collision. Copies move;
//! live actors, health, gates and authoritative transforms are never relocated by this probe.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const v = @import("../../core/domain/vector.zig");
const nav = @import("../../core/domain/navigation.zig");
const slide = @import("../../core/domain/slide.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const c = abi.c;
const Slots = @import("../../engine/slots.zig").Slots;
const pilot = @import("bot_pilot.zig");
const movement = @import("../domain/player_move.zig");
const allocator = std.heap.c_allocator;
const Case = struct { id: usize, actor: u32, slot: u16, definition: u8, start: v.Vec3, goal: v.Vec3, mins: v.Vec3, maxs: v.Vec3, mask: u32 };
const Result = struct { reached: bool = false, hazardous: bool = false, distance: f32 = 0, time_ms: i64 = 0 };
const harmful: u32 = c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO;

fn hazardous(point: v.Vec3, mins: v.Vec3, slot: u16) !bool {
    return try engine.collisionService().contents(v.add(point, .{ 0, 0, mins[2] + 1 }), slot) & harmful != 0;
}
fn touchesExit(world: *data.World, point: v.Vec3, body: data.Body) !bool {
    var exits = world.queryAccess(data.World.mask(.{ data.Exit, data.Transform, data.Body }), 0, 0);
    defer exits.deinit();
    while (exits.next()) |view| for (view.read(data.Transform), view.read(data.Body)) |pose, bounds| {
        var intersects = true;
        for (0..3) |axis| if (point[axis] + body.maxs[axis] <= pose.position[axis] + bounds.mins[axis] or point[axis] + body.mins[axis] >= pose.position[axis] + bounds.maxs[axis]) {
            intersects = false;
        };
        if (intersects) return true;
    };
    return false;
}
/// Independent physical oracle: ordinary slide/step collision, without route
/// selection, actor floor prediction, control use or catch-up placement.
fn reference(world: *data.World, start: v.Vec3, wanted: v.Vec3, body: data.Body, slot: u16) !?v.Vec3 {
    var state: slide.State = .{ .position = start, .velocity = @splat(0) };
    for (0..40) |_| {
        const ground = try engine.collisionService().trace(.{ .start = state.position, .end = v.add(state.position, .{ 0, 0, -0.5 }), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask });
        if (ground.start_solid or ground.all_solid) return null;
        const along = nav.velocity(state.position, wanted, 128, 0.05);
        state.velocity[0] = along[0];
        state.velocity[1] = along[1];
        if (ground.fraction < 1 and state.velocity[2] < 0) state.velocity[2] = 0;
        var context: slide.Context = .{ .service = engine.collisionService(), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask, .delta = 0.05, .gravity = 800, .ground = if (ground.fraction < 1 and ground.normal[2] >= 0.7) ground.normal else null };
        try context.step(&state);
        if (try touchesExit(world, state.position, body)) return null;
        if (state.position[2] < start[2] - 32 or try hazardous(state.position, body.mins, slot)) return null;
        if (nav.horizontalDistance(state.position, wanted) < 4) break;
    }
    if (nav.horizontalDistance(state.position, start) < nav.horizontalDistance(start, wanted) * 0.75) return null;
    const support = try engine.collisionService().trace(.{ .start = state.position, .end = v.add(state.position, .{ 0, 0, -2 }), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask });
    if (support.start_solid or support.fraction == 1 or support.normal[2] < 0.7) return null;
    return state.position;
}
fn collect(world: *data.World, slots: *const Slots) !std.ArrayList(Case) {
    var cases: std.ArrayList(Case) = .empty;
    errdefer cases.deinit(allocator);
    var supported: usize = 0;
    var embedded: usize = 0;
    var recoverable: usize = 0;
    var unsupported: usize = 0;
    var actors = world.queryAccess(data.World.mask(.{ data.Actor, data.Transform, data.Body, data.Binding }), 0, 0);
    defer actors.deinit();
    while (actors.next()) |view| for (view.entities(), view.read(data.Actor), view.read(data.Transform), view.read(data.Body), view.read(data.Binding)) |entity, actor, pose, shape, binding| {
        if (actor.mode == .dead or shape.motion_owner != null) continue;
        var body = shape;
        body.collision_mask &= ~@as(u32, c.CONTENTS_BODY);
        var floor = try engine.collisionService().trace(.{ .start = pose.position, .end = v.add(pose.position, .{ 0, 0, -48 }), .mins = body.mins, .maxs = body.maxs, .slot = binding.slot, .mask = body.collision_mask });
        var trial_start: ?v.Vec3 = null;
        if (floor.start_solid or floor.all_solid) {
            embedded += 1;
            var message: [320]u8 = undefined;
            var clearance: i32 = -1;
            for ([_]f32{ 0.125, 0.25, 0.5, 1, 2, 4, 8, 16 }) |up| {
                const point = v.add(pose.position, .{ 0, 0, up });
                const probe = try engine.collisionService().trace(.{ .start = point, .end = point, .mins = body.mins, .maxs = body.maxs, .slot = binding.slot, .mask = body.collision_mask });
                if (!probe.start_solid and !probe.all_solid) {
                    clearance = @intFromFloat(up * 1000);
                    break;
                }
            }
            engine.print(try std.fmt.bufPrintZ(&message, "dk3 naveval: embedded actor={d} class={s} start={d:.3},{d:.3},{d:.3} hit={d} contents={d} raise_milli={d}\n", .{ try world.persistentId(entity), @import("actor_catalog").entries[actor.definition].classname, pose.position[0], pose.position[1], pose.position[2], floor.entity, floor.contents, clearance }));
            // A physically valid floor with up to one unit of numerical
            // penetration is a recovery trial. Preserve the raw embedded
            // start for both scored controllers; only the independent oracle
            // gets a clear starting point to qualify its reachable goals.
            if (clearance <= 0 or clearance > 1000) continue;
            const raised = v.add(pose.position, .{ 0, 0, @as(f32, @floatFromInt(clearance)) / 1000 });
            floor = try engine.collisionService().trace(.{ .start = raised, .end = v.add(raised, .{ 0, 0, -48 }), .mins = body.mins, .maxs = body.maxs, .slot = binding.slot, .mask = body.collision_mask });
            if (floor.start_solid or floor.all_solid) continue;
            recoverable += 1;
            trial_start = pose.position;
        }
        if (floor.fraction == 1 or floor.normal[2] < 0.7) {
            unsupported += 1;
            continue;
        }
        supported += 1;
        const start = v.add(floor.end, .{ 0, 0, 0.125 });
        for ([_]f32{ 64, 192 }) |radius| for (0..8) |direction| {
            const angle = @as(f32, @floatFromInt(direction)) * std.math.pi / 4;
            const wanted = v.add(start, .{ @cos(angle) * radius, @sin(angle) * radius, 0 });
            const goal = try reference(world, start, wanted, body, binding.slot) orelse continue;
            if (try touchesExit(world, goal, body)) continue;
            try cases.append(allocator, .{ .id = cases.items.len, .actor = try world.persistentId(entity), .slot = binding.slot, .definition = actor.definition, .start = trial_start orelse start, .goal = goal, .mins = body.mins, .maxs = body.maxs, .mask = body.collision_mask });
        };
    };
    _ = slots;
    var text: [200]u8 = undefined;
    engine.print(try std.fmt.bufPrintZ(&text, "dk3 naveval: inventory supported={d} embedded={d} unsupported={d} eligible={d} recoverable={d}\n", .{ supported, embedded, unsupported, cases.items.len, recoverable }));
    return cases;
}
fn vector(tokens: *std.mem.TokenIterator(u8, .any)) !v.Vec3 {
    var result: v.Vec3 = undefined;
    for (&result) |*value| {
        value.* = try std.fmt.parseFloat(f32, tokens.next() orelse return error.InvalidNavigationCase);
        if (!std.math.isFinite(value.*)) return error.InvalidNavigationCase;
    }
    return result;
}
fn frozen(world: *data.World, path: []const u8) !std.ArrayList(Case) {
    var name: [128]u8 = undefined;
    const bytes = try @import("../../engine/files.zig").read(.server, &engine.gateway, allocator, try std.fmt.bufPrintZ(&name, "{s}", .{path}), 16 * 1024 * 1024);
    defer allocator.free(bytes);
    var result: std.ArrayList(Case) = .empty;
    errdefer result.deinit(allocator);
    var lines = std.mem.tokenizeScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        var tokens = std.mem.tokenizeAny(u8, line, " \t\r");
        if (!std.mem.eql(u8, tokens.next() orelse continue, "case")) return error.InvalidNavigationCase;
        const id = try std.fmt.parseInt(usize, tokens.next() orelse return error.InvalidNavigationCase, 10);
        const actor_id = try std.fmt.parseInt(u32, tokens.next() orelse return error.InvalidNavigationCase, 10);
        const entity = world.find(actor_id) orelse return error.MissingNavigationActor;
        const actor = (try world.get(entity, data.Actor)).*;
        const start = try vector(&tokens);
        const goal = try vector(&tokens);
        const mins = try vector(&tokens);
        const maxs = try vector(&tokens);
        const mask = try std.fmt.parseInt(u32, tokens.next() orelse return error.InvalidNavigationCase, 10);
        if (tokens.next() != null or id != result.items.len) return error.InvalidNavigationCase;
        try result.append(allocator, .{ .id = id, .actor = actor_id, .slot = (try world.get(entity, data.Binding)).slot, .definition = actor.definition, .start = start, .goal = goal, .mins = mins, .maxs = maxs, .mask = mask });
    }
    return result;
}
fn trial(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, service: nav.Service, weapons: *const @import("../domain/weapons.zig").Table, fixture: ecs.Entity, case: Case, controller: enum { actor, follower }) !Result {
    var actor: data.Actor = .{ .definition = case.definition, .mode = .chase, .threat_position = case.goal };
    var pose: data.Transform = .{ .position = case.start };
    var body: data.Body = .{ .mins = case.mins, .maxs = case.maxs, .collision_mask = case.mask };
    var velocity: data.Velocity = .{};
    var player: data.Player = .{ .command_ms = 950 };
    var steering: pilot.Pilot = .{};
    var result: Result = .{};
    for (0..100) |tick| {
        const now: i64 = 1000 + @as(i64, @intCast(tick)) * 50;
        if (controller == .actor) {
            try @import("actor_motion.zig").step(&actor, &pose, &body, &velocity, service, case.goal, 128, case.slot, now, 50);
        } else {
            (try world.get(fixture, data.Transform)).* = pose;
            (try world.get(fixture, data.Velocity)).* = velocity;
            (try world.get(fixture, data.Body)).* = body;
            (try world.get(fixture, data.Player)).* = player;
            (try world.get(fixture, data.Binding)).slot = case.slot;
            const frame: pilot.Frame = .{ .world = world, .slots = slots, .projections = projections, .service = service, .collision = engine.collisionService(), .table = weapons, .slot = case.slot, .entity = fixture, .state = player, .hull = .{ .mins = case.mins, .maxs = case.maxs }, .motor = .{ .speed = 128, .jump_speed = 270, .slot = case.slot, .mask = case.mask, .water_mask = c.MASK_WATER, .solid_mask = c.CONTENTS_SOLID, .mins = case.mins, .maxs = case.maxs, .snap_velocity = false }, .now = now, .capabilities = .{ .controls = false, .operate_lifts = false, .passages = false, .exits = false, .use = false, .nuisance = false, .ignore_ambient = true, .duck_to_shoot = false, .careful_footing = true, .tread_water = true } };
            const command = (try steering.steer(frame, .{ .destination = case.goal, .fight = false })).command;
            pose.angles = .{ command.angles[0], command.angles[1], 0 };
            var motion: slide.State = .{ .position = pose.position, .velocity = velocity.linear };
            _ = try movement.run(&player, &motion, .{ .time_ms = now, .angles = pose.angles, .forward = command.forward, .right = command.right, .up = command.up }, .{ .speed = 128, .jump_speed = 270, .slot = case.slot, .mask = case.mask, .water_mask = c.MASK_WATER, .solid_mask = c.CONTENTS_SOLID, .mins = case.mins, .maxs = case.maxs, .snap_velocity = false }, engine.collisionService());
            pose.position = motion.position;
            velocity.linear = motion.velocity;
        }
        result.time_ms = @as(i64, @intCast(tick + 1)) * 50;
        result.distance = v.length(v.subtract(case.goal, pose.position));
        if (try hazardous(pose.position, case.mins, case.slot) or pose.position[2] < case.start[2] - 48) {
            result.hazardous = true;
            break;
        }
        if (nav.horizontalDistance(pose.position, case.goal) <= 16 and @abs(pose.position[2] - case.goal[2]) <= 24) {
            result.reached = true;
            break;
        }
    }
    return result;
}
pub fn run(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, service: nav.Service, weapons: *const @import("../domain/weapons.zig").Table, path: []const u8) !void {
    if (engine.integer("dk3_runtime_probe") != 2) return error.IsolatedNavigationProbeOnly;
    var cases = if (path.len == 0) try collect(world, slots) else try frozen(world, path);
    defer cases.deinit(allocator);
    const fixture = try world.create(null, .{ data.Transform{}, data.Velocity{}, data.Body{}, data.Binding{ .slot = c.ENTITYNUM_NONE }, data.Keys{}, data.Ailments{}, data.Hurt{}, data.Weapons{}, data.Health{ .current = 100 }, data.Character{}, data.Player{} });
    defer world.destroy(fixture) catch unreachable;
    var text: [1024]u8 = undefined;
    for (cases.items) |case| {
        engine.print(try std.fmt.bufPrintZ(&text, "dk3 naveval: case {d} {d} {d:.6} {d:.6} {d:.6} {d:.6} {d:.6} {d:.6} {d:.6} {d:.6} {d:.6} {d:.6} {d:.6} {d:.6} {d}\n", .{ case.id, case.actor, case.start[0], case.start[1], case.start[2], case.goal[0], case.goal[1], case.goal[2], case.mins[0], case.mins[1], case.mins[2], case.maxs[0], case.maxs[1], case.maxs[2], case.mask }));
        inline for (.{ .actor, .follower }) |controller| {
            const result = trial(world, slots, projections, service, weapons, fixture, case, controller) catch |err| {
                if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace);
                return err;
            };
            engine.print(try std.fmt.bufPrintZ(&text, "dk3 naveval: result case={d} controller={s} class={s} reached={d} hazardous={d} distance={d:.3} time_ms={d}\n", .{ case.id, @tagName(controller), @import("actor_catalog").entries[case.definition].classname, @intFromBool(result.reached), @intFromBool(result.hazardous), result.distance, result.time_ms }));
        }
    }
    engine.print(try std.fmt.bufPrintZ(&text, "dk3 naveval: complete cases={d}\n", .{cases.items.len}));
}
