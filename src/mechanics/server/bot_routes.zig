// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Physical bot subgoals for authored route controls. Never fires remote targets.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const nav = @import("../../core/domain/navigation.zig");
const v = @import("../../core/domain/vector.zig");
const engine = @import("../../engine/server.zig");
const c = @import("../../engine/abi.zig").c;
const prop = @import("properties.zig");
const Slots = @import("../../engine/slots.zig").Slots;
pub const Control = struct { id: u32, obstacle: u32, route_obstacle: u32, point: v.Vec3, action: enum { use, touch, shoot } };
pub const Passage = struct { id: u32, point: v.Vec3 };
/// Propose a supported walking step clear of the moving solid that just
/// crushed a body. Angular solids reserve their complete horizontal sweep;
/// linear solids reserve both endpoints. Collision still owns all movement.
pub fn crushEscape(world: *data.World, actor: ecs.Entity, source: u32, collision: @import("../../core/domain/collision.zig").Collision) !?v.Vec3 {
    const solid = world.find(source) orelse return null;
    const mover = world.get(solid, data.Mover) catch return null;
    if (!mover.moving()) return null;
    const solid_pose = (try world.get(solid, data.Transform)).*;
    const solid_body = (try world.get(solid, data.Body)).*;
    const position = (try world.get(actor, data.Transform)).position;
    const body = (try world.get(actor, data.Body)).*;
    const slot = (try world.get(actor, data.Binding)).slot;
    var radius: f32 = 0;
    for ([_]f32{ solid_body.mins[0], solid_body.maxs[0] }) |x| for ([_]f32{ solid_body.mins[1], solid_body.maxs[1] }) |y| {
        radius = @max(radius, @sqrt(x * x + y * y));
    };
    const actor_radius = @sqrt(body.maxs[0] * body.maxs[0] + body.maxs[1] * body.maxs[1]);
    const forbidden: u32 = c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO;
    for ([_]f32{ 48, 80, 112 }) |distance| for (0..8) |way| {
        const angle = @as(f32, @floatFromInt(way)) * std.math.pi / 4;
        const candidate = v.add(position, .{ @cos(angle) * distance, @sin(angle) * distance, 0 });
        if (mover.angular) {
            if (nav.horizontalDistance(candidate, solid_pose.position) < radius + actor_radius + 4) continue;
        } else {
            var outside = false;
            for (0..2) |axis| {
                const low = @min(mover.closed[axis], mover.opened[axis]) + solid_body.mins[axis] - body.maxs[axis] - 4;
                const high = @max(mover.closed[axis], mover.opened[axis]) + solid_body.maxs[axis] - body.mins[axis] + 4;
                outside = outside or candidate[axis] < low or candidate[axis] > high;
            }
            if (!outside) continue;
        }
        const point = try @import("../../core/domain/navigation_input.zig").walkPathDrop(collision, .{ .start = position, .end = candidate, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = c.MASK_PLAYERSOLID }, forbidden, &.{}, 64) orelse continue;
        return point;
    };
    return null;
}
/// Authored teleporter recovery for a physically blocked AAS route. Reaching
/// the trigger is ordinary walking, qualified through every intervening hull.
pub fn teleportPassage(world: *data.World, projections: []const @import("../../engine/abi.zig").EntityProjection, actor: ecs.Entity, toward: v.Vec3, goal: v.Vec3, service: nav.Service, now: i64) !?Passage {
    const pose = (try world.get(actor, data.Transform)).*;
    const body = (try world.get(actor, data.Body)).*;
    const slot = (try world.get(actor, data.Binding)).slot;
    const id = try world.persistentId(actor);
    const obstruction = try engine.collisionService().trace(.{ .start = pose.position, .end = v.add(pose.position, v.scale(v.normalize(v.subtract(toward, pose.position)), 80)), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = c.MASK_PLAYERSOLID });
    if (obstruction.fraction == 1) return null;
    const steering = @import("../../core/domain/navigation_input.zig");
    var hazards: [256]steering.Bounds = undefined;
    var hazard_count: usize = 0;
    {
        var query = world.queryAccess(data.World.mask(.{ data.Hazard, data.Binding }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.read(data.Hazard), view.read(data.Binding)) |hazard, binding| {
            if (!hazard.enabled) continue;
            if (hazard_count == hazards.len) return null;
            const bounds = projections[binding.slot].shared;
            hazards[hazard_count] = .{ .mins = bounds.absmin, .maxs = bounds.absmax };
            hazard_count += 1;
        };
    }
    var selected: ?Passage = null;
    var nearest: f32 = 640;
    var query = world.queryAccess(data.World.mask(.{ data.WorldControl, data.MapObject, data.Binding }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.WorldControl), view.read(data.MapObject), view.read(data.Binding)) |entity, control, object, binding| {
        if (!@import("entity_classes/registry.zig").isPassage(control.action) or now < control.ready_ms) continue;
        if (!try @import("world_controls.zig").touches(world, entity, actor) or !@import("locks.zig").allows(world, object, id)) continue;
        const box = projections[binding.slot].shared;
        if (box.contents & c.CONTENTS_TRIGGER == 0) continue;
        // A thin trigger can sit against a wall. Touching it requires hull
        // overlap, not putting the player's origin inside the brush centre.
        var contact = pose.position;
        for (0..3) |axis| contact[axis] = std.math.clamp(contact[axis], box.absmin[axis] - body.maxs[axis] + 1, box.absmax[axis] - body.mins[axis] - 1);
        const distance = nav.horizontalDistance(pose.position, contact);
        if (distance >= nearest) continue;
        const target = try @import("entity_classes/registry.zig").passage(control.action, world, entity) orelse continue;
        if (v.length(v.subtract(target.position, pose.position)) < 128) continue;
        if (try service.next(.{ .position = target.position, .destination = goal, .slot = slot, .player = true, .allow_slime_escape = true }) == null) continue;
        const point = try steering.walkPath(engine.collisionService(), .{ .start = pose.position, .end = contact, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = c.MASK_PLAYERSOLID }, c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO, hazards[0..hazard_count]) orelse continue;
        var overlaps = true;
        for (0..3) |axis| if (point[axis] + body.maxs[axis] <= box.absmin[axis] or point[axis] + body.mins[axis] >= box.absmax[axis]) {
            overlaps = false;
        };
        if (!overlaps) continue;
        selected = .{ .id = try world.persistentId(entity), .point = point };
        nearest = distance;
    };
    return selected;
}
pub fn completed(world: *data.World, control: Control) bool {
    const obstacle = world.find(control.route_obstacle) orelse return true;
    if (world.get(obstacle, data.Mover) catch null) |mover| if (mover.state == .open or mover.state == .opening) return true;
    // A train lift is sent (or called) once it moves.
    if (@import("platforms.zig").pathPhase(world, obstacle)) |phase| return phase.moving or phase.teleporting;
    // A navigation gate (toggled wall, damaging volume, breakable, sliding
    // floor or door) is done when it no longer blocks.
    if (gates.closedNow(world, gate_projections, obstacle)) |closed| return !closed;
    _ = world.get(obstacle, data.Mover) catch return true;
    return false;
}
/// Projections for gate checks in `completed` (set by `unblock`).
var gate_projections: []const @import("../../engine/abi.zig").EntityProjection = &.{};
const gates = @import("navigation_gates.zig");
/// The authored control to operate first for a goal the live route cannot
/// reach: the route with every navigation gate open crosses a closed gate;
/// seek what opens it (a button, trigger or shot whose authored chain reaches
/// it, with nested prerequisites), or shoot it if it is a breakable.
pub fn unblock(world: *data.World, slots: *Slots, projections: []const @import("../../engine/abi.zig").EntityProjection, state: *gates.State, actor: ecs.Entity, goal: v.Vec3, service: nav.Service, now: i64, avoided: u32) !?Control {
    var waiting = false;
    return unblockWaiting(world, slots, projections, state, actor, goal, service, now, avoided, &waiting);
}
/// `unblock`, also telling whether the gate in the way is already moving
/// (a door opening, a floor sliding out): then there is nothing to operate.
pub fn unblockWaiting(world: *data.World, slots: *Slots, projections: []const @import("../../engine/abi.zig").EntityProjection, state: *gates.State, actor: ecs.Entity, goal: v.Vec3, service: nav.Service, now: i64, avoided: u32, waiting: *bool) !?Control {
    gate_projections = projections;
    waiting.* = false;
    return unblockToward(world, slots, projections, state, actor, goal, service, now, avoided, waiting, 0);
}
/// Where a player waits for the first closed gate on its way to `goal`: the
/// near side of a door a teammate is opening, or one already moving.
pub fn gateFront(world: *data.World, state: *gates.State, actor: ecs.Entity, goal: v.Vec3) !?v.Vec3 {
    const pose = (try world.get(actor, data.Transform)).*;
    const slot = (try world.get(actor, data.Binding)).slot;
    const block = state.blocking(pose.position, slot, goal) orelse return null;
    return block.near;
}
fn unblockToward(world: *data.World, slots: *Slots, projections: []const @import("../../engine/abi.zig").EntityProjection, state: *gates.State, actor: ecs.Entity, goal: v.Vec3, service: nav.Service, now: i64, avoided: u32, waiting: *bool, depth: usize) anyerror!?Control {
    if (depth == 4) return null;
    const pose = (try world.get(actor, data.Transform)).*;
    const slot = (try world.get(actor, data.Binding)).slot;
    var excluded: [64]u32 = undefined;
    var count: usize = 0;
    while (count < @min(excluded.len, state.gates.items.len)) {
        const gate = (state.blockingExcept(pose.position, slot, goal, excluded[0..count]) orelse return null).gate;
        if (std.mem.indexOfScalar(u32, excluded[0..count], gate.id) != null) return null;
        excluded[count] = gate.id;
        count += 1;
        if (gate.id == avoided) continue;
        const entity = world.find(gate.id) orelse continue;
        if (world.get(entity, data.Mover) catch null) |mover| if (mover.moving()) {
            waiting.* = true;
            return null;
        };
        const diagnostic = engine.integer("developer") >= 2;
        if (engine.integer("developer") >= 1) {
            var text: [192]u8 = undefined;
            const object = (try world.get(entity, data.MapObject)).*;
            engine.print(std.fmt.bufPrintZ(&text, "dk3 navigation plan: depth={d} gate={s} #{d} {s} targetname={s} alternative={d}\n", .{ depth, @tagName(gate.kind), gate.id & 0xffffff, object.classname, object.targetname, count }) catch "");
        }
        // Prefer a control reachable in the live world. Otherwise resolve its
        // prerequisite without reopening previously rejected shortcuts.
        if (try gateControl(world, slots, projections, actor, entity, gate, service, now, avoided, diagnostic)) |control| {
            if (diagnostic) {
                var text: [192]u8 = undefined;
                engine.print(try std.fmt.bufPrintZ(&text, "dk3 navigation control: gate={d} control={d} point={d:.1},{d:.1},{d:.1}\n", .{ gate.id, control.id, control.point[0], control.point[1], control.point[2] }));
            }
            return control;
        }
        const control = behind: {
            state.openExcept(excluded[0 .. count - 1]);
            defer state.restore();
            break :behind try gateControl(world, slots, projections, actor, entity, gate, service, now, avoided, diagnostic) orelse continue;
        };
        const next = (state.blocking(pose.position, slot, control.point) orelse continue).gate;
        // A control behind the very gate it opens cannot be this route's
        // prerequisite. Keep that shortcut closed and try another route.
        if (next.id == gate.id) continue;
        if (try unblockToward(world, slots, projections, state, actor, control.point, service, now, avoided, waiting, depth + 1)) |prerequisite| return prerequisite;
    }
    return null;
}
fn gateControl(world: *data.World, slots: *Slots, projections: []const @import("../../engine/abi.zig").EntityProjection, actor: ecs.Entity, entity: ecs.Entity, gate: gates.Gate, service: nav.Service, now: i64, avoided: u32, diagnostic: bool) !?Control {
    if (gate.kind == .breakable) {
        const breakable = try world.get(entity, data.Destructible);
        if (breakable.shootable) {
            var obstructions: [approach_points]u16 = @splat(c.ENTITYNUM_NONE);
            const point = try approach(world, entity, actor, .shoot, service, projections, diagnostic, &obstructions, null) orelse return null;
            return .{ .id = gate.id, .obstacle = gate.id, .route_obstacle = gate.id, .point = point, .action = .shoot };
        }
        // One only another breakable's blast brings down (e1m3b's logo
        // wall, fired by a charged panel above it): find what fires it.
    }
    var dependencies: [64]u32 = undefined;
    var control = try seekObstacle(world, slots, projections, actor, entity, service, now, avoided, diagnostic, &dependencies, 0) orelse return null;
    control.route_obstacle = gate.id;
    return control;
}
/// Finishing a prerequisite does not finish the original blocked route. Resolve
/// the next real control from the current world state, retaining the route goal.
pub fn advance(world: *data.World, slots: *Slots, projections: []const @import("../../engine/abi.zig").EntityProjection, actor: ecs.Entity, control: Control, service: nav.Service, now: i64) !?Control {
    if (completed(world, control)) return null;
    const obstacle = world.find(control.route_obstacle) orelse return null;
    var dependencies: [64]u32 = undefined;
    var next = try seekObstacle(world, slots, projections, actor, obstacle, service, now, 0, false, &dependencies, 0) orelse return null;
    next.route_obstacle = control.route_obstacle;
    return next;
}
pub fn aim(world: *data.World, control: Control) !?v.Vec3 {
    const entity = world.find(control.id) orelse return null;
    if (world.get(entity, data.Health) catch null) |health| if (health.current <= 0) return null;
    if (world.get(entity, data.Mover) catch null) |mover| if (mover.state == .open or mover.state == .opening) return null;
    if (world.find(control.obstacle)) |obstacle| {
        if (world.get(obstacle, data.Mover) catch null) |mover| if (mover.state == .open or mover.state == .opening) return null;
    } else return null;
    return try center(world, entity);
}
pub fn center(world: *data.World, entity: ecs.Entity) !v.Vec3 {
    const bounds = try bodyBounds(world, entity);
    return v.scale(v.add(bounds.mins, bounds.maxs), 0.5);
}
/// Tight world-space bounds of the transformed body, independent of the
/// engine's deliberately loose broad-phase bounds for rotating inline models.
pub fn bodyBounds(world: *data.World, entity: ecs.Entity) !@import("../../core/domain/navigation_input.zig").Bounds {
    const pose = (try world.get(entity, data.Transform)).*;
    const body = world.get(entity, data.Body) catch return .{ .mins = pose.position, .maxs = pose.position };
    const inline_model = if (world.get(entity, data.MapObject) catch null) |object| object.model.len > 1 and object.model[0] == '*' else false;
    // Trigger angles describe facing/launch direction. Their authoritative
    // touch volume is axis aligned, including when it uses an inline model.
    if (!inline_model or body.contents & c.CONTENTS_TRIGGER != 0)
        return .{ .mins = v.add(pose.position, body.mins), .maxs = v.add(pose.position, body.maxs) };
    var result: @import("../../core/domain/navigation_input.zig").Bounds = .{ .mins = @splat(std.math.inf(f32)), .maxs = @splat(-std.math.inf(f32)) };
    for (0..8) |corner| {
        var local: v.Vec3 = undefined;
        for (0..3) |axis| local[axis] = if (corner & (@as(usize, 1) << @intCast(axis)) != 0) body.maxs[axis] else body.mins[axis];
        const point = v.add(pose.position, @import("../domain/poses.zig").rotate(local, @splat(0), pose.angles));
        for (0..3) |axis| {
            result.mins[axis] = @min(result.mins[axis], point[axis]);
            result.maxs[axis] = @max(result.maxs[axis], point[axis]);
        }
    }
    return result;
}
test "a rotating off-centre brush carries its physical centre" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    const entity = try world.create(333, .{
        data.Transform{ .position = .{ 10, 20, 30 }, .angles = .{ 0, 90, 0 } },
        data.Body{ .mins = .{ -8, -100, -4 }, .maxs = .{ 8, -20, 4 } },
        data.MapObject{ .classname = "", .model = "*1" },
    });
    const point = try center(&world, entity);
    for (point, [_]f32{ 70, 20, 30 }) |actual, expected| try std.testing.expectApproxEqAbs(expected, actual, 0.001);
    const bounds = try bodyBounds(&world, entity);
    for (bounds.mins, [_]f32{ 30, 12, 26 }) |actual, expected| try std.testing.expectApproxEqAbs(expected, actual, 0.001);
    for (bounds.maxs, [_]f32{ 110, 28, 34 }) |actual, expected| try std.testing.expectApproxEqAbs(expected, actual, 0.001);
}
test "an off-centre trigger's facing angle does not rotate its touch volume" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    const entity = try world.create(25, .{
        data.Transform{ .angles = .{ 0, 180, 0 } },
        data.Body{ .mins = .{ -609, -1481, 487 }, .maxs = .{ -591, -1287, 705 }, .contents = c.CONTENTS_TRIGGER },
        data.MapObject{ .classname = "", .model = "*2" },
    });
    try std.testing.expectEqual(v.Vec3{ -600, -1384, 596 }, try center(&world, entity));
    const bounds = try bodyBounds(&world, entity);
    try std.testing.expectEqual(v.Vec3{ -609, -1481, 487 }, bounds.mins);
    try std.testing.expectEqual(v.Vec3{ -591, -1287, 705 }, bounds.maxs);
}
/// Stay inside a lift shaft until its authored travel brings the rider to the
/// requested floor. Running into the upper landing early can block the pusher.
pub fn ridePoint(world: *data.World, slots: *const Slots, actor: ecs.Entity, ground: u16, destination: v.Vec3) !?v.Vec3 {
    if (ground >= slots.occupants.len) return null;
    const platform = slots.occupants[ground] orelse return null;
    // A train lift carries its rider while it moves: stay at its middle.
    if (@import("platforms.zig").pathPhase(world, platform)) |phase| {
        if (!phase.moving) return null;
        var middle = try center(world, platform);
        middle[2] = (try world.get(actor, data.Transform)).position[2];
        return middle;
    }
    const mover = world.get(platform, data.Mover) catch return null;
    if (mover.angular or @abs(mover.opened[2] - mover.closed[2]) < 18) return null;
    if (@abs(mover.opened[0] - mover.closed[0]) > 1 or @abs(mover.opened[1] - mover.closed[1]) > 1) return null;
    const rider = (try world.get(actor, data.Transform)).position;
    if (@abs(destination[2] - rider[2]) <= 18) return null;
    const pose = (try world.get(platform, data.Transform)).position;
    // Only wait for real travel. A stationary upper landing does not promise
    // another descent merely because the final objective lies on a lower floor.
    const endpoint = if (mover.moving()) mover.motion.end else if (mover.return_at.at_ms != null) (if (mover.state == .open) mover.closed else mover.opened) else return null;
    if (@abs(destination[2] - (rider[2] + endpoint[2] - pose[2])) >= @abs(destination[2] - rider[2]) - 18) return null;
    var point = try center(world, platform);
    point[2] = rider[2];
    return point;
}
fn linked(source: data.MapObject, target: []const u8) bool {
    if (target.len == 0) return false;
    if (std.mem.eql(u8, source.target, target)) return true;
    for ([_][]const u8{ "target2", "target3", "target4" }) |key| if (prop.text(source, key)) |name| if (std.mem.eql(u8, name, target)) return true;
    return false;
}
/// Follow only authored forwarding controls. Script programs and changetargets
/// are not presumed to fire their epairs; the target router remains authoritative.
fn chain(world: *data.World, source: ecs.Entity, obstacle: ecs.Entity, actor: u32, now: i64, visited: *[64]u32, depth: usize) !bool {
    if (source.index == obstacle.index) return true;
    if (depth == visited.len) return false;
    const id = try world.persistentId(source);
    if (std.mem.indexOfScalar(u32, visited[0..depth], id) != null) return false;
    visited[depth] = id;
    const object = (try world.get(source, data.MapObject)).*;
    if (!@import("locks.zig").allows(world, object, actor)) return false;
    // Event generators fan out to their timed targets like a relay.
    const sequence = world.get(source, data.TargetSequence) catch null;
    // A breakable fires its targets (and removes its killtargets) as it breaks.
    const forwards = sequence != null or @import("entity_classes/registry.zig").traitsOf(object.classname).relays;
    if (!forwards) return false;
    if (world.get(source, data.Trigger) catch null) |trigger| if (now < trigger.ready_ms or (trigger.limit > 0 and trigger.uses >= trigger.limit)) return false;
    var query = world.queryAccess(data.World.mask(.{data.MapObject}), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, target| {
        const timed = if (sequence) |events| for (events.events) |event| {
            if (target.targetname.len != 0 and std.mem.eql(u8, event.target, target.targetname)) break true;
        } else false else false;
        if (!timed and !linked(object, target.targetname)) {
            // Removing the obstacle opens it too (relays that kill laser beams).
            if (entity.index == obstacle.index and target.targetname.len != 0) if (prop.text(object, "killtarget")) |name| if (std.mem.eql(u8, name, target.targetname)) return true;
            continue;
        }
        if (!@import("locks.zig").allows(world, target, actor)) continue;
        if (try chain(world, entity, obstacle, actor, now, visited, depth + 1)) return true;
    };
    return false;
}
pub fn seek(world: *data.World, slots: *Slots, projections: []const @import("../../engine/abi.zig").EntityProjection, actor: ecs.Entity, toward: v.Vec3, service: nav.Service, now: i64, avoided: u32) !?Control {
    return seekInternal(world, slots, projections, actor, toward, service, now, avoided, false);
}
pub fn diagnose(world: *data.World, slots: *Slots, projections: []const @import("../../engine/abi.zig").EntityProjection, actor: ecs.Entity, toward: v.Vec3, service: nav.Service, now: i64) !void {
    _ = try seekInternal(world, slots, projections, actor, toward, service, now, 0, true);
}
fn seekInternal(world: *data.World, slots: *Slots, projections: []const @import("../../engine/abi.zig").EntityProjection, actor: ecs.Entity, toward: v.Vec3, service: nav.Service, now: i64, avoided: u32, diagnostic: bool) !?Control {
    const pose = (try world.get(actor, data.Transform)).*;
    const body = (try world.get(actor, data.Body)).*;
    const slot = (try world.get(actor, data.Binding)).slot;
    var direction = v.subtract(toward, pose.position);
    const ground = (try world.get(actor, data.Player)).ground_entity;
    const platform = if (ground < slots.occupants.len) slots.occupants[ground] else null;
    // The next AAS descent can be underneath the platform we stand on. Keep
    // that trace's vertical component so the actual lift, not an imaginary
    // horizontal wall, owns the request for its authored control. (A goal
    // below and off the platform is a step down from it: door slabs laid
    // as stairs, e1m5b's console room.)
    const over_platform = ground < projections.len and
        toward[0] > projections[ground].shared.absmin[0] - 24 and toward[0] < projections[ground].shared.absmax[0] + 24 and
        toward[1] > projections[ground].shared.absmin[1] - 24 and toward[1] < projections[ground].shared.absmax[1] + 24;
    const descending_lift = direction[2] < -18 and over_platform and (if (platform) |entity| (world.get(entity, data.Mover) catch null) != null else false);
    // Climbing straight up (a ladder under a hatch, e1m6b's from the
    // platform in the nitrogen): what closes the way is overhead.
    const climbing = direction[2] > 18 and v.length(.{ direction[0], direction[1], 0 }) < 24;
    if (!descending_lift and !climbing) direction[2] = 0;
    direction = v.normalize(direction);
    var hit = try engine.collisionService().trace(.{ .start = pose.position, .end = v.add(pose.position, v.scale(direction, 80)), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = c.MASK_PLAYERSOLID });
    // A hull grazing a doorway's jamb meets the wall first: look again with a
    // slim body above step height for the door straight ahead.
    if (hit.fraction < 1 and hit.entity >= slots.occupants.len) {
        const slim = try engine.collisionService().trace(.{ .start = pose.position, .end = v.add(pose.position, v.scale(direction, 80)), .mins = .{ -4, -4, body.mins[2] + 18 }, .maxs = .{ 4, 4, body.maxs[2] }, .slot = slot, .mask = c.MASK_PLAYERSOLID });
        if (slim.fraction < 1 and slim.entity < slots.occupants.len) hit = slim;
    }
    if (diagnostic) {
        var text: [256]u8 = undefined;
        const top = if (hit.entity < slots.occupants.len) projections[hit.entity].shared.absmax[2] else 0;
        engine.print(try std.fmt.bufPrintZ(&text, "dk3 control seek: slot={d} hit_slot={d} fraction={d:.3} solid={d} ground={d} top={d:.0} feet={d:.0} normal={d:.2},{d:.2},{d:.2}\n", .{ slot, hit.entity, hit.fraction, @intFromBool(hit.start_solid), ground, top, pose.position[2] + body.mins[2], hit.normal[0], hit.normal[1], hit.normal[2] }));
    }
    if (hit.fraction == 1 or hit.entity >= slots.occupants.len) return null;
    const obstacle = slots.occupants[hit.entity] orelse return null;
    var dependencies: [64]u32 = undefined;
    var control = try seekObstacle(world, slots, projections, actor, obstacle, service, now, avoided, diagnostic, &dependencies, 0) orelse return null;
    const mover = world.get(obstacle, data.Mover) catch return null;
    control.route_obstacle = if (world.find(mover.group)) |master| try world.persistentId(master) else try world.persistentId(obstacle);
    return control;
}
/// Physical controls the player can operate directly. Unnamed angular movers
/// include levers; a named remote door retains its authored control requirement.
pub fn canOperate(world: *data.World, entity: ecs.Entity, object: data.MapObject) bool {
    const traits = @import("entity_classes/registry.zig").traitsOf(object.classname);
    return object.manually_unlocked or traits.button or traits.player_usable or
        (object.targetname.len == 0 and (world.get(entity, data.Mover) catch null) != null);
}
fn seekObstacle(world: *data.World, slots: *Slots, projections: []const @import("../../engine/abi.zig").EntityProjection, actor: ecs.Entity, blocked: ecs.Entity, service: nav.Service, now: i64, avoided: u32, diagnostic: bool, dependencies: *[64]u32, depth: usize) anyerror!?Control {
    var obstacle = blocked;
    // Doors act as one group; other gates (walls, damaging volumes) are their own.
    if (world.get(obstacle, data.Mover) catch null) |mover| {
        if (mover.moving()) return null;
        if (world.find(mover.group)) |master| obstacle = master;
    }
    const obstacle_id = try world.persistentId(obstacle);
    if (depth == dependencies.len or std.mem.indexOfScalar(u32, dependencies[0..depth], obstacle_id) != null) return null;
    dependencies[depth] = obstacle_id;
    const pose = (try world.get(actor, data.Transform)).*;
    const id = try world.persistentId(actor);
    var result: ?Control = null;
    var nearest: f32 = std.math.inf(f32);
    var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Body, data.Transform, data.Binding }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.MapObject), view.read(data.Binding)) |entity, object, binding| {
        const control_id = try world.persistentId(entity);
        if (world.get(entity, data.Mover) catch null) |motion| if (motion.state == .open or motion.moving()) continue;
        if (control_id == avoided or !@import("locks.zig").allows(world, object, id)) continue;
        var action: @FieldType(Control, "action") = .use;
        const traits = @import("entity_classes/registry.zig").traitsOf(object.classname);
        // A button controls another obstacle; pressing the panel itself
        // never creates a passage through its wall. Treating a bumped
        // flush panel as its own gate repeatedly fetches the same control.
        if (entity.index == obstacle.index and traits.button) continue;
        if (canOperate(world, entity, object) or entity.index == obstacle.index) {
            if (try prop.number(object, "health", 0) > 0) {
                if ((world.get(entity, data.Health) catch continue).current <= 0) continue;
                action = .shoot;
            } else if (traits.button and object.flags & 1 != 0) {
                // A beam that switches damage on is never a control.
                if (gates.tripwire(world, object)) continue;
                action = .touch;
            } else if (!canOperate(world, entity, object)) {
                // A bumped solid without a use hook or shootable authored
                // health is an obstruction, not a control. Fetching its own
                // centre cannot open a path through an unbreakable prop.
                continue;
            } else if (entity.index == obstacle.index and object.targetname.len != 0) continue;
        } else if (traits.touch_volume and traits.relays and !traits.counter and object.flags & 1 == 0 and projections[binding.slot].shared.contents & c.CONTENTS_TRIGGER != 0) {
            action = .touch;
        } else if (traits.breakable and object.targetname.len == 0 and (object.target.len != 0 or prop.text(object, "killtarget") != null)) {
            // A breakable panel whose authored chain does the work (e1m3b's
            // lightning box above the laser corridor).
            const state = world.get(entity, data.Destructible) catch continue;
            if (state.broken or state.hidden or !state.shootable) continue;
            action = .shoot;
        } else continue;
        var visited: [64]u32 = undefined;
        const chained = try chain(world, entity, obstacle, id, now, &visited, 0);
        if (engine.integer("developer") >= 2 and canOperate(world, entity, object)) {
            var text: [192]u8 = undefined;
            engine.print(std.fmt.bufPrintZ(&text, "dk3 control candidate: obstacle={d} control={d} {s} target={s} chained={d}\n", .{ obstacle.index, entity.index, object.classname, object.target, @intFromBool(chained) }) catch "");
        }
        if (!chained) continue;
        var obstructions: [approach_points]u16 = @splat(c.ENTITYNUM_NONE);
        if (try approach(world, entity, actor, action, service, projections, diagnostic, &obstructions, null)) |point| {
            const distance = v.length(v.subtract(point, pose.position));
            if (distance >= nearest) continue;
            nearest = distance;
            result = .{ .id = control_id, .obstacle = obstacle_id, .route_obstacle = obstacle_id, .point = point, .action = action };
        } else for (obstructions, 0..) |blocked_slot, index| {
            if (blocked_slot >= slots.occupants.len or std.mem.indexOfScalar(u16, obstructions[0..index], blocked_slot) != null) continue;
            const blocker = slots.occupants[blocked_slot] orelse continue;
            // A control may itself sit behind another authored door. Walk to that
            // door's real control first; normal use/contact still performs every step.
            const prerequisite = try seekObstacle(world, slots, projections, actor, blocker, service, now, avoided, diagnostic, dependencies, depth + 1) orelse continue;
            const distance = v.length(v.subtract(prerequisite.point, pose.position));
            if (distance >= nearest) continue;
            nearest = distance;
            result = prerequisite;
        }
    };
    return result;
}

test "an unbreakable solid without a use hook is not its own route control" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    const actor = try world.create(1, .{data.Transform{}});
    const obstacle = try world.create(2, .{ data.MapObject{ .classname = "" }, data.Transform{}, data.Body{ .contents = c.CONTENTS_SOLID }, data.Binding{ .slot = 0 } });
    var slots: Slots = .{};
    var dependencies: [64]u32 = undefined;
    // No collision or navigation query is valid for this inert obstruction:
    // it has no operation whose approach could be planned.
    try std.testing.expectEqual(@as(?Control, null), try seekObstacle(&world, &slots, &.{}, actor, obstacle, undefined, 0, 0, false, &dependencies, 0));
}
/// One step of riding the lift a route's next reachability takes from its
/// entrance (the standing point on the lift at its lower stop).
pub const Lift = union(enum) {
    /// Walk onto the lift: it waits at the entrance.
    board: v.Vec3,
    /// Stay at the lift's middle while it travels or rises on its own.
    hold: v.Vec3,
    /// Operate this control: it sends the lift up, or calls it down.
    operate: Control,
    /// The lift is away and nothing reachable calls it: wait for it.
    wait,
    /// The lift stands away and this rider may not call it: go round.
    away,
};
/// What a lift rider's movement state says (a player's or a companion's own
/// motor), and whether it may operate controls itself.
pub const Rider = struct {
    ground: u16,
    view_height: f32,
    collision: @import("../../core/domain/collision.zig").Collision,
    /// A rider that never presses buttons waits for someone else to send it.
    operate: bool = true,
};
pub fn liftStep(world: *data.World, slots: *Slots, projections: []const @import("../../engine/abi.zig").EntityProjection, actor: ecs.Entity, rider: Rider, entrance: v.Vec3, service: nav.Service, now: i64) !?Lift {
    const ground = rider.ground;
    const lift = findLift(world, projections, entrance, if (ground < slots.occupants.len) slots.occupants[ground] else null) orelse return null;
    const lift_slot = (try world.get(lift, data.Binding)).slot;
    const box = projections[lift_slot].shared;
    const pose = (try world.get(actor, data.Transform)).*;
    const player: struct { ground_entity: u16, view_height: f32 } = .{ .ground_entity = rider.ground, .view_height = rider.view_height };
    const middle: v.Vec3 = .{ (box.absmin[0] + box.absmax[0]) / 2, (box.absmin[1] + box.absmax[1]) / 2, pose.position[2] };
    const moving = if (world.get(lift, data.Mover) catch null) |mover| mover.moving() else if (@import("platforms.zig").pathPhase(world, lift)) |phase| phase.moving or phase.teleporting else false;
    if (engine.integer("developer") >= 2) {
        var text: [192]u8 = undefined;
        engine.print(std.fmt.bufPrintZ(&text, "dk3 lift step: lift={d} slot={d} ground={d} moving={d} z={d:.0} entrance_z={d:.0}\n", .{ lift.index, lift_slot, player.ground_entity, @intFromBool(moving), pose.position[2], entrance[2] }) catch "");
    }
    var dependencies: [64]u32 = undefined;
    if (player.ground_entity == lift_slot) {
        if (moving) return .{ .hold = middle };
        // Aboard and stopped at the entrance level: set it going.
        if (@abs(pose.position[2] - entrance[2]) < 40) {
            if (!rider.operate) return .{ .hold = middle };
            // Aboard, only a control the lift carries sends it with the rider:
            // a call button on the landing sends it away without them.
            if (try carriedControl(world, projections, actor, lift, box, service, now) orelse try seekObstacle(world, slots, projections, actor, lift, service, now, 0, engine.integer("developer") >= 2, &dependencies, 0)) |found| {
                // Press a button the lift carries from on the lift: from a spot
                // overhanging its edge the moving floor can catch the rider
                // against the landing. The middle serves when it is clear (a
                // platform may carry its button on a console there) and in reach.
                var control = found;
                const body = (try world.get(actor, data.Body)).*;
                const over = control.point[0] + body.mins[0] >= box.absmin[0] and control.point[0] + body.maxs[0] <= box.absmax[0] and control.point[1] + body.mins[1] >= box.absmin[1] and control.point[1] + body.maxs[1] <= box.absmax[1];
                if (!over) if (world.find(control.id)) |button| if (v.length(v.subtract(try center(world, button), v.add(middle, .{ 0, 0, player.view_height }))) < 80) {
                    const room = try rider.collision.trace(.{ .start = middle, .end = middle, .mins = body.mins, .maxs = body.maxs, .slot = (try world.get(actor, data.Binding)).slot, .mask = c.MASK_PLAYERSOLID });
                    if (!room.start_solid and !room.all_solid) control.point = middle;
                };
                return .{ .operate = control };
            }
            return .{ .hold = middle };
        }
        // Stopped elsewhere: arrived, the route goes on from here.
        return null;
    }
    const body = (try world.get(actor, data.Body)).*;
    // An entrance on the landing beside it: its floor is level with the landing.
    // A cage lift (a train with walls and a roof) has its floor well below
    // the top of its box: find the floor inside it at the landing's height.
    var floor_z = box.absmax[2];
    const feet = entrance[2] + body.mins[2];
    const inside = try rider.collision.trace(.{ .start = .{ middle[0], middle[1], feet + 40 }, .end = .{ middle[0], middle[1], feet - 40 }, .mins = .{ -4, -4, 0 }, .maxs = .{ 4, 4, 0 }, .slot = (try world.get(actor, data.Binding)).slot, .mask = c.MASK_PLAYERSOLID });
    if (!inside.start_solid and inside.fraction < 1 and inside.entity == lift_slot and inside.normal[2] > 0.7) floor_z = inside.end[2];
    const level = @abs(floor_z - feet) < 20;
    // Never wait over the shaft or under the lift while it is not level with
    // the landing (a raised lift comes down, a lower one comes up through
    // whoever stands there): step out to the entrance beside it.
    const overlapping = pose.position[0] + body.maxs[0] > box.absmin[0] and pose.position[0] + body.mins[0] < box.absmax[0] and pose.position[1] + body.maxs[1] > box.absmin[1] and pose.position[1] + body.mins[1] < box.absmax[1];
    if (overlapping and (moving or !level)) return .{ .board = entrance };
    if (moving) return .wait;
    // The lift stands at the entrance when its floor is under that point.
    const below = try rider.collision.trace(.{ .start = v.add(entrance, .{ 0, 0, 8 }), .end = v.add(entrance, .{ 0, 0, -48 }), .mins = body.mins, .maxs = body.maxs, .slot = (try world.get(actor, data.Binding)).slot, .mask = c.MASK_PLAYERSOLID });
    if ((below.fraction < 1 and below.entity == lift_slot) or level) return .{ .board = .{ middle[0], middle[1], entrance[2] } };
    if (!rider.operate) return .away;
    if (try seekObstacle(world, slots, projections, actor, lift, service, now, 0, false, &dependencies, 0)) |control| return .{ .operate = control };
    // Nothing to board it with and nothing to call it by: the graph's platform
    // link is not a lift at all (e1m7a's hall counts the fallen cable that
    // story-drops across the room as a platform between its two floors). Give
    // up the lift and let the route be planned without one.
    return .away;
}
/// A button riding on `lift` (inside its footprint) whose chain reaches it,
/// with a standing point to press it from.
fn carriedControl(world: *data.World, projections: []const @import("../../engine/abi.zig").EntityProjection, actor: ecs.Entity, lift: ecs.Entity, box: anytype, service: nav.Service, now: i64) !?Control {
    const id = try world.persistentId(actor);
    const lift_id = try world.persistentId(lift);
    var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Binding }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.MapObject), view.read(data.Binding)) |entity, object, binding| {
        if (!@import("entity_classes/registry.zig").traitsOf(object.classname).button or binding.slot >= projections.len) continue;
        if (world.get(entity, data.Mover) catch null) |motion| if (motion.state == .open or motion.moving()) continue;
        const own = projections[binding.slot].shared;
        const middle = v.scale(v.add(own.absmin, own.absmax), 0.5);
        if (middle[0] < box.absmin[0] - 8 or middle[0] > box.absmax[0] + 8 or middle[1] < box.absmin[1] - 8 or middle[1] > box.absmax[1] + 8) continue;
        var visited: [64]u32 = undefined;
        if (!try chain(world, entity, lift, id, now, &visited, 0)) continue;
        var obstructions: [approach_points]u16 = @splat(c.ENTITYNUM_NONE);
        const point = try approach(world, entity, actor, .use, service, projections, false, &obstructions, null) orelse continue;
        return .{ .id = try world.persistentId(entity), .obstacle = lift_id, .route_obstacle = lift_id, .point = point, .action = .use };
    };
    return null;
}
/// The lift (a mover or train) whose footprint holds `point` across, or that
/// it stands beside (a lift link's entrance can lie on the landing next to it).
fn findLift(world: *data.World, projections: []const @import("../../engine/abi.zig").EntityProjection, point: v.Vec3, standing: ?ecs.Entity) ?ecs.Entity {
    var best: ?ecs.Entity = null;
    var nearest: f32 = std.math.inf(f32);
    var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Binding }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.Binding)) |entity, binding| {
        if (binding.slot >= projections.len) continue;
        // Something that lifts: a train, or a mover travelling up and down
        // (not a door or button beside the shaft).
        const is_lift = @import("platforms.zig").pathPhase(world, entity) != null or if (world.get(entity, data.Mover) catch null) |mover| !mover.angular and @abs(mover.opened[2] - mover.closed[2]) > @max(@abs(mover.opened[0] - mover.closed[0]), @abs(mover.opened[1] - mover.closed[1])) else false;
        if (!is_lift) continue;
        const box = projections[binding.slot].shared;
        if (engine.integer("developer") >= 3) {
            var text: [192]u8 = undefined;
            engine.print(std.fmt.bufPrintZ(&text, "dk3 lift candidate: slot={d} linked={d} box={d:.0},{d:.0},{d:.0}..{d:.0},{d:.0},{d:.0} point={d:.0},{d:.0},{d:.0}\n", .{ binding.slot, box.linked, box.absmin[0], box.absmin[1], box.absmin[2], box.absmax[0], box.absmax[1], box.absmax[2], point[0], point[1], point[2] }) catch "");
        }
        if (box.linked == 0) continue;
        if (point[0] < box.absmin[0] - 32 or point[0] > box.absmax[0] + 32 or point[1] < box.absmin[1] - 32 or point[1] > box.absmax[1] + 32) continue;
        // The lift underfoot is the one to ride.
        if (standing) |entity_under| if (entity_under.index == entity.index) return entity;
        const distance = @abs((box.absmin[2] + box.absmax[2]) / 2 - point[2]);
        if (distance < nearest) {
            nearest = distance;
            best = entity;
        }
    };
    return best;
}
/// Candidate standing points `approach` tries around a control.
pub const approach_points = 13;
/// Nearest supported, reachable standing point from which `action` can operate `target`.
pub fn approach(world: *data.World, target: ecs.Entity, actor: ecs.Entity, action: @FieldType(Control, "action"), service: nav.Service, projections: []const @import("../../engine/abi.zig").EntityProjection, diagnostic: bool, obstructions: *[approach_points]u16, lane: ?Lane) !?v.Vec3 {
    return approachWithin(world, target, actor, action, service, projections, diagnostic, obstructions, lane, 2000);
}
/// A firing stand must be within the selected weapon's actual reach.
pub fn approachWithin(world: *data.World, target: ecs.Entity, actor: ecs.Entity, action: @FieldType(Control, "action"), service: nav.Service, projections: []const @import("../../engine/abi.zig").EntityProjection, diagnostic: bool, obstructions: *[approach_points]u16, lane: ?Lane, reach: f32) !?v.Vec3 {
    const pose = (try world.get(actor, data.Transform)).*;
    var body = (try world.get(actor, data.Body)).*;
    const player = (try world.get(actor, data.Player)).*;
    // Player bodies retain their standing extents; the movement state owns
    // the current duck. Firing/use stands in crawlways need that same hull.
    if (player.ducked) body.maxs[2] = @min(body.maxs[2], 4);
    const target_slot = (try world.get(target, data.Binding)).slot;
    var box = projections[target_slot].shared;
    const physical = try bodyBounds(world, target);
    box.absmin = physical.mins;
    box.absmax = physical.maxs;
    // Rotated inline bounds are a broad-phase sphere about the hinge. The
    // action must aim at the actual transformed body centre, on the panel.
    const middle = try center(world, target);
    const margin: f32 = if (action == .shoot) 96 else if (action == .touch) 2 else 32;
    const probe: Stand = .{
        .world = world,
        .target = target,
        .action = action,
        .service = service,
        .diagnostic = diagnostic,
        .pose = pose,
        .body = body,
        .view_height = player.view_height,
        .slot = (try world.get(actor, data.Binding)).slot,
        .target_slot = target_slot,
        .middle = middle,
        .lane = lane,
        .reach = reach,
        // A shot at an explosive (a barrel, a charged panel) is fired from
        // outside the worst of its blast.
        .blast = if (action != .shoot) 0 else if (world.get(target, data.Scenery) catch null) |scenery| (if (scenery.explosive) 100 else 0) else if (world.get(target, data.Destructible) catch null) |destructible| (if (destructible.damage > 0) destructible.radius else 0) else 0,
    };
    var chosen: ?v.Vec3 = null;
    var distance: f32 = std.math.inf(f32);
    if (action == .shoot) {
        // A shooter stands anywhere with a line to it: out along eight
        // directions from its edge, the first good spot on each (a target
        // down a narrow corridor is in sight only from along it).
        const half = v.scale(v.subtract(box.absmax, box.absmin), 0.5);
        for (0..8) |way| {
            const angle = @as(f32, @floatFromInt(way)) * std.math.pi / 4;
            const bearing: v.Vec3 = .{ @cos(angle), @sin(angle), 0 };
            const clearance = outlineRadius(half, bearing) + @max(body.maxs[0], body.maxs[1]);
            // Close rings first, then farther out down a long corridor (a
            // panel behind a gated stretch is shot from its near end).
            var ring: f32 = 8;
            while (ring <= 640) : (ring += if (ring < 200) 16 else 48) {
                var blocker: u16 = c.ENTITYNUM_NONE;
                const point = try probe.check(v.add(middle, v.scale(bearing, clearance + ring)), &blocker);
                if (ring == 8) obstructions[1 + way] = blocker;
                const found = point orelse continue;
                const length = v.length(v.subtract(pose.position, found));
                if (length < distance) {
                    chosen = found;
                    distance = length;
                }
                break;
            }
        }
    } else {
        // Beside each face at the action's margin and close up, and off each
        // corner: a button recessed in a wall is in sight only from in front.
        var points: [approach_points]v.Vec3 = @splat(middle);
        for ([_]f32{ margin, 4 }, 0..) |gap, row| {
            points[1 + row * 4][0] = box.absmin[0] - body.maxs[0] - gap;
            points[2 + row * 4][0] = box.absmax[0] - body.mins[0] + gap;
            points[3 + row * 4][1] = box.absmin[1] - body.maxs[1] - gap;
            points[4 + row * 4][1] = box.absmax[1] - body.mins[1] + gap;
        }
        for (0..4) |corner| {
            points[9 + corner][0] = if (corner & 1 == 0) box.absmin[0] - body.maxs[0] - margin * 0.7 else box.absmax[0] - body.mins[0] + margin * 0.7;
            points[9 + corner][1] = if (corner & 2 == 0) box.absmin[1] - body.maxs[1] - margin * 0.7 else box.absmax[1] - body.mins[1] + margin * 0.7;
        }
        // A trigger is also touched from its middle.
        for (points, 0..) |candidate, index| {
            if (index == 0 and action != .touch) continue;
            const found = try probe.check(candidate, &obstructions[index]) orelse continue;
            const length = v.length(v.subtract(pose.position, found));
            if (length < distance) {
                chosen = found;
                distance = length;
            }
        }
    }
    // Where the player stands may already do.
    if (action != .touch) if (try probe.check(pose.position, &obstructions[0])) |found| return found;
    return chosen;
}
/// A standing point with a navigation area from which a player's hull meets
/// the volume `mins..maxs`: its centre, else just outside each face (a thin
/// exit strip set against the end of the walkable space has its centre where
/// no area reaches, yet a player in front of it touches it).
pub fn touchPoint(mins: v.Vec3, maxs: v.Vec3, slot: u16) !?v.Vec3 {
    return touchPointFrom(mins, maxs, slot, null);
}
/// `touchPoint`, preferring a point the route from `from` reaches (the
/// centre of a trigger set against a console can lie in an area of its own).
pub fn touchPointFrom(mins: v.Vec3, maxs: v.Vec3, slot: u16, from: ?struct { position: v.Vec3, service: nav.Service }) !?v.Vec3 {
    const navigation = @import("../../engine/navigation.zig");
    const hull_mins: v.Vec3 = .{ -15, -15, -24 };
    const hull_maxs: v.Vec3 = .{ 15, 15, 32 };
    var centre = v.scale(v.add(mins, maxs), 0.5);
    centre[2] = @min(maxs[2], mins[2] - hull_mins[2] + 8);
    var first: ?v.Vec3 = null;
    var candidates: [5]v.Vec3 = @splat(centre);
    candidates[1][0] = mins[0] - hull_maxs[0] + 1;
    candidates[2][0] = maxs[0] - hull_mins[0] - 1;
    candidates[3][1] = mins[1] - hull_maxs[1] + 1;
    candidates[4][1] = maxs[1] - hull_mins[1] - 1;
    for (candidates) |candidate| {
        var floors: TouchFloors = .{ .queries = engine.collisionService(), .candidate = candidate, .mins = mins, .maxs = maxs, .slot = slot };
        while (try floors.next()) |point| {
            if (navigation.destinationArea(point) == 0) continue;
            const origin = from orelse return point;
            if (first == null) first = point;
            if (try origin.service.next(.{ .position = origin.position, .destination = point, .slot = slot, .player = true }) != null) return point;
        }
    }
    return first;
}
/// A volume across stairs can contain several floor heights. Its bottom-based
/// seed may be inside a higher step, so search upward within hull overlap.
const TouchFloors = struct {
    queries: @import("../../core/domain/collision.zig").Collision,
    candidate: v.Vec3,
    mins: v.Vec3,
    maxs: v.Vec3,
    slot: u16,
    rise: f32 = 0,
    previous: ?v.Vec3 = null,
    fn next(self: *@This()) !?v.Vec3 {
        while (self.candidate[2] + self.rise <= self.maxs[2] + 24) {
            const start = v.add(self.candidate, .{ 0, 0, self.rise });
            self.rise += 18;
            const floor = try self.queries.trace(.{ .start = start, .end = v.add(start, .{ 0, 0, -512 }), .mins = .{ -15, -15, -24 }, .maxs = .{ 15, 15, 32 }, .slot = self.slot, .mask = c.MASK_PLAYERSOLID });
            if (floor.start_solid or floor.all_solid or floor.fraction == 1 or floor.normal[2] < 0.7) continue;
            const point = floor.end;
            if (point[2] + 32 < self.mins[2] or point[2] - 24 > self.maxs[2]) continue;
            if (self.previous) |previous| if (v.length(v.subtract(point, previous)) < 0.1) continue;
            self.previous = point;
            return point;
        }
        return null;
    }
};
test "touch volume finds a supported stair above an embedded bottom seed" {
    const collision = @import("../../core/domain/collision.zig");
    const Fixture = struct {
        height: f32 = 288,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (request.start[2] < self.height) return .{ .fraction = 0, .end = request.start, .normal = @splat(0), .start_solid = true };
            const fraction = (request.start[2] - self.height) / (request.start[2] - request.end[2]);
            return .{ .fraction = fraction, .end = .{ request.start[0], request.start[1], self.height }, .normal = .{ 0, 0, 1 } };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var fixture: Fixture = .{};
    const queries: collision.Collision = .{ .context = &fixture, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents };
    var floors: TouchFloors = .{ .queries = queries, .candidate = .{ 0, 0, 256 }, .mins = .{ -16, -8, 224 }, .maxs = .{ 16, 8, 384 }, .slot = 0 };
    try std.testing.expectEqual(@as(v.Vec3, .{ 0, 0, 288 }), (try floors.next()).?);
    try std.testing.expectEqual(null, try floors.next());
    fixture.height = 128;
    floors.rise = 0;
    floors.previous = null;
    try std.testing.expectEqual(null, try floors.next());
}
/// A civilian whose body stands in a control's travel (a worker typing at the
/// console a button is set in): the control cannot move while he is there.
pub fn civilianBlocker(world: *data.World, projections: []const @import("../../engine/abi.zig").EntityProjection, control: ecs.Entity) !?u32 {
    const mover = world.get(control, data.Mover) catch return null;
    if (mover.angular or mover.state == .open) return null;
    const binding = world.get(control, data.Binding) catch return null;
    if (binding.slot >= projections.len) return null;
    const box = projections[binding.slot].shared;
    const pose = (try world.get(control, data.Transform)).position;
    var low = box.absmin;
    var high = box.absmax;
    for ([_]v.Vec3{ mover.closed, mover.opened }) |end| for (0..3) |axis| {
        low[axis] = @min(low[axis], box.absmin[axis] + end[axis] - pose[axis]) - 1;
        high[axis] = @max(high[axis], box.absmax[axis] + end[axis] - pose[axis]) + 1;
    };
    var query = world.queryAccess(data.World.mask(.{ data.Actor, data.Health, data.Transform, data.Body }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.Actor), view.read(data.Health), view.read(data.Transform), view.read(data.Body)) |entity, actor, health, transform, body| {
        if (health.current <= 0 or !@import("actor_catalog").traitsOf(@import("actor_catalog").entries[actor.definition].kind).bystander) continue;
        var overlaps = true;
        for (0..3) |axis| if (transform.position[axis] + body.mins[axis] >= high[axis] or transform.position[axis] + body.maxs[axis] <= low[axis]) {
            overlaps = false;
        };
        if (overlaps) return try world.persistentId(entity);
    };
    return null;
}
/// A health station (hosportal and kin): used up close, facing it.
pub fn isStation(world: *data.World, entity: ecs.Entity) bool {
    if ((world.get(entity, data.WorldControl) catch null) == null) return false;
    const object = world.get(entity, data.MapObject) catch return false;
    return @import("entity_classes/registry.zig").traitsOf(object.classname).station;
}
/// What a held blast round needs of a position: where the round leaves the
/// weapon, so its lane can be traced from the muzzle and not the eye; how far
/// its blast carries once it bursts (`reach`, the same distance the pilot holds
/// itself out to); and whether the round needs a blast at all to do its work.
pub const Lane = struct {
    muzzle: v.Vec3,
    reach: f32 = 0,
    direct: bool = true,
    mins: v.Vec3 = @splat(-6),
    maxs: v.Vec3 = @splat(6),
    /// Shooter hull relative to the eye, when supplied by the caller.
    self_bounds: ?@import("../../core/domain/navigation_input.zig").Bounds = null,
};
/// Distance from the centre to the rectangular face along this bearing.
fn outlineRadius(half: v.Vec3, bearing: v.Vec3) f32 {
    var radius = std.math.inf(f32);
    for (0..2) |axis| if (@abs(bearing[axis]) > 0.0001) {
        radius = @min(radius, half[axis] / @abs(bearing[axis]));
    };
    return if (std.math.isFinite(radius)) radius else 0;
}
test "a wide thin target permits a close firing stand at its near face" {
    try std.testing.expectApproxEqAbs(@as(f32, 4), outlineRadius(.{ 45, 4, 12 }, .{ 0, 1, 0 }), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 45), outlineRadius(.{ 45, 4, 12 }, .{ -1, 0, 0 }), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4 * @sqrt(@as(f32, 2))), outlineRadius(.{ 45, 4, 12 }, .{ 0.7071068, -0.7071068, 0 }), 0.001);
}
/// Whether a round bursting at `point` can affect a mark centred on `mark`.
/// The game measures a blast from an object's centre, so a splash-only round
/// that bursts at the near end of a long target (the end of a window pane)
/// reaches none of it: firing there spends ammo forever and changes nothing.
pub fn roundTells(point: v.Vec3, mark: v.Vec3, lane: Lane) bool {
    if (lane.direct or lane.reach <= 0) return true;
    return v.length(v.subtract(point, mark)) <= lane.reach;
}
/// Whether a shooter at `eye` may fire a round that bursts at `point` at all:
/// its own blast would land on it. This is the pilot's own rule, so a stand
/// taken here is one the trigger will actually be pulled from.
pub fn roundSafe(eye: v.Vec3, point: v.Vec3, lane: Lane) bool {
    if (lane.reach <= 0) return true;
    const nearest = if (lane.self_bounds) |box| v.closestInBounds(point, v.add(eye, box.mins), v.add(eye, box.maxs)) else eye;
    return v.length(v.subtract(point, nearest)) >= lane.reach;
}
/// Whether a blast round's own lane reaches `point`. The round starts below the
/// eye and detonates on whatever it meets, so a line the eye can see may be a
/// lane the round cannot travel (a fin across a pit clips a shot aimed down at
/// the pipe under it). The tolerance is the pilot's own, so a spot taken here
/// is one it will pull the trigger from.
pub fn laneClear(slot: u16, eye: v.Vec3, point: v.Vec3, lane: Lane, target_slot: u16) !bool {
    return traceLane(engine.collisionService(), slot, eye, point, lane, target_slot);
}
/// Use reaches the panel's surface, which can be closer than its brush centre.
/// An established rider need not walk across a cage to an already usable lever.
pub fn canPressFrom(service: @import("../../core/domain/collision.zig").Collision, slot: u16, eye: v.Vec3, point: v.Vec3, target_slot: u16) !bool {
    const hit = try service.trace(.{ .start = eye, .end = point, .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = c.MASK_SHOT | c.CONTENTS_TRIGGER });
    return !hit.start_solid and !hit.all_solid and hit.fraction < 1 and hit.entity == target_slot and v.length(v.subtract(hit.end, eye)) <= 88;
}
test "a reachable panel face does not require approaching its farther centre" {
    const collision = @import("../../core/domain/collision.zig");
    const Fixture = struct {
        fraction: f32 = 0.9,
        entity: u16 = 8,
        solid: bool = false,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            return .{ .fraction = self.fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), self.fraction)), .normal = @splat(0), .entity = self.entity, .start_solid = self.solid };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var fixture: Fixture = .{};
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents };
    try std.testing.expect(try canPressFrom(service, 0, @splat(0), .{ 94, 0, 0 }, 8));
    fixture.fraction = 0.98;
    try std.testing.expect(!try canPressFrom(service, 0, @splat(0), .{ 94, 0, 0 }, 8));
    fixture.fraction = 0.9;
    fixture.entity = 9;
    try std.testing.expect(!try canPressFrom(service, 0, @splat(0), .{ 94, 0, 0 }, 8));
    fixture.entity = 8;
    fixture.solid = true;
    try std.testing.expect(!try canPressFrom(service, 0, @splat(0), .{ 94, 0, 0 }, 8));
}
fn traceLane(service: @import("../../core/domain/collision.zig").Collision, slot: u16, eye: v.Vec3, point: v.Vec3, lane: Lane, target_slot: u16) !bool {
    const muzzle = @import("../domain/combat.zig").muzzleAlong(eye, point, lane.muzzle);
    // The launcher converges on the first surface under the crosshair. Use
    // that impact, rather than a point inside the bounding box, to test the
    // offset muzzle's path. A nonexplosive bolt must hit the actual object;
    // striking another surface a few units away does no damage to it.
    const forward = v.normalize(v.subtract(point, eye));
    const sight = try service.trace(.{ .start = eye, .end = v.add(point, v.scale(forward, 64)), .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = c.MASK_SHOT });
    // Collision returns an impact just outside the surface. Ending the
    // offset muzzle ray at that point can never enter a thin target. Carry
    // it through the contact skin, as the real shot continues down its lane.
    const end = if (lane.reach > 0) point else v.add(sight.end, v.scale(v.normalize(v.subtract(sight.end, muzzle)), 8));
    const flight = try service.trace(.{ .start = muzzle, .end = end, .mins = lane.mins, .maxs = lane.maxs, .slot = slot, .mask = c.MASK_SHOT });
    if (!@import("builtin").is_test and engine.integer("developer") >= 3 and engine.integer("dk3_trace_entity") == target_slot) {
        var text: [384]u8 = undefined;
        engine.print(try std.fmt.bufPrintZ(&text, "dk3 muzzle lane: start={d:.2},{d:.2},{d:.2} end={d:.2},{d:.2},{d:.2} hit={d} fraction={d:.3} solid={d} bounds={d:.1},{d:.1}\n", .{ muzzle[0], muzzle[1], muzzle[2], end[0], end[1], end[2], flight.entity, flight.fraction, @intFromBool(flight.start_solid), lane.mins[0], lane.maxs[0] }));
    }
    // A distant target does not make a near interception safe. Bars and
    // sills can stop an offset projectile inside its shooter's blast radius.
    if (!roundSafe(eye, flight.end, lane)) return false;
    return !flight.start_solid and (flight.entity == target_slot or (lane.reach > 0 and (flight.fraction == 1 or v.length(v.subtract(flight.end, point)) <= @min(48, lane.reach))));
}
test "offset muzzle clearance reaches through the collision contact skin" {
    const collision = @import("../../core/domain/collision.zig");
    const Fixture = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            const surface: f32 = 100 - 0.03125;
            if (request.end[0] >= 100) {
                const fraction = (surface - request.start[0]) / (request.end[0] - request.start[0]);
                return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ -1, 0, 0 }, .entity = 7 };
            }
            return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
        }
    };
    var fixture: u8 = 0;
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Fixture.trace };
    try std.testing.expect(try traceLane(service, 0, @splat(0), .{ 104, 0, 0 }, .{ .muzzle = .{ 8, 12, -10 } }, 7));
}
test "a direct projectile rejects a nearby sill and a clear miss while blast lanes retain their reach" {
    const collision = @import("../../core/domain/collision.zig");
    const Fixture = struct {
        hit: u16 = 4,
        fraction: f32 = 0.8,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (request.mins[0] == 0) return .{ .fraction = 0.9, .entity = 7, .end = .{ 96, 0, 0 }, .normal = .{ -1, 0, 0 } };
            try std.testing.expectEqual(v.Vec3{ -4, -4, -4 }, request.mins);
            return .{ .fraction = self.fraction, .entity = self.hit, .end = .{ 90, 0, 0 }, .normal = .{ -1, 0, 0 } };
        }
    };
    var fixture: Fixture = .{};
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Fixture.trace };
    var lane: Lane = .{ .muzzle = .{ 0, 0, 22 }, .mins = @splat(-4), .maxs = @splat(4) };
    try std.testing.expect(!try traceLane(service, 0, @splat(0), .{ 100, 0, 0 }, lane, 7));
    fixture.hit = 7;
    try std.testing.expect(try traceLane(service, 0, @splat(0), .{ 100, 0, 0 }, lane, 7));
    fixture.hit = c.ENTITYNUM_NONE;
    fixture.fraction = 1;
    try std.testing.expect(!try traceLane(service, 0, @splat(0), .{ 100, 0, 0 }, lane, 7));
    fixture.hit = 4;
    fixture.fraction = 0.8;
    lane.reach = 64;
    try std.testing.expect(try traceLane(service, 0, @splat(0), .{ 100, 0, 0 }, lane, 7));
    lane.reach = 96;
    // The target is outside96 units; the intercepted round would burst at90.
    try std.testing.expect(roundSafe(@splat(0), .{ 100, 0, 0 }, lane));
    try std.testing.expect(!try traceLane(service, 0, @splat(0), .{ 100, 0, 0 }, lane, 7));
    lane.reach = 80;
    lane.self_bounds = .{ .mins = .{ -16, -16, -46 }, .maxs = .{ 16, 16, 10 } };
    // The eye is90 units away, but the body's near face is only74 away.
    try std.testing.expect(!roundSafe(@splat(0), .{ 90, 0, 0 }, lane));
    try std.testing.expect(!try traceLane(service, 0, @splat(0), .{ 100, 0, 0 }, lane, 7));
}
/// One candidate standing point for `approach`.
const Stand = struct {
    reach: f32 = 2000,
    world: *data.World,
    target: ecs.Entity,
    action: @FieldType(Control, "action"),
    service: nav.Service,
    diagnostic: bool,
    pose: data.Transform,
    body: data.Body,
    view_height: f32,
    slot: u16,
    target_slot: u16,
    middle: v.Vec3,
    blast: f32,
    lane: ?Lane = null,

    /// The floor under `candidate` if the action works from there and the
    /// route reaches it; `obstruction` names what hid or held it.
    fn check(self: Stand, candidate: v.Vec3, obstruction: *u16) !?v.Vec3 {
        // A ceiling grate has a floor on its upper side too. Prefer a real
        // firing stand on the actor's current layer before trying that
        // upper floor, which cannot be entered until the grate breaks.
        if (self.action == .shoot) {
            if (try self.checkAt(candidate, self.pose.position[2], obstruction)) |point| return point;
            if (@abs(self.pose.position[2] - self.middle[2]) <= 24) return null;
        }
        return self.checkAt(candidate, self.middle[2], obstruction);
    }
    fn checkAt(self: Stand, candidate: v.Vec3, base: f32, obstruction: *u16) !?v.Vec3 {
        var text: [512]u8 = undefined;
        // Buttons and triggers are operated from the floor below them; a
        // shooter may stand anywhere up to its own height.
        var top = candidate;
        // From above the control, lower when a lintel or ledge is in the way.
        // Bodies are not floors: a monster in front of a button moves on.
        var found: ?@import("../../core/domain/collision.zig").Trace = null;
        var blocker: ?u16 = null;
        for ([_]f32{ 48, 16, -16 }) |rise| {
            top[2] = base + rise;
            // A shot may come from far below a control set high on a wall
            // (a box at the ceiling over a keypad).
            const depth: f32 = if (self.action == .shoot) 640 else 256;
            const support = try @import("../../core/domain/navigation_input.zig").supportedPoint(engine.collisionService(), .{ .start = top, .end = v.add(top, .{ 0, 0, -depth }), .mins = self.body.mins, .maxs = self.body.maxs, .slot = self.slot, .mask = @as(u32, c.MASK_PLAYERSOLID) & ~@as(u32, c.CONTENTS_BODY) });
            if (support.floor) |hit| {
                found = hit;
                break;
            }
            if (blocker == null) blocker = support.obstruction;
        }
        const floor = found orelse {
            obstruction.* = blocker orelse c.ENTITYNUM_NONE;
            return null;
        };
        if (self.diagnostic) engine.print(try std.fmt.bufPrintZ(&text, "dk3 control floor: slot={d} control={d} point={d:.2},{d:.2},{d:.2} fraction={d:.3} solid={d} normal_z={d:.3}\n", .{ self.slot, try self.world.persistentId(self.target), floor.end[0], floor.end[1], floor.end[2], floor.fraction, @intFromBool(floor.start_solid or floor.all_solid), floor.normal[2] }));
        if (try engine.collisionService().contents(v.add(floor.end, .{ 0, 0, self.body.mins[2] + 1 }), self.slot) & (c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO) != 0) return null;
        const eye = v.add(floor.end, .{ 0, 0, self.view_height });
        if (self.action == .shoot and v.length(v.subtract(self.middle, eye)) > self.reach) return null;
        // Actors and corpses move or can be cleared; only geometry hides a control.
        // A shot is a bolt-sized box: an edge the sight line just clears
        // stops it.
        const bolt: f32 = if (self.action == .shoot) 3 else 0;
        const target_contents = (try self.world.get(self.target, data.Body)).contents;
        const sight_mask = (@as(u32, c.MASK_SHOT) & ~@as(u32, c.CONTENTS_BODY | c.CONTENTS_CORPSE)) | (target_contents & c.CONTENTS_CORPSE);
        var sight = try engine.collisionService().trace(.{ .start = eye, .end = self.middle, .mins = @splat(-bolt), .maxs = @splat(bolt), .slot = self.slot, .mask = sight_mask });
        if (self.action == .use and sight.entity != self.target_slot) {
            const physical = try bodyBounds(self.world, self.target);
            const spread = v.scale(v.subtract(physical.maxs, physical.mins), 0.4);
            for ([_]v.Vec3{ .{ spread[0], 0, 0 }, .{ -spread[0], 0, 0 }, .{ 0, spread[1], 0 }, .{ 0, -spread[1], 0 }, .{ 0, 0, spread[2] }, .{ 0, 0, -spread[2] } }) |offset| {
                sight = try engine.collisionService().trace(.{ .start = eye, .end = v.add(self.middle, offset), .mins = @splat(0), .maxs = @splat(0), .slot = self.slot, .mask = sight_mask });
                if (sight.entity == self.target_slot) break;
            }
        }
        if (self.diagnostic) engine.print(try std.fmt.bufPrintZ(&text, "dk3 control sight: slot={d} control={d} hit_slot={d} target_slot={d} range={d:.3}\n", .{ self.slot, try self.world.persistentId(self.target), sight.entity, self.target_slot, v.length(v.subtract(sight.end, eye)) }));
        // Qualify the physical control, including shot-only contact bounds.
        if (self.action != .touch and sight.entity != self.target_slot) {
            obstruction.* = sight.entity;
            return null;
        }
        // A blast round needs the lane as well as the eye its line: a shot
        // fired at what the eye can see detonates on the first ledge it meets.
        // It also needs the shooter out of the burst's own reach, or the pilot
        // holding that rule never pulls the trigger from here.
        if (self.action == .shoot) if (self.lane) |lane| {
            if (!(try laneClear(self.slot, eye, self.middle, lane, self.target_slot))) {
                obstruction.* = c.ENTITYNUM_NONE;
                return null;
            }
            if (!roundSafe(eye, self.middle, lane)) {
                obstruction.* = c.ENTITYNUM_NONE;
                return null;
            }
        };
        if (self.blast > 0 and v.length(v.subtract(floor.end, self.middle)) < self.blast / 2) return null;
        if (self.action == .use and v.length(v.subtract(sight.end, eye)) > 88) return null;
        // A health station heals only a recipient within 64 of its origin.
        if (self.action == .use and isStation(self.world, self.target)) if (v.length(v.subtract((try self.world.get(self.target, data.Transform)).position, floor.end)) > 56) return null;
        var reachable = try self.service.next(.{ .position = self.pose.position, .destination = floor.end, .slot = self.slot, .player = true }) != null;
        // A short level walk needs no route: a control carried on the lift the
        // player stands on lies in shaft space the area graph leaves empty.
        if (!reachable and nav.horizontalDistance(self.pose.position, floor.end) < 128 and @abs(floor.end[2] - self.pose.position[2]) < 18) {
            reachable = try @import("../../core/domain/navigation_input.zig").walkPath(engine.collisionService(), .{ .start = self.pose.position, .end = floor.end, .mins = self.body.mins, .maxs = self.body.maxs, .slot = self.slot, .mask = c.MASK_PLAYERSOLID }, c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO, &.{}) != null;
        }
        if (self.diagnostic) engine.print(try std.fmt.bufPrintZ(&text, "dk3 control approach: slot={d} control={d} reachable={d}\n", .{ self.slot, try self.world.persistentId(self.target), @intFromBool(reachable) }));
        return if (reachable) floor.end else null;
    }
};
test "ceiling targets prefer the accessible firing floor and retain an upper-floor fallback" {
    const Fixture = struct {
        var lower_hidden = false;
        var crawl_lower = false;
        fn syscall(operation: isize, ...) callconv(.c) isize {
            var args = @cVaStart();
            defer @cVaEnd(&args);
            if (operation != c.G_TRACE) return 0;
            const out = @cVaArg(&args, *c.trace_t);
            const start = @cVaArg(&args, *const [3]f32);
            const mins = @cVaArg(&args, *const [3]f32);
            const maxs = @cVaArg(&args, *const [3]f32);
            const end = @cVaArg(&args, *const [3]f32);
            out.* = std.mem.zeroes(c.trace_t);
            out.fraction = 1;
            out.endpos = end.*;
            out.entityNum = c.ENTITYNUM_NONE;
            if (mins[0] > -4) {
                out.entityNum = if (lower_hidden and start[2] < 100) c.ENTITYNUM_WORLD else 1;
                return 0;
            }
            const height: f32 = if (start[2] + mins[2] >= 96) 96 else 0;
            if (start[2] + mins[2] < height) {
                out.startsolid = 1;
                out.allsolid = 1;
                out.fraction = 0;
                out.endpos = start.*;
                return 0;
            }
            if (crawl_lower and height == 0 and start[2] + maxs[2] > 40) {
                out.startsolid = 1;
                if (v.length(v.subtract(start.*, end.*)) < 0.001) out.allsolid = 1;
            }
            const a = start[2] + mins[2] - height;
            const b = end[2] + mins[2] - height;
            if (b < 0) {
                out.fraction = if (a > 0) a / (a - b) else 0;
                out.endpos = v.add(start.*, v.scale(v.subtract(end.*, start.*), out.fraction));
                out.plane.normal[2] = 1;
                out.entityNum = c.ENTITYNUM_WORLD;
            }
            return 0;
        }
        fn next(_: *anyopaque, request: nav.Request) !?nav.Waypoint {
            return .{ .point = request.destination };
        }
    };
    const previous = engine.gateway;
    defer engine.gateway = previous;
    engine.gateway.bind(Fixture.syscall);
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    const target = try world.create(2, .{ data.Transform{ .position = .{ 128, 0, 128 } }, data.Body{}, data.Binding{ .slot = 1 }, data.MapObject{ .classname = "" } });
    var context: u8 = 0;
    const stand: Stand = .{
        .world = &world,
        .target = target,
        .action = .shoot,
        .service = .{ .context = &context, .next_fn = Fixture.next },
        .diagnostic = false,
        .pose = .{ .position = .{ 0, 0, 24 } },
        .body = .{ .mins = .{ -15, -15, -24 }, .maxs = .{ 15, 15, 32 } },
        .view_height = 22,
        .slot = 0,
        .target_slot = 1,
        .middle = .{ 128, 0, 128 },
        .blast = 0,
    };
    var obstruction: u16 = c.ENTITYNUM_NONE;
    try std.testing.expectApproxEqAbs(@as(f32, 24), (try stand.check(.{ 96, 0, 128 }, &obstruction)).?[2], 0.001);
    Fixture.lower_hidden = true;
    try std.testing.expectApproxEqAbs(@as(f32, 120), (try stand.check(.{ 96, 0, 128 }, &obstruction)).?[2], 0.001);
    Fixture.lower_hidden = false;
    Fixture.crawl_lower = true;
    const actor = try world.create(3, .{ data.Transform{ .position = .{ 0, 0, 24 } }, data.Body{ .mins = .{ -15, -15, -24 }, .maxs = .{ 15, 15, 32 } }, data.Binding{ .slot = 0 }, data.Player{ .ducked = true, .view_height = 12 } });
    var projections = std.mem.zeroes([2]@import("../../engine/abi.zig").EntityProjection);
    var obstructions: [approach_points]u16 = @splat(c.ENTITYNUM_NONE);
    const navigation: nav.Service = .{ .context = &context, .next_fn = Fixture.next };
    const ducked = (try approachWithin(&world, target, actor, .shoot, navigation, &projections, false, &obstructions, null, 2000)).?;
    try std.testing.expectApproxEqAbs(@as(f32, 24), ducked[2], 0.001);
    (try world.get(actor, data.Player)).ducked = false;
    const upright = (try approachWithin(&world, target, actor, .shoot, navigation, &projections, false, &obstructions, null, 2000)).?;
    try std.testing.expectApproxEqAbs(@as(f32, 120), upright[2], 0.001);
}
/// Give an occupied narrow lane to the teammate ahead, with a traced safe floor.
pub fn yieldPoint(world: *data.World, slots: *Slots, actor: ecs.Entity, toward: v.Vec3) !?v.Vec3 {
    const pose = (try world.get(actor, data.Transform)).*;
    const body = (try world.get(actor, data.Body)).*;
    const slot = (try world.get(actor, data.Binding)).slot;
    const team = (try world.get(actor, data.Session)).*;
    const forward = v.normalize(.{ toward[0] - pose.position[0], toward[1] - pose.position[1], 0 });
    const hit = try engine.collisionService().trace(.{ .start = pose.position, .end = v.add(pose.position, v.scale(forward, 56)), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = c.MASK_PLAYERSOLID });
    if (hit.fraction == 1 or hit.entity >= slots.occupants.len) return null;
    const other = slots.occupants[hit.entity] orelse return null;
    const member = (world.get(other, data.Session) catch return null).*;
    if (!@import("../domain/multiplayer.zig").allied(team, member)) return null;
    // Human teammates retain priority; two bots choose one yielding participant.
    if (member.bot and slot < hit.entity) return null;
    const side: v.Vec3 = .{ -forward[1], forward[0], 0 };
    for ([_]f32{ 1, -1 }) |sign| {
        const point = v.add(v.add(pose.position, v.scale(side, sign * 48)), v.scale(forward, -24));
        const passage = try engine.collisionService().trace(.{ .start = pose.position, .end = point, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = c.MASK_PLAYERSOLID });
        if (passage.fraction < 1 or passage.start_solid or passage.all_solid) continue;
        const floor = try engine.collisionService().trace(.{ .start = point, .end = v.add(point, .{ 0, 0, -40 }), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = c.MASK_PLAYERSOLID });
        if (floor.fraction == 1 or floor.normal[2] < 0.7 or floor.start_solid or floor.all_solid) continue;
        if (try engine.collisionService().contents(v.add(floor.end, .{ 0, 0, body.mins[2] + 1 }), slot) & (c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO) != 0) continue;
        return floor.end;
    }
    return null;
}

test "route controls follow authored relay chains without bypassing locks or scripts" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 8);
    defer world.deinit();
    _ = try world.create(1, .{data.Keys{}});
    const button = try world.create(2, .{data.MapObject{ .classname = "func_button", .target = "relay" }});
    const relay = try world.create(3, .{data.MapObject{ .classname = "trigger_relay", .targetname = "relay", .target = "door" }});
    const door = try world.create(4, .{data.MapObject{ .classname = "func_door", .targetname = "door" }});
    const lever = try world.create(5, .{ data.MapObject{ .classname = "func_door_rotate", .target = "relay" }, data.Mover{ .closed = @splat(0), .opened = .{ 0, 90, 0 }, .motion = .{} } });
    var visited: [64]u32 = undefined;
    try t.expect(try chain(&world, button, door, 1, 0, &visited, 0));
    try t.expect(canOperate(&world, lever, (try world.get(lever, data.MapObject)).*));
    try t.expect(try chain(&world, lever, door, 1, 0, &visited, 0));
    (try world.get(lever, data.MapObject)).targetname = "remote_control";
    try t.expect(!canOperate(&world, lever, (try world.get(lever, data.MapObject)).*));
    (try world.get(door, data.MapObject)).properties = &.{.{ .key = "keyname", .value = "item_control_card_red" }};
    try t.expect(!try chain(&world, button, door, 1, 0, &visited, 0));
    (try world.get(door, data.MapObject)).properties = &.{};
    (try world.get(relay, data.MapObject)).classname = "trigger_script";
    try t.expect(!try chain(&world, button, door, 1, 0, &visited, 0));
    (try world.get(relay, data.MapObject)).classname = "trigger_relay";
    (try world.get(relay, data.MapObject)).target = "relay";
    try t.expect(!try chain(&world, button, door, 1, 0, &visited, 0));
}

test "an open prerequisite keeps the original blocked route active" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 4);
    defer world.deinit();
    const root = try world.create(110, .{data.Mover{ .closed = @splat(0), .opened = .{ 0, 0, 128 }, .motion = .{} }});
    const prerequisite = try world.create(321, .{data.Mover{ .closed = @splat(0), .opened = .{ 0, 0, 128 }, .motion = .{}, .state = .open }});
    const control: Control = .{ .id = 507, .obstacle = 321, .route_obstacle = 110, .point = @splat(0), .action = .use };
    try t.expect(!completed(&world, control));
    try world.destroy(prerequisite);
    try t.expect(!completed(&world, control));
    (try world.get(root, data.Mover)).state = .opening;
    try t.expect(completed(&world, control));
    (try world.get(root, data.Mover)).state = .closing;
    try t.expect(!completed(&world, control));
    try world.destroy(root);
    try t.expect(completed(&world, control));
}

test "a lift rider centers below the landing and resumes its route at landing height" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 4);
    defer world.deinit();
    var slots: Slots = .{};
    const platform = try world.create(337, .{ data.Transform{ .position = .{ 0, 0, -98 } }, data.Body{ .mins = .{ 616, 1264, -144 }, .maxs = .{ 712, 1344, 96 } }, data.Mover{ .closed = @splat(0), .opened = .{ 0, 0, -98 }, .motion = .{}, .state = .open, .return_at = .{ .at_ms = 1000 } } });
    const slot = try slots.acquire(platform, null);
    const actor = try world.create(1, .{ data.Player{ .ground_entity = slot }, data.Transform{ .position = .{ 631, 1300, 22 } } });
    const goal: v.Vec3 = .{ 272, 1304, 120 };
    try t.expectEqual(@as(?v.Vec3, .{ 664, 1304, 22 }), try ridePoint(&world, &slots, actor, (try world.get(actor, data.Player)).ground_entity, goal));
    // Ordinary same-height traversal and non-riders remain unaffected.
    try t.expectEqual(@as(?v.Vec3, null), try ridePoint(&world, &slots, actor, (try world.get(actor, data.Player)).ground_entity, .{ 272, 1304, 22 }));
    (try world.get(actor, data.Player)).ground_entity = c.ENTITYNUM_WORLD;
    try t.expectEqual(@as(?v.Vec3, null), try ridePoint(&world, &slots, actor, (try world.get(actor, data.Player)).ground_entity, goal));
    (try world.get(actor, data.Player)).ground_entity = slot;
    (try world.get(platform, data.Transform)).position[2] = 0;
    (try world.get(actor, data.Transform)).position[2] = 120;
    const mover = try world.get(platform, data.Mover);
    mover.state = .closed;
    mover.return_at = .{};
    try t.expectEqual(@as(?v.Vec3, null), try ridePoint(&world, &slots, actor, (try world.get(actor, data.Player)).ground_entity, goal));
    // Reproduce the actual carrier at a stopped upper endpoint. Its capture
    // volume is below both lift endpoints; no descent is currently scheduled.
    const lower_goal: v.Vec3 = .{ 936, -48, -108 };
    try t.expectEqual(@as(?v.Vec3, null), try ridePoint(&world, &slots, actor, (try world.get(actor, data.Player)).ground_entity, lower_goal));
    mover.state = .opening;
    mover.motion.end = mover.opened;
    try t.expectEqual(@as(?v.Vec3, .{ 664, 1304, 120 }), try ridePoint(&world, &slots, actor, (try world.get(actor, data.Player)).ground_entity, lower_goal));
    mover.state = .closing;
    mover.motion.end = mover.closed;
    (try world.get(platform, data.Transform)).position[2] = -98;
    (try world.get(actor, data.Transform)).position[2] = 22;
    try t.expectEqual(@as(?v.Vec3, null), try ridePoint(&world, &slots, actor, (try world.get(actor, data.Player)).ground_entity, lower_goal));
}
