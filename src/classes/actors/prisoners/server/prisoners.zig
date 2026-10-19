// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: prisoners. Server adapter for the prisoners class.
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
const policy = catalog.prisoners;
pub fn think(routes: *const @import("../../../../mechanics/server/air_routes.zig").Routes, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, definition: Definition, now: i64) !void {
    const white = catalog.entries[actor.definition].kind == .whiteprisoner;
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
    if (injured and try @import("../../../../mechanics/server/actor_pain.zig").generic(world, entity, actor, definition, hurt, previous_threat, if (white) 20 else 10, if (white) 40 else 35, now)) {
        actor.evasion.until_ms = null;
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
    var completed = false;
    if (actor.melee.active) {
        if (now >= actor.prisoner.emit_ms) {
            try emit(world, slots, projections, entity, actor, pose.*, definition, target, facing, now);
            actor.prisoner.emit_ms = now + 100;
        }
        if (now - actor.melee.started_ms >= definition.attacks[actor.melee.pose].lastFrameMs()) {
            actor.melee.active = false;
            completed = true;
            if (sensed.distance <= definition.attack_range and sensed.visible and try @import("../../../../mechanics/server/actor_evasion.zig").targeted(world, entity, target, pose.*) and (try world.get(entity, data.Random)).next() < 0.3 and try @import("../../../../mechanics/server/actor_evasion.zig").start(routes, world, entity, target, actor, pose.*, false, now)) return;
        }
    }
    if (!actor.melee.active and tick and sensed.visible and (completed or now >= actor.prisoner.ready_ms)) {
        const random = try world.get(entity, data.Random);
        const admitted = if (completed) sensed.distance <= definition.attack_range else policy.inRange(sensed.distance, definition.attack_range, random.next());
        if (admitted) {
            actor.melee.begin(policy.select(sensed.distance, definition.attack_range, random.next()), now);
            actor.prisoner.emit_ms = now;
            actor.changed_ms = now;
            if (!completed) actor.prisoner.ready_ms = now + 1000;
        }
    }
    actor.mode = if (actor.melee.active) .attack else .chase;
}
fn emit(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, definition: Definition, target: Ref, facing: bool, now: i64) !void {
    try @import("../../../../mechanics/server/actor_attack_sounds.zig").emit(world, slots, projections, entity, actor, pose.position, definition, now);
    const index = actor.melee.pose;
    const first = actor.melee.event(1, @divTrunc(@as(i64, definition.strikes[index]) * 1000, definition.attacks[index].fps), now, false);
    const strike = first or if (definition.second_strikes[index]) |frame| actor.melee.event(2, @divTrunc(@as(i64, frame) * 1000, definition.attacks[index].fps), now, false) else false;
    if (!strike or !facing) return;
    if (index == 3) return @import("prisoner_rocks.zig").launch(world, slots, projections, entity, target, pose, definition.tuning(catalog.prisoners).rock, now);
    const aim = try @import("../../../../mechanics/server/actor_aim.zig").lead(world, target, pose, definition.offset, try world.get(entity, data.Random));
    const hit = try @import("../../../../mechanics/server/region_collision.zig").from(aim.world, .{ .start = aim.origin, .end = v.add(aim.origin, v.scale(aim.direction, definition.range)), .mins = @splat(0), .maxs = @splat(0), .slot = (try world.get(entity, data.Binding)).slot, .mask = c.MASK_SHOT }, try world.persistentId(entity));
    // The punch sounds whenever its trace hits anything, a wall too.
    if ((hit.fraction < 1 or hit.start_solid) and definition.second_attack_sounds[index].len > 0) try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, definition.second_attack_sounds[index], pose.position, (try world.get(entity, data.Binding)).slot, c.CHAN_WEAPON, now);
    if (@import("../../../../mechanics/server/region_access.zig").victim(world, slots, hit)) |victim| {
        if ((victim.get(data.Health) catch null) == null) return;
        const amount = definition.damage + (try world.get(entity, data.Random)).next() * definition.random_damage;
        _ = try @import("../../../../mechanics/server/damage.zig").apply(victim.world, victim.entity, @intFromFloat(@ceil(amount)), now, .{ .source = try world.persistentId(entity), .attacker_class = catalog.entries[actor.definition].classname });
    }
}
