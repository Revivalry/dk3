// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: battleboar. Server adapter for the battleboar class.
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
const policy = @import("actor_catalog").battleboar;

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
    // A hit clip played over its task ends on its own clock.
    if (actor.reaction != null and now >= actor.battleboar.flinch_until_ms) actor.reaction = null;
    if (injured and now > actor.pain_ready_ms) {
        const random = try world.get(entity, data.Random);
        const stops = hurt.amount > 0 and !@import("../../../../mechanics/server/actor_pain.zig").acquiring(world, hurt, previous_threat) and @as(u8, @intFromFloat(random.next() * 99.9)) < policy.pain_chance;
        const clips = [3]?@import("../../../../core/domain/animation.zig").Sequence{ definition.pain[0], definition.pain[1], definition.pain_c };
        if (if (stops) definition.pain[0] else clips[policy.hitClip(random.next())]) |hit| {
            actor.reaction = hit;
            actor.reaction_started_ms = now;
            actor.pain_ready_ms = now + @divTrunc(@as(i64, hit.last - hit.first) * 1000, hit.fps);
            if (stops) {
                actor.reaction_until_ms = now + hit.lastFrameMs();
                actor.melee.active = false;
                actor.battleboar.flashed = false;
                actor.mode = .idle;
                return;
            }
            actor.battleboar.flinch_until_ms = now + hit.lastFrameMs();
        }
    }
    const target = sensed.enemy orelse {
        actor.melee.active = false;
        actor.mode = .idle;
        return;
    };
    const delta = v.subtract(actor.threat_position, pose.position);
    const yaw = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
    const tick = now >= actor.think_ms;
    if (tick) {
        pose.angles[1] += std.math.clamp(@mod(yaw - pose.angles[1] + 180, 360) - 180, -definition.yaw_speed, definition.yaw_speed);
        actor.think_ms = now + 100;
    }
    const facing = @abs(@mod(yaw - pose.angles[1] + 180, 360) - 180) <= 5;
    const clear = try clearShot(world, entity, target, pose.*);
    if (actor.melee.active) {
        try emit(world, slots, projections, entity, actor, pose.*, definition, target, facing, clear, now);
        if (clear and now - actor.melee.started_ms >= definition.attacks[actor.melee.pose].lastFrameMs()) actor.melee.active = false;
    }
    const in_range = sensed.distance < definition.tuning(@import("actor_catalog").battleboar).weapons[actor.battleboar.selected].range;
    if (!actor.melee.active and tick and facing and sensed.visible and in_range) {
        actor.battleboar.selected = policy.select(sensed.distance, (try world.get(entity, data.Random)).next());
        actor.battleboar.flashed = false;
        actor.melee.begin(actor.battleboar.selected, now);
        actor.changed_ms = now;
    }
    actor.mode = if (actor.melee.active) .attack else .chase;
    if (actor.melee.active) try emit(world, slots, projections, entity, actor, pose.*, definition, target, facing, clear, now);
}
fn clearShot(world: *data.World, entity: ecs.Entity, target: Ref, pose: data.Transform) !bool {
    var end = v.add((try target.get(data.Transform)).position, .{ 0, 0, 12 });
    if (target.get(data.Player) catch null) |player| if (player.ducked) {
        end[2] -= 32;
    };
    const hit = try engine.collisionService().trace(.{ .start = v.add(pose.position, .{ 0, 0, 15 }), .end = end, .mins = @splat(0), .maxs = @splat(0), .slot = (try world.get(entity, data.Binding)).slot, .mask = c.MASK_SHOT });
    return hit.entity == (try target.get(data.Binding)).slot and (try target.get(data.Health)).current > 0;
}
fn emit(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, definition: Definition, target: Ref, facing: bool, clear: bool, now: i64) !void {
    try @import("../../../../mechanics/server/actor_attack_sounds.zig").emit(world, slots, projections, entity, actor, pose.position, definition, now);
    const index = actor.melee.pose;
    // The second authored strike is unused by the active Battleboar callback.
    if (!clear or !actor.melee.event(1, @divTrunc(@as(i64, definition.strikes[index]) * 1000, definition.attacks[index].fps), now, false) or !facing) return;
    if (index == 0) {
        _ = try @import("../../../../mechanics/server/actor_bullets.zig").fire(world, slots, projections, entity, target, pose, definition.tuning(@import("actor_catalog").battleboar).weapons[0], now);
        actor.battleboar.flashed = true;
    } else try @import("../../../../mechanics/server/actor_rockets.zig").launch(world, slots, projections, entity, target, pose, .battleboar, definition.tuning(@import("actor_catalog").battleboar).weapons[1], now);
}
