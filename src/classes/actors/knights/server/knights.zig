// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: knights. Server adapter for the knights class.
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
const policy = catalog.knights;
pub fn think(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, definition: Definition, now: i64) !void {
    const hurt = (try world.get(entity, data.Hurt)).*;
    const injured = hurt.revision != actor.receipt;
    const previous_threat = actor.threat;
    const perceived = try @import("../../../../mechanics/server/actor_perception.zig").perceive(world, slots, entity, actor, pose.*, definition, now);
    actor.knight.sword_lit = perceived.visible;
    if (actor.reaction_until_ms) |until| {
        if (now < until) {
            actor.mode = .idle;
            return;
        }
        actor.reaction = null;
        actor.reaction_until_ms = null;
    }
    // Knight1's own pain callback is never installed in the reference: only the shared single roll.
    // Knight2 uses the generic handler.
    const pain = @import("../../../../mechanics/server/actor_pain.zig");
    if (injured) {
        const knight2 = catalog.entries[actor.definition].kind == .knight2;
        const flinched = if (knight2)
            try pain.generic(world, entity, actor, definition, hurt, previous_threat, policy.pain_chance, policy.knight2_pain_limit, now)
        else
            !pain.acquiring(world, hurt, previous_threat) and try pain.direct(world, entity, actor, definition, hurt.amount, policy.pain_chance, now);
        if (flinched) return;
    }
    const target = perceived.enemy orelse {
        actor.mode = .idle;
        actor.melee.active = false;
        return;
    };
    if (actor.knight.sidestep_until) |until| {
        if (now < until and v.length(v.subtract(actor.knight.destination, pose.position)) >= 16) {
            actor.mode = .chase;
            actor.threat_position = actor.knight.destination;
            return;
        }
        actor.knight.sidestep_until = null;
    }
    const delta = v.subtract(actor.threat_position, pose.position);
    const yaw = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
    const tick = now >= actor.think_ms;
    if (tick) {
        pose.angles[1] += std.math.clamp(@mod(yaw - pose.angles[1] + 180, 360) - 180, -definition.yaw_speed, definition.yaw_speed);
        actor.think_ms = now + 100;
    }
    const facing = @abs(@mod(yaw - pose.angles[1] + 180, 360) - 180) <= 5;
    if (actor.melee.active) {
        try emit(world, slots, projections, entity, actor, pose.*, definition, target, facing, now);
        if (actor.knight.sidestep_until != null) {
            actor.mode = .chase;
            actor.threat_position = actor.knight.destination;
            return;
        }
        if (now - actor.melee.started_ms >= definition.attacks[actor.melee.pose].lastFrameMs()) actor.melee.active = false;
    }
    if (!actor.melee.active and tick and facing and perceived.visible) {
        const random = try world.get(entity, data.Random);
        if (policy.inRange(perceived.distance, definition.range, definition.tuning(catalog.knights).ranged.range, random.next(), random.next())) {
            actor.melee.begin(policy.select(perceived.distance), now);
            actor.changed_ms = now;
        }
    }
    actor.mode = if (actor.melee.active) .attack else .chase;
    if (actor.melee.active) try emit(world, slots, projections, entity, actor, pose.*, definition, target, facing, now);
}
fn emit(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, definition: Definition, target: Ref, facing: bool, now: i64) !void {
    const index = actor.melee.pose;
    const sequence = definition.attacks[index];
    const slot = (try world.get(entity, data.Binding)).slot;
    try @import("../../../../mechanics/server/actor_attack_sounds.zig").emit(world, slots, projections, entity, actor, pose.position, definition, now);
    if (!actor.melee.event(1, @divTrunc(@as(i64, definition.strikes[index]) * 1000, sequence.fps), now, false) or !facing) return;
    const lightning = catalog.entries[actor.definition].kind == .knight2;
    if (index == 1) {
        if (!try @import("../../../../mechanics/server/actor_aim.zig").clearProjectile(world, slots, entity, target, pose, definition.tuning(catalog.knights).ranged, 0)) {
            if (try @import("../../../../mechanics/server/actor_motion.zig").sidestep(pose, (try world.get(entity, data.Body)).*, slot, (try world.get(entity, data.Random)).next())) |point| {
                actor.knight.destination = point;
                actor.knight.sidestep_until = now + 2000;
                actor.melee.active = false;
            }
            return;
        }
        if (lightning) try @import("knight_attacks.zig").zap(world, slots, projections, entity, target, pose, now) else try @import("../../../../mechanics/server/actor_fireballs.zig").launch(world, slots, projections, entity, target, pose, .knight, definition.tuning(catalog.knights).ranged, now);
        return;
    }
    const aim = try @import("../../../../mechanics/server/actor_aim.zig").lead(world, target, pose, definition.offset, try world.get(entity, data.Random));
    const hit = try @import("../../../../mechanics/server/region_collision.zig").from(aim.world, .{ .start = aim.origin, .end = v.add(aim.origin, v.scale(aim.direction, definition.range)), .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = c.MASK_SHOT }, try world.persistentId(entity));
    if (@import("../../../../mechanics/server/region_access.zig").victim(world, slots, hit)) |victim| {
        if ((victim.get(data.Health) catch null) == null) return;
        const amount = definition.damage + (try world.get(entity, data.Random)).next() * definition.random_damage;
        _ = try @import("../../../../mechanics/server/damage.zig").apply(victim.world, victim.entity, @intFromFloat(@ceil(amount)), now, .{ .source = try world.persistentId(entity), .attacker_class = catalog.entries[actor.definition].classname });
        if (lightning) {
            try @import("knight_attacks.zig").punch(world, slots, projections, entity, pose, now);
            if ((victim.get(data.Actor) catch null) != null or (victim.get(data.Player) catch null) != null) {
                var impulse = v.scale(v.basis(pose.angles).forward, amount * 30);
                impulse[2] = 40 + amount;
                const velocity = try victim.get(data.Velocity);
                velocity.linear = v.add(velocity.linear, impulse);
                (try victim.get(data.Body)).grounded = false;
                if (victim.get(data.Actor) catch null) |other| other.ground_entity = c.ENTITYNUM_NONE;
                if (victim.get(data.Player) catch null) |other| other.ground_entity = c.ENTITYNUM_NONE;
            }
        }
    }
}
