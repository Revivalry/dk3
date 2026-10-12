// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Class-requested evasion through supplied hide nodes and ordinary locomotion.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const Ref = @import("../domain/world_references.zig").Ref;
const ecs = @import("../../core/ecs/world.zig");
const engine = @import("../../engine/server.zig");
const c = @import("../../engine/abi.zig").c;
const v = @import("../../core/domain/vector.zig");
const Routes = @import("air_routes.zig").Routes;
const policy = @import("actor_catalog").evasion;
const spawnflags = @import("actor_catalog").spawnflags;
pub fn targeted(world: *data.World, entity: ecs.Entity, target: Ref, pose: data.Transform) !bool {
    const other = (try target.get(data.Transform)).*;
    if (target.get(data.Player) catch null) |player| {
        // Native targeting currently uses actual crosshair contact, as Cambot does.
        const eye = v.add(other.position, .{ 0, 0, player.view_height });
        const hit = try @import("region_collision.zig").owned(target.world, .{ .start = eye, .end = v.add(eye, v.scale(v.basis(other.angles).forward, 8192)), .mins = @splat(0), .maxs = @splat(0), .slot = (try target.get(data.Binding)).slot, .mask = c.MASK_SHOT }, try target.id());
        return hit.fraction < 1 and @import("region_collision.zig").reaches(target.world, hit, .{ .world = world, .entity = entity });
    }
    const direction = v.subtract(other.position, pose.position);
    const yaw = std.math.atan2(direction[1], direction[0]) * 180 / std.math.pi;
    return @abs(@mod(yaw - pose.angles[1] + 180, 360) - 180) <= 5;
}
pub fn update(actor: *data.Actor, pose: data.Transform, now: i64) bool {
    const until = actor.evasion.until_ms orelse return false;
    const delta = v.subtract(actor.evasion.destination, pose.position);
    if (now >= until or (@sqrt(delta[0] * delta[0] + delta[1] * delta[1]) < 16 and @abs(delta[2]) < 32)) {
        actor.evasion.until_ms = null;
        return false;
    }
    actor.threat_position = actor.evasion.destination;
    actor.mode = .chase;
    return true;
}
pub fn start(routes: *const Routes, world: *data.World, entity: ecs.Entity, target: Ref, actor: *data.Actor, pose: data.Transform, ranged: bool, now: i64) !bool {
    const flags = (try world.get(entity, data.MapObject)).flags;
    if (!spawnflags.moves(flags)) return false;
    const random = try world.get(entity, data.Random);
    const kind = policy.choose(ranged, flags & spawnflags.sniper != 0, random.next(), random.next());
    return startKind(routes, world, entity, target, actor, pose, kind, now);
}
/// `start` for a class whose evasive action lasts at most `limit_ms` (the reference forces some
/// classes' evasion task to end early).
pub fn startBrief(routes: *const Routes, world: *data.World, entity: ecs.Entity, target: Ref, actor: *data.Actor, pose: data.Transform, ranged: bool, limit_ms: i64, now: i64) !bool {
    if (!try start(routes, world, entity, target, actor, pose, ranged, now)) return false;
    actor.evasion.until_ms = @min(actor.evasion.until_ms.?, now + limit_ms);
    return true;
}
pub fn dodge(routes: *const Routes, world: *data.World, entity: ecs.Entity, target: Ref, actor: *data.Actor, pose: data.Transform, now: i64) !bool {
    return startKind(routes, world, entity, target, actor, pose, .dodge, now);
}
fn startKind(routes: *const Routes, world: *data.World, entity: ecs.Entity, target: Ref, actor: *data.Actor, pose: data.Transform, kind: policy.Kind, now: i64) !bool {
    const random = try world.get(entity, data.Random);
    const body = (try world.get(entity, data.Body)).*;
    const slot = (try world.get(entity, data.Binding)).slot;
    var destination: ?v.Vec3 = null;
    var duration: i64 = if (kind == .strafe) 1100 else 2000;
    if (kind == .dodge and routes.nodes.len > 0 and random.next() > 0.5) {
        const visible = random.next() < 0.2;
        const enemy = (try target.get(data.Transform)).position;
        const enemy_slot = (try target.get(data.Binding)).slot;
        var choices: [4]u16 = undefined;
        var count: usize = 0;
        var nearest: f32 = 768;
        for (routes.nodes, 0..) |node, i| {
            if (!visible and node.flags & @import("actor_catalog").cover.hide_node == 0) continue;
            const distance = v.length(v.subtract(node.position, pose.position));
            if (distance >= nearest) continue;
            const hit = try @import("region_collision.zig").owned(target.world, .{ .start = enemy, .end = node.position, .mins = @splat(0), .maxs = @splat(0), .slot = enemy_slot, .mask = c.MASK_SOLID }, try target.id());
            if ((hit.fraction == 1) != visible) continue;
            if (visible) {
                choices[0] = @intCast(i);
                count = 1;
                nearest = distance;
            } else {
                choices[count] = @intCast(i);
                count += 1;
                if (count == choices.len) break;
            }
        }
        if (count != 0) {
            const selected = choices[@min(count - 1, @as(usize, @intFromFloat(random.next() * @as(f32, @floatFromInt(count)))))];
            if (visible or shortRoute(routes, pose.position, selected)) {
                const point = routes.nodes[selected].position;
                if (try routes.next(pose.position, point, body, slot) != null) {
                    destination = point;
                    duration = 5000;
                }
            }
        }
    }
    if (destination == null) destination = try @import("actor_motion.zig").sidestepDistance(pose, body, slot, random.next(), switch (kind) {
        .sidestep => 96,
        .strafe => 80,
        .dodge => 128,
    });
    begin(actor, pose, destination orelse return false, kind, now + duration);
    return true;
}
/// A side-step across the actor's facing (reference TASKTYPE_SIDESTEP), which classes request
/// when their shot is blocked. Actors that may not move never step.
pub fn sidestep(world: *data.World, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, now: i64) !bool {
    if (!spawnflags.moves((try world.get(entity, data.MapObject)).flags)) return false;
    const point = try @import("actor_motion.zig").sidestepDistance(pose, (try world.get(entity, data.Body)).*, (try world.get(entity, data.Binding)).slot, (try world.get(entity, data.Random)).next(), 96) orelse return false;
    begin(actor, pose, point, .sidestep, now + 2000);
    return true;
}
fn begin(actor: *data.Actor, pose: data.Transform, point: v.Vec3, kind: policy.Kind, until_ms: i64) void {
    actor.evasion = .{ .until_ms = until_ms, .destination = point, .kind = kind, .yaw = pose.angles[1] };
    actor.melee.active = false;
    actor.threat_position = point;
    actor.mode = .chase;
}
fn shortRoute(routes: *const Routes, origin: v.Vec3, target: u16) bool {
    var closest: ?u16 = null;
    var distance: f32 = std.math.inf(f32);
    for (routes.nodes, 0..) |node, i| {
        const d = v.length(v.subtract(node.position, origin));
        if (d < distance) {
            distance = d;
            closest = @intCast(i);
        }
    }
    const first = closest orelse return false;
    var queue: [4096]u16 = undefined;
    var depth: [4096]u8 = @splat(255);
    queue[0] = first;
    depth[first] = 0;
    var read: usize = 0;
    var count: usize = 1;
    while (read < count) : (read += 1) {
        const index = queue[read];
        if (index == target) return true;
        if (depth[index] >= 2) continue;
        for (routes.nodes[index].links) |link| {
            const next = routes.indices[@intCast(link[1])].?;
            if (depth[next] != 255) continue;
            depth[next] = depth[index] + 1;
            queue[count] = next;
            count += 1;
        }
    }
    return false;
}
