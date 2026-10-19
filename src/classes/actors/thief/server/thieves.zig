// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: thief. Server adapter for the thief class.
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
const policy = @import("actor_catalog").thief;
pub fn think(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, definition: Definition, now: i64) !void {
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
    if (injured and try @import("../../../../mechanics/server/actor_pain.zig").generic(world, entity, actor, definition, hurt, previous_threat, 30, 35, now)) {
        return;
    }
    const target = sensed.enemy orelse {
        actor.melee.active = false;
        actor.mode = .idle;
        return;
    };
    if (actor.thief.sidestep_until) |until| {
        if (now < until and v.length(v.subtract(actor.thief.destination, pose.position)) >= 16) {
            actor.threat_position = actor.thief.destination;
            actor.mode = .chase;
            return;
        }
        actor.thief.sidestep_until = null;
    }
    const delta = v.subtract(actor.threat_position, pose.position);
    const yaw = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
    const tick = now >= actor.think_ms;
    if (tick) {
        pose.angles[1] += std.math.clamp(@mod(yaw - pose.angles[1] + 180, 360) - 180, -definition.yaw_speed, definition.yaw_speed);
        actor.think_ms = now + 100;
    }
    const facing = @abs(@mod(yaw - pose.angles[1] + 180, 360) - 180) <= 5;
    // The reference's ranged callback schedules its next think a second away, but the attack task
    // resets it to 100 ms at once: the thief attacks on every think.
    if (actor.melee.active and now >= actor.thief.next_attack_ms) {
        try emit(world, slots, projections, entity, actor, pose.*, definition, target, facing, now);
        actor.thief.next_attack_ms = now + 100;
        if (actor.thief.sidestep_until != null) {
            actor.threat_position = actor.thief.destination;
            actor.mode = .chase;
            return;
        }
        if (now - actor.melee.started_ms >= definition.attacks[actor.melee.pose].lastFrameMs()) actor.melee.active = false;
    }
    if (!actor.melee.active and tick and facing and sensed.visible) {
        const random = try world.get(entity, data.Random);
        if (policy.inRange(sensed.distance, definition.range, definition.tuning(@import("actor_catalog").thief).knife.range, random.next(), random.next())) {
            actor.melee.begin(policy.select(sensed.distance), now);
            actor.changed_ms = now;
            actor.thief.next_attack_ms = now;
        }
    }
    actor.mode = if (actor.melee.active) .attack else .chase;
}
fn emit(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, definition: Definition, target: Ref, facing: bool, now: i64) !void {
    try @import("../../../../mechanics/server/actor_attack_sounds.zig").emit(world, slots, projections, entity, actor, pose.position, definition, now);
    if (!facing) return;
    const index = actor.melee.pose;
    if (!actor.melee.event(1, @divTrunc(@as(i64, definition.strikes[index]) * 1000, definition.attacks[index].fps), now, false)) return;
    if (index == 0) {
        if (!try @import("../../../../mechanics/server/actor_aim.zig").clearProjectile(world, slots, entity, target, pose, definition.tuning(@import("actor_catalog").thief).knife, 0)) {
            if (try @import("../../../../mechanics/server/actor_motion.zig").sidestep(pose, (try world.get(entity, data.Body)).*, (try world.get(entity, data.Binding)).slot, (try world.get(entity, data.Random)).next())) |point| {
                actor.thief.destination = point;
                actor.thief.sidestep_until = now + 2000;
                actor.melee.active = false;
            }
            return;
        }
        return @import("../../../../mechanics/server/shafts.zig").launch(world, slots, projections, entity, target, pose, .thief, definition.tuning(@import("actor_catalog").thief).knife, now);
    }
    const aim = try @import("../../../../mechanics/server/actor_aim.zig").lead(world, target, pose, definition.offset, try world.get(entity, data.Random));
    const hit = try @import("../../../../mechanics/server/region_collision.zig").from(aim.world, .{ .start = aim.origin, .end = v.add(aim.origin, v.scale(aim.direction, definition.range)), .mins = @splat(0), .maxs = @splat(0), .slot = (try world.get(entity, data.Binding)).slot, .mask = c.MASK_SHOT }, try world.persistentId(entity));
    if (@import("../../../../mechanics/server/region_access.zig").victim(world, slots, hit)) |victim| {
        if ((victim.get(data.Health) catch null) == null) return;
        const amount = definition.damage + (try world.get(entity, data.Random)).next() * definition.random_damage;
        _ = try @import("../../../../mechanics/server/damage.zig").apply(victim.world, victim.entity, @intFromFloat(@ceil(amount)), now, .{ .source = try world.persistentId(entity), .attacker_class = "monster_thief" });
        if (definition.second_attack_sounds[index].len > 0) try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, definition.second_attack_sounds[index], pose.position, (try world.get(entity, data.Binding)).slot, c.CHAN_WEAPON, now);
    }
}
