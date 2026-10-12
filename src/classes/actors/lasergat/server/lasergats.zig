// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: lasergat. Server adapter for the lasergat class.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const engine = @import("../../../../engine/server.zig");
const c = abi.c;
const v = @import("../../../../core/domain/vector.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const Definition = @import("../../../../mechanics/domain/actors.zig").Definition;
const policy = @import("actor_catalog").lasergat;
pub fn think(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, definition: Definition, now: i64) !void {
    const hurt = (try world.get(entity, data.Hurt)).*;
    const injured = hurt.revision != actor.receipt;
    const previous_threat = actor.threat;
    const perceived = try @import("../../../../mechanics/server/actor_perception.zig").perceive(world, slots, entity, actor, pose.*, definition, now);
    const target = perceived.enemy orelse {
        actor.mode = .idle;
        actor.melee.active = false;
        return;
    };
    // A hit from its enemy (not the one that made it the enemy) stalls the turret: it has no pain
    // clip, so the shot cycle restarts after a brief pause.
    if (injured and hurt.amount > 0 and hurt.source == previous_threat and now > actor.pain_ready_ms and (try world.get(entity, data.Random)).next() < policy.pain_chance) {
        actor.pain_ready_ms = now + policy.pain_lock_ms;
        actor.reaction_until_ms = now + policy.stall_ms;
        actor.melee.active = false;
        if (engine.integer("developer") != 0) {
            var message: [96]u8 = undefined;
            engine.print(try std.fmt.bufPrintZ(&message, "dk3 zig lasergat: id={d} stalled now={d}\n", .{ try world.persistentId(entity), now }));
        }
    }
    if (@import("../../../../mechanics/server/actor_pain.zig").reacting(actor, now)) return;
    const delta = v.subtract((try target.get(data.Transform)).position, pose.position);
    const desired: [2]f32 = .{ std.math.clamp(-std.math.atan2(delta[2], @sqrt(delta[0] * delta[0] + delta[1] * delta[1])) * 180 / std.math.pi, -60, 60), std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi };
    const tick = now >= actor.think_ms;
    if (tick) {
        actor.think_ms = now + 100;
        pose.angles[0] += std.math.clamp(@mod(desired[0] - pose.angles[0] + 180, 360) - 180, -definition.pitch_speed, definition.pitch_speed);
        pose.angles[1] += std.math.clamp(@mod(desired[1] - pose.angles[1] + 180, 360) - 180, -policy.turn_degrees, policy.turn_degrees);
    }
    actor.lasergat.turning = @abs(@mod(desired[1] - pose.angles[1] + 180, 360) - 180) > 1 or @abs(@mod(desired[0] - pose.angles[0] + 180, 360) - 180) > 2;
    // Out of sight it keeps turning toward its enemy but never fires; its weapon range never stops
    // it (the reference attack task restarts at the range check and fires again).
    if (actor.lasergat.turning or !perceived.visible) {
        actor.melee.active = false;
        actor.mode = .idle;
        if (actor.lasergat.turning and now >= actor.lasergat.servo_ms) {
            actor.lasergat.servo_ms = now + 400;
            try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, policy.servo_sound, pose.position, (try world.get(entity, data.Binding)).slot, c.CHAN_AUTO, now);
        }
        return;
    }
    if (!actor.melee.active) actor.melee.begin(0, now);
    actor.mode = .attack;
    const sequence = definition.attacks[0];
    const strikes = [_]?u16{ definition.strikes[0], definition.second_strikes[0] };
    for (strikes, 0..) |frame, i| if (frame) |at| {
        if (actor.melee.event(@as(u2, 1) << @intCast(i), @divTrunc(@as(i64, at) * 1000, sequence.fps), now, false)) {
            try @import("../../../../mechanics/server/actor_lasers.zig").launch(world, slots, projections, entity, target, pose.*, definition.tuning(@import("actor_catalog").lasergat).laser, true, now);
            if (engine.integer("developer") != 0) {
                var message: [96]u8 = undefined;
                engine.print(try std.fmt.bufPrintZ(&message, "dk3 zig lasergat: id={d} fired now={d}\n", .{ try world.persistentId(entity), now }));
            }
        }
    };
    try @import("../../../../mechanics/server/actor_attack_sounds.zig").emit(world, slots, projections, entity, actor, pose.position, definition, now);
    // The cycle restarts when the clip reaches its last frame, on its own clock.
    const cycle = @divTrunc(@as(i64, sequence.last - sequence.first) * 1000, sequence.fps);
    if (now - actor.melee.started_ms >= cycle) actor.melee.begin(0, actor.melee.started_ms + cycle);
}
