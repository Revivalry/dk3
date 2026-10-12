// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: ghost. Ghost: dormant until woken, fading in and out, and its own death.
//! Reference behaviour: ghost.cpp (docs/class-porting.md).
const std = @import("std");
const catalog = @import("actor_catalog");
const data = @import("../../../../game/domain/components.zig");
const abi = @import("../../../../engine/abi.zig");
const v = @import("../../../../core/domain/vector.zig");
const Definition = @import("../../../../mechanics/domain/actors.zig").Definition;
const Playback = @import("../../../../core/domain/animation.zig").Playback;
const context = @import("../../../../mechanics/server/actor_classes/frame.zig");
const common = @import("../../../../mechanics/server/actor_classes/common.zig");
const registry = @import("../../../../mechanics/server/actor_classes/registry.zig");
const ground = @import("../../../../mechanics/server/ground_combat.zig");
const Frame = context.Frame;
const Actors = context.Actors;
pub const policy = catalog.ghost;
pub const attacks: []const []const u8 = &policy.attacks;
pub const routes: context.Routes = .{ .air = true };
/// The ghost fades out instead of taking the shared death (unless petrified).
pub const own_death = true;
/// Its attack clip has no supplied event row; it strikes on its second frame.
pub fn attackLoad(_: catalog.Kind, _: usize) context.AttackLoad {
    return .{ .events = .first_frame };
}
pub fn spawn(spawning: *context.Spawn) !void {
    (try spawning.world.get(spawning.entity, data.Body)).contents = abi.c.CONTENTS_CORPSE;
}
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    try common.airPath(frame, point, speed);
}
pub fn takeover(frame: *Frame) !context.Takeover {
    if (frame.dead and !frame.actor.death_dispatched) try frame.actors.dispatchDeath(frame);
    if (try @import("ghosts.zig").step(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body.*, frame.velocity, frame.now, frame.elapsed)) return .done;
    return .stepped;
}
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (actor.scripted_pose != null) return null;
    return switch (actor.ghost.phase) {
        .dormant, .waking => .{ .sequence = view.definition.idle, .started = actor.ghost.started_ms, .looping = false },
        .chase, .fading => .{ .sequence = view.definition.run, .started = actor.ghost.started_ms },
        .attack => .{ .sequence = view.definition.attacks[0], .started = actor.melee.started_ms },
    };
}
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    decoration.state.time2 = catalog.fade.fade_tag;
    decoration.state.origin2[0] = actor.ghost.alpha;
    if (actor.ghost.phase == .dormant) decoration.state.modelindex = 0;
}
/// Its pain callback deducts a surviving player hit a second time.
pub fn afterDamage(hit: *context.Hit) !void {
    if (hit.result.blood <= 0 or hit.result.killed) return;
    const source = @import("../../../../mechanics/server/region_access.zig").find(hit.world, hit.options.source) orelse return;
    if ((source.get(data.Player) catch null) == null) return;
    hit.health.current -= hit.amount;
    hit.result.blood += hit.amount;
    hit.result.killed = hit.health.current <= 0;
}
