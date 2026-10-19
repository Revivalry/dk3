// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: rocketgang. Server adapter for the rocketgang class.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const Ref = @import("../../../../mechanics/domain/world_references.zig").Ref;
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const v = @import("../../../../core/domain/vector.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const Definition = @import("../../../../mechanics/domain/actors.zig").Definition;
const policy = @import("actor_catalog").rocketgang;
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
    if (injured and try @import("../../../../mechanics/server/actor_pain.zig").generic(world, entity, actor, definition, hurt, previous_threat, 10, 50, now)) {
        return;
    }
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
    if (actor.melee.active) {
        try emit(world, slots, projections, entity, actor, pose.*, definition, target, facing, now);
        if (now - actor.melee.started_ms >= definition.attacks[actor.melee.pose].lastFrameMs()) {
            actor.melee.active = false;
            if (sensed.visible and sensed.distance < definition.tuning(@import("actor_catalog").rocketgang).rockets[actor.rocketgang.selected].range and try @import("../../../../mechanics/server/actor_evasion.zig").targeted(world, entity, target, pose.*) and (try world.get(entity, data.Random)).next() > 0.2 and try @import("../../../../mechanics/server/actor_evasion.zig").start(routes, world, entity, target, actor, pose.*, true, now)) return;
        }
    }
    // A rocketeer that may not move fires at any range it sees; facing only gates the shot.
    const stationary = !@import("actor_catalog").spawnflags.moves((try world.get(entity, data.MapObject)).flags);
    const in_range = stationary or sensed.distance < definition.tuning(@import("actor_catalog").rocketgang).rockets[actor.rocketgang.selected].range;
    if (!actor.melee.active and tick and sensed.visible and in_range) {
        if (try @import("../../../../mechanics/server/actor_evasion.zig").targeted(world, entity, target, pose.*) and (try world.get(entity, data.Random)).next() > 0.5 and try @import("../../../../mechanics/server/actor_evasion.zig").start(routes, world, entity, target, actor, pose.*, true, now)) return;
        actor.rocketgang.selected = policy.select(sensed.distance);
        actor.melee.begin(actor.rocketgang.selected, now);
        actor.changed_ms = now;
    }
    actor.mode = if (actor.melee.active) .attack else if (in_range and sensed.visible) .idle else .chase;
    if (actor.melee.active) try emit(world, slots, projections, entity, actor, pose.*, definition, target, facing, now);
}
fn emit(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, definition: Definition, target: Ref, facing: bool, now: i64) !void {
    try @import("../../../../mechanics/server/actor_attack_sounds.zig").emit(world, slots, projections, entity, actor, pose.position, definition, now);
    if (!facing) return;
    // The reference refreshes this deadline throughout the facing attack sequence; only its
    // take-cover attack reads it, so volleys follow each other without rest.
    actor.rocketgang.ready_ms = now + 2000;
    const index = actor.melee.pose;
    if (!actor.melee.event(1, @divTrunc(@as(i64, definition.strikes[index]) * 1000, definition.attacks[index].fps), now, false)) return;
    try @import("../../../../mechanics/server/actor_rockets.zig").launch(world, slots, projections, entity, target, pose, .rocketdude, definition.tuning(@import("actor_catalog").rocketgang).rockets[index], now);
}
