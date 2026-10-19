// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: dragon. Dragon: hovering, fire breath and patrols.
//! Reference behaviour: dragon.cpp (docs/class-porting.md).
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
pub const policy = catalog.dragon;
pub const attacks: []const []const u8 = &policy.attacks;
pub const routes: context.Routes = .{ .air = true };
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    try common.airPath(frame, point, speed);
    if (frame.actor.path != 0) try @import("dragons.zig").patrol(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose.*, frame.now);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("dragons.zig").step(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body.*, frame.velocity, frame.definition.*, frame.now, frame.elapsed);
}
fn free(actor: *const data.Actor) bool {
    return actor.mode != .dead and actor.scripted_pose == null and actor.reaction == null;
}
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (!free(actor) or actor.dragon.phase != .hover) return null;
    return .{ .sequence = view.definition.attacks[1], .started = actor.melee.started_ms, .looping = true };
}
/// The breath plume, from 850 ms before it ends, along the breath direction.
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    if (!free(actor)) return;
    if (actor.dragon.breath_until_ms) |until| {
        decoration.state.time2 = policy.breath_tag;
        decoration.state.time = @intCast(until - 850);
        decoration.state.origin2 = actor.dragon.breath_direction;
    }
}
