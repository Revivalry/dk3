// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: vermin. Server adapter for the vermin class.
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
const policy = @import("actor_catalog").vermin;
pub fn think(routes: *const @import("../../../../mechanics/server/air_routes.zig").Routes, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, definition: Definition, now: i64) !void {
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
    // The hit that makes its attacker the enemy starts the fight instead of a flinch.
    if (injured and try @import("../../../../mechanics/server/actor_pain.zig").generic(world, entity, actor, definition, hurt, previous_threat, policy.pain_chance, policy.pain_limit, now)) return;
    const target = sensed.enemy orelse {
        actor.melee.active = false;
        actor.mode = .idle;
        return;
    };
    if (@import("../../../../mechanics/server/actor_evasion.zig").update(actor, pose.*, now)) return;
    const delta = v.subtract(actor.threat_position, pose.position);
    const yaw = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
    const tick = now >= actor.think_ms;
    if (tick) {
        pose.angles[1] += std.math.clamp(@mod(yaw - pose.angles[1] + 180, 360) - 180, -definition.yaw_speed, definition.yaw_speed);
        actor.think_ms = now + 100;
    }
    const facing = @abs(@mod(yaw - pose.angles[1] + 180, 360) - 180) <= 5;
    if (now < actor.vermin.ready_ms) {
        actor.mode = .attack;
        return;
    }
    const chosen = policy.select(sensed.distance) orelse {
        actor.melee.active = false;
        actor.mode = .chase;
        return;
    };
    const current = if (actor.melee.pose == 3) @as(u3, 1) else actor.melee.pose;
    if (actor.melee.active and current != chosen) actor.melee.active = false;
    if (actor.melee.active) {
        try emit(world, slots, projections, entity, actor, pose.*, definition, target, facing, now);
        if (now - actor.melee.started_ms >= definition.attacks[actor.melee.pose].lastFrameMs()) actor.melee.active = false;
    }
    if (!actor.melee.active and tick and facing and sensed.visible) {
        if (try @import("../../../../mechanics/server/actor_evasion.zig").targeted(world, entity, target, pose.*) and (try world.get(entity, data.Random)).next() > 0.75 and try @import("../../../../mechanics/server/actor_evasion.zig").start(routes, world, entity, target, actor, pose.*, true, now)) return;
        actor.melee.begin(chosen, now);
        actor.changed_ms = now;
    }
    actor.mode = if (actor.melee.active) .attack else if (sensed.visible) .idle else .chase;
    if (actor.melee.active) try emit(world, slots, projections, entity, actor, pose.*, definition, target, facing, now);
}
fn emit(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, definition: Definition, target: Ref, facing: bool, now: i64) !void {
    const index = actor.melee.pose;
    const sequence = definition.attacks[index];
    const slot = (try world.get(entity, data.Binding)).slot;
    try @import("../../../../mechanics/server/actor_attack_sounds.zig").emit(world, slots, projections, entity, actor, pose.position, definition, now);
    const jump = index == 1 or index == 3;
    const first = actor.melee.event(1, @divTrunc(@as(i64, definition.strikes[index]) * 1000, sequence.fps), now, false);
    if (jump and first) {
        const velocity = try world.get(entity, data.Velocity);
        velocity.linear = v.scale(v.basis(pose.angles).forward, definition.speed * 1.5);
        velocity.linear[2] = definition.upward_speed * 0.5;
        actor.ground_entity = c.ENTITYNUM_NONE;
        if (index == 1 and definition.attack_present[3]) {
            actor.melee.begin(3, now);
            return;
        }
    }
    // The leap strikes on its clip's second attack frame; none is authored, so it never bites.
    const strike = if (jump) if (definition.second_strikes[index]) |frame| actor.melee.event(2, @divTrunc(@as(i64, frame) * 1000, sequence.fps), now, false) else false else first;
    if (!strike or (index != 0 and !facing)) return;
    if (index == 2) {
        try @import("../../../../mechanics/server/actor_rockets.zig").launch(world, slots, projections, entity, target, pose, .vermin, definition.tuning(@import("actor_catalog").vermin).rocket, now);
        actor.vermin.ready_ms = now + 1500;
        return;
    }
    const aim = try @import("../../../../mechanics/server/actor_aim.zig").lead(world, target, pose, definition.offset, try world.get(entity, data.Random));
    const hit = try @import("../../../../mechanics/server/region_collision.zig").from(aim.world, .{ .start = aim.origin, .end = v.add(aim.origin, v.scale(aim.direction, definition.range)), .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = c.MASK_SHOT }, try world.persistentId(entity));
    if (@import("../../../../mechanics/server/region_access.zig").victim(world, slots, hit)) |victim| {
        if ((victim.get(data.Health) catch null) == null) return;
        const amount = definition.damage + (try world.get(entity, data.Random)).next() * definition.random_damage;
        const source = try world.persistentId(entity);
        _ = try @import("../../../../mechanics/server/damage.zig").apply(victim.world, victim.entity, @intFromFloat(@ceil(amount)), now, .{ .source = source, .attacker_class = "monster_venomvermin" });
        try @import("../../../../mechanics/server/ailments.zig").apply(victim.world, victim.entity, .{ .poison = .{ .damage = 1, .duration_ms = 15000, .interval_ms = 3000 } }, source, 0, now);
        if (definition.second_attack_sounds[index].len > 0) try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, definition.second_attack_sounds[index], pose.position, slot, c.CHAN_WEAPON, now);
    }
}
