// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: archers. Server adapter for the archers class.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const Ref = @import("../../../../mechanics/domain/world_references.zig").Ref;
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const engine = @import("../../../../engine/server.zig");
const c = abi.c;
const v = @import("../../../../core/domain/vector.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const Definition = @import("../../../../mechanics/domain/actors.zig").Definition;
const catalog = @import("actor_catalog");
const policy = catalog.archers;
pub fn think(routes: *const @import("../../../../mechanics/server/air_routes.zig").Routes, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, definition: Definition, now: i64) !void {
    const kind: policy.Kind = if (catalog.entries[actor.definition].kind == .centurion) .centurion else .fletcher;
    const hurt = (try world.get(entity, data.Hurt)).*;
    const injured = hurt.revision != actor.receipt;
    const previous_threat = actor.threat;
    const sensed = try @import("../../../../mechanics/server/actor_perception.zig").perceive(world, slots, entity, actor, pose.*, definition, now);
    if (actor.reaction_until_ms) |until| {
        if (now < until) {
            actor.mode = .idle;
            return;
        }
        actor.reaction = null;
        actor.reaction_until_ms = null;
    }
    if (injured and kind == .fletcher and try @import("../../../../mechanics/server/actor_pain.zig").generic(world, entity, actor, definition, hurt, previous_threat, 20, 25, now)) return;
    const pain = @import("../../../../mechanics/server/actor_pain.zig");
    if (injured and kind == .centurion and !pain.acquiring(world, hurt, previous_threat) and try pain.direct(world, entity, actor, definition, hurt.amount, policy.centurion_pain_chance, now)) return;
    const target = sensed.enemy orelse {
        actor.melee.active = false;
        actor.mode = .idle;
        return;
    };
    if (actor.archer.sidestep_until) |until| {
        if (now < until and v.length(v.subtract(actor.archer.destination, pose.position)) >= 16) {
            actor.threat_position = actor.archer.destination;
            actor.mode = .chase;
            return;
        }
        actor.archer.sidestep_until = null;
    }
    if (@import("../../../../mechanics/server/actor_evasion.zig").update(actor, pose.*, now)) return;
    const delta = v.subtract(actor.threat_position, pose.position);
    const yaw = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
    const tick = now >= actor.think_ms;
    if (tick) {
        pose.angles[1] += std.math.clamp(@mod(yaw - pose.angles[1] + 180, 360) - 180, -definition.yaw_speed, definition.yaw_speed);
        actor.think_ms = now + 100;
    }
    const facing = @abs(@mod(yaw - pose.angles[1] + 180, 360) - 180) <= 5;
    var completed = false;
    if (actor.melee.active) {
        try emit(world, slots, projections, entity, actor, pose.*, definition, target, kind, facing, now);
        if (actor.archer.sidestep_until != null) {
            actor.threat_position = actor.archer.destination;
            actor.mode = .chase;
            return;
        }
        if (now - actor.melee.started_ms >= definition.attacks[actor.melee.pose].lastFrameMs()) {
            completed = true;
            const melee = kind == .centurion and actor.melee.pose == 0;
            actor.melee.active = false;
            if (sensed.visible and sensed.distance < (if (melee) definition.range else definition.tuning(catalog.archers).ranged.range) and (melee or try @import("../../../../mechanics/server/actor_evasion.zig").targeted(world, entity, target, pose.*))) {
                const roll = (try world.get(entity, data.Random)).next();
                if ((if (kind == .fletcher) roll <= 0.3 else roll > 0.75) and try @import("../../../../mechanics/server/actor_evasion.zig").start(routes, world, entity, target, actor, pose.*, true, now)) return;
            }
        }
    }
    const in_range = sensed.distance < policy.reach(kind, actor.melee.pose, definition.range, definition.tuning(catalog.archers).ranged.range);
    if (!actor.melee.active and tick and now >= actor.archer.ready_ms and facing and sensed.visible and in_range) {
        if (!completed and try @import("../../../../mechanics/server/actor_evasion.zig").targeted(world, entity, target, pose.*)) {
            const roll = (try world.get(entity, data.Random)).next();
            if ((if (kind == .fletcher) roll <= 0.3 else roll > 0.75) and try @import("../../../../mechanics/server/actor_evasion.zig").start(routes, world, entity, target, actor, pose.*, true, now)) return;
        }
        actor.melee.begin(policy.select(kind, sensed.distance, definition.range), now);
        actor.archer.clear_ms = now;
        actor.changed_ms = now;
    }
    actor.mode = if (actor.melee.active) .attack else if (in_range and sensed.visible) .idle else .chase;
    if (actor.melee.active) try emit(world, slots, projections, entity, actor, pose.*, definition, target, kind, facing, now);
    if (actor.archer.sidestep_until != null) {
        actor.threat_position = actor.archer.destination;
        actor.mode = .chase;
    }
}
fn sidestep(world: *data.World, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, now: i64) !void {
    if (try @import("../../../../mechanics/server/actor_motion.zig").sidestep(pose, (try world.get(entity, data.Body)).*, (try world.get(entity, data.Binding)).slot, (try world.get(entity, data.Random)).next())) |point| {
        actor.archer.destination = point;
        actor.archer.sidestep_until = now + 2000;
        actor.melee.active = false;
    }
}
fn emit(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, definition: Definition, target: Ref, kind: policy.Kind, facing: bool, now: i64) !void {
    const index = actor.melee.pose;
    const sequence = definition.attacks[index];
    const slot = (try world.get(entity, data.Binding)).slot;
    try @import("../../../../mechanics/server/actor_attack_sounds.zig").emit(world, slots, projections, entity, actor, pose.position, definition, now);
    if (kind == .fletcher and facing and now >= actor.archer.clear_ms) {
        actor.archer.clear_ms = now + 100;
        if (!try @import("../../../../mechanics/server/actor_aim.zig").clearProjectile(world, slots, entity, target, pose, definition.tuning(catalog.archers).ranged, 0)) {
            try sidestep(world, entity, actor, pose, now);
            return;
        }
    }
    if (kind == .fletcher and !facing) return;
    if (!actor.melee.event(1, @divTrunc(@as(i64, definition.strikes[index]) * 1000, sequence.fps), now, false) or !facing) return;
    if (kind == .fletcher or index == 1) {
        if (kind == .centurion and !try @import("../../../../mechanics/server/actor_aim.zig").clearProjectile(world, slots, entity, target, pose, definition.tuning(catalog.archers).ranged, 0)) {
            try sidestep(world, entity, actor, pose, now);
            return;
        }
        try @import("../../../../mechanics/server/shafts.zig").launch(world, slots, projections, entity, target, pose, if (kind == .centurion) .centurion else .fletcher, definition.tuning(catalog.archers).ranged, now);
        if (kind == .centurion) actor.archer.ready_ms = now + 750;
        return;
    }
    const aim = try @import("../../../../mechanics/server/actor_aim.zig").lead(world, target, pose, definition.offset, try world.get(entity, data.Random));
    const hit = try @import("../../../../mechanics/server/region_collision.zig").from(aim.world, .{ .start = aim.origin, .end = v.add(aim.origin, v.scale(aim.direction, definition.range)), .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = c.MASK_SHOT }, try world.persistentId(entity));
    if (@import("../../../../mechanics/server/region_access.zig").victim(world, slots, hit)) |victim| {
        if ((victim.get(data.Health) catch null) == null) return;
        const amount = definition.damage + (try world.get(entity, data.Random)).next() * definition.random_damage;
        _ = try @import("../../../../mechanics/server/damage.zig").apply(victim.world, victim.entity, @intFromFloat(@ceil(amount)), now, .{ .source = try world.persistentId(entity), .attacker_class = "monster_centurion" });
        if (definition.second_attack_sounds[index].len > 0) try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, definition.second_attack_sounds[index], pose.position, slot, c.CHAN_WEAPON, now);
    }
}
