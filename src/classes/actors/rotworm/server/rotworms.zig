// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: rotworm. Server adapter for the rotworm class.
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
const policy = @import("actor_catalog").rotworm;
pub fn initialize(world: *data.World, entity: ecs.Entity, now: i64) !void {
    const object = (try world.get(entity, data.MapObject)).*;
    if (object.flags & 0x800 == 0) return;
    const pose = try world.get(entity, data.Transform);
    const body = (try world.get(entity, data.Body)).*;
    const hit = try @import("../../../../mechanics/server/actor_collision.zig").service().trace(.{ .start = pose.position, .end = v.add(pose.position, .{ 0, 0, 10000 }), .mins = @splat(0), .maxs = @splat(0), .slot = (try world.get(entity, data.Binding)).slot, .mask = c.MASK_SOLID });
    if (hit.fraction == 1 or hit.start_solid) return error.InvalidRotwormCeiling;
    const distance = hit.end[2] - pose.position[2];
    const height = body.maxs[2] - body.mins[2];
    if (distance > height) pose.position[2] += distance - height;
    pose.angles[0] = 90;
    const actor = try world.get(entity, data.Actor);
    actor.rotworm.phase = .ceiling;
    actor.think_ms = now + 100;
}
pub fn think(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, definition: Definition, now: i64) !void {
    const state = &actor.rotworm;
    const tick = now >= actor.think_ms;
    if (state.phase == .ceiling and !tick) {
        actor.mode = .idle;
        return;
    }
    const hurt = (try world.get(entity, data.Hurt)).*;
    const injured = hurt.revision != actor.receipt;
    const previous_threat = actor.threat;
    const sensed = try @import("../../../../mechanics/server/actor_perception.zig").perceive(world, slots, entity, actor, pose.*, definition, now);
    if (tick) actor.think_ms = now + (if (state.phase == .ceiling) @as(i64, 300) else 100);
    if (state.phase == .flight or state.phase == .jump_bite) state.phase = .ground;
    const pain = @import("../../../../mechanics/server/actor_pain.zig");
    if (injured and !pain.acquiring(world, hurt, previous_threat) and try pain.direct(world, entity, actor, definition, hurt.amount, policy.pain_chance, now)) actor.melee.active = false;
    if (actor.reaction_until_ms) |until| {
        if (now < until) {
            actor.mode = .idle;
            return;
        }
        actor.reaction = null;
        actor.reaction_until_ms = null;
    }
    if (state.phase == .ceiling) {
        actor.mode = .idle;
        // Native drops on any visible enemy in sight range; the reference only on a fresh
        // acquisition by its own scan, so a worm shot while hanging stayed up for good.
        if (sensed.enemy != null and sensed.visible and sensed.distance < definition.sight_range) state.phase = .ground;
        return;
    }
    const target = sensed.enemy orelse {
        actor.melee.active = false;
        actor.mode = .idle;
        return;
    };
    pose.angles[0] = 0;
    const delta = v.subtract(actor.threat_position, pose.position);
    const yaw = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
    if (tick) pose.angles[1] += std.math.clamp(@mod(yaw - pose.angles[1] + 180, 360) - 180, -definition.yaw_speed, definition.yaw_speed);
    if (actor.melee.active) {
        try emit(world, slots, projections, entity, actor, pose.*, definition, target, now);
        if (now - actor.melee.started_ms >= definition.attacks[actor.melee.pose].lastFrameMs()) {
            actor.melee.active = false;
            actor.mode = .chase;
            return;
        }
        actor.mode = .attack;
        return;
    }
    actor.mode = .chase;
    if (!tick or !sensed.visible) return;
    // It chases until its enemy is within the spit's reach (its starting weapon), then bites or spits.
    if (sensed.distance < definition.tuning(policy).spit.range) {
        actor.melee.begin(policy.select(sensed.distance, (try world.get(entity, data.Random)).next()), now);
        actor.mode = .attack;
        actor.changed_ms = now;
        try emit(world, slots, projections, entity, actor, pose.*, definition, target, now);
    }
}
fn emit(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, definition: Definition, target: Ref, now: i64) !void {
    const index = actor.melee.pose;
    const sequence = definition.attacks[index];
    const slot = (try world.get(entity, data.Binding)).slot;
    try @import("../../../../mechanics/server/actor_attack_sounds.zig").emit(world, slots, projections, entity, actor, pose.position, definition, now);
    if (!actor.melee.event(1, @divTrunc(@as(i64, definition.strikes[index]) * 1000, sequence.fps), now, false)) return;
    if (index == 1) return @import("../../../../mechanics/server/venom_spit.zig").launch(world, slots, projections, entity, target, pose, .rotworm, definition.tuning(@import("actor_catalog").rotworm).spit, now);
    const aim = try @import("../../../../mechanics/server/actor_aim.zig").lead(world, target, pose, definition.offset, try world.get(entity, data.Random));
    const hit = try @import("../../../../mechanics/server/actor_collision.zig").service().trace(.{ .start = aim.origin, .end = v.add(aim.origin, v.scale(aim.direction, definition.range)), .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = c.MASK_SHOT });
    if (@import("../../../../mechanics/server/region_access.zig").victim(world, slots, hit)) |victim| {
        if ((victim.get(data.Health) catch null) == null) return;
        const amount = definition.damage + (try world.get(entity, data.Random)).next() * definition.random_damage;
        const source = try world.persistentId(entity);
        _ = try @import("../../../../mechanics/server/damage.zig").apply(victim.world, victim.entity, @intFromFloat(@ceil(amount)), now, .{ .source = source, .attacker_class = "monster_rotworm" });
        try @import("../../../../mechanics/server/ailments.zig").apply(victim.world, victim.entity, .{ .poison = .{ .damage = 1, .duration_ms = 15000, .interval_ms = 3000 } }, source, 0, now);
    }
}
