// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: surgeon. Server adapter for the surgeon class: pain, hiding and the cower's
//! reevaluation (docs/class-porting/surgeon.md).
const std = @import("std");
const catalog = @import("actor_catalog");
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const Frame = @import("../../../../mechanics/server/actor_classes/frame.zig").Frame;
const policy = catalog.surgeon;
const Sight = struct { point: v.Vec3 = @splat(0), distance: f32 = std.math.inf(f32), visible: bool = false };
/// Where the surgeon's enemy is and whether it sees it (from its origin, as the reference does).
fn sight(frame: *Frame) !Sight {
    const target = frame.world.find(frame.actor.threat) orelse return .{};
    const point = (try frame.world.get(target, data.Transform)).position;
    const hit = try engine.collisionService().trace(.{ .start = frame.pose.position, .end = point, .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_OPAQUE });
    return .{ .point = point, .distance = v.length(v.subtract(point, frame.pose.position)), .visible = hit.fraction == 1 or hit.entity == (try frame.world.get(target, data.Binding)).slot };
}
pub fn think(frame: *Frame) !void {
    const world = frame.world;
    const actor = frame.actor;
    const now = frame.now;
    const random = try world.get(frame.entity, data.Random);
    const hurt = frame.hurt;
    if (hurt.revision != actor.receipt) {
        actor.receipt = hurt.revision;
        if (world.find(hurt.source)) |source| {
            // A player's hit ends its indifference to him; any attacker becomes its enemy.
            const player = (world.get(source, data.Player) catch null) != null;
            if (player) actor.ignore_player = false;
            if (player or (world.get(source, data.Actor) catch null) != null) {
                actor.threat = hurt.source;
                if (actor.mode == .flee) {
                    actor.mode = .idle;
                    actor.changed_ms = now;
                }
                actor.surgeon.hurt(frame.pose.position, now, random.next(), random.next());
            }
        }
    }
    // A finished hide flight cowers where it stopped.
    if (actor.surgeon.hiding and actor.mode != .flee) actor.surgeon.settle(now, random.next());
    // A calm surgeon that no longer ignores the player runs from the enemy it sees.
    if (!actor.surgeon.active and !actor.surgeon.hiding and !actor.ignore_player and actor.threat != 0 and actor.mode != .dead) {
        const seen = try sight(frame);
        if (seen.visible) {
            actor.route = .{};
            actor.surgeon.hide(frame.pose.position);
            @import("../../../../mechanics/domain/actors.zig").panic(actor, actor.threat, seen.point, policy.hide_ms, now);
        }
    }
    if (actor.surgeon.voice_pending) {
        actor.surgeon.voice_pending = false;
        const chance = random.next();
        if (catalog.hide_voice.choose(policy.thin_voice, chance, random.next())) |name| try @import("../../../../mechanics/server/actor_audio.zig").play(world, frame.slots, frame.projections, frame.entity, frame.definition.*, name, now);
    }
    if (actor.surgeon.active) {
        const seen = try sight(frame);
        const action = actor.surgeon.advance(seen.distance, seen.visible, frame.definition.sight_range, now);
        actor.mode = .idle;
        if (action != .cower) {
            actor.threat = 0;
            actor.changed_ms = now;
        }
    }
    if (actor.surgeon.returning) {
        actor.threat_position = actor.surgeon.home;
        actor.mode = .chase;
        if (@import("../../../../core/domain/navigation.zig").horizontalDistance(frame.pose.position, actor.surgeon.home) < 16) {
            actor.surgeon.returning = false;
            actor.mode = .idle;
        }
    }
}
