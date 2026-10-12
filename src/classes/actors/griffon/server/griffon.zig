// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: griffon. Griffon: air pursuit, landing and the ground leap.
//! Reference behaviour: griffon.cpp (docs/class-porting.md).
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
pub const policy = catalog.griffon;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{.{ .slot = .ground_run, .name = "runa" }};
pub const routes: context.Routes = .{ .air = true, .ground = true };
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    if (frame.actor.griffon.flying) return common.airPath(frame, point, speed);
    try common.groundPath(frame, point, speed);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("griffons.zig").step(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.now, frame.elapsed, frame.slow);
}
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (actor.mode == .dead or actor.reaction != null or actor.scripted_pose != null) return null;
    if (actor.griffon.phase == .leap) return .{ .sequence = view.definition.attacks[4], .started = actor.melee.started_ms, .looping = true };
    if (!actor.griffon.flying and actor.mode == .chase) return .{ .sequence = view.definition.ground_run, .started = actor.changed_ms, .looping = true };
    return null;
}
