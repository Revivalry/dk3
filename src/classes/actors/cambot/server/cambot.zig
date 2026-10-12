// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: cambot. Cambot: patrol flight, camera acquisition and alarm.
//! Reference behaviour: cambot.cpp (docs/class-porting.md).
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
pub const policy = catalog.cambot;
pub const routes: context.Routes = .{ .air = true };
pub const path_gait: @import("../../../../mechanics/server/actor_classes/registry.zig").Gait = .walk;
/// The camera senses on its own think cadence, not through path perception.
pub fn perceive(frame: *Frame) !void {
    if (frame.now >= frame.actor.think_ms) try @import("cambots.zig").sense(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose.*, frame.body.*, frame.definition.*, frame.now);
}
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    if (frame.now >= frame.actor.think_ms) frame.actor.think_ms = frame.now + 100;
    try common.airPath(frame, point, speed);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("cambots.zig").fly(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body.*, frame.velocity, frame.now, frame.elapsed);
}
/// The lens shows alert while the camera has a threat, and looks toward it.
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    if (actor.mode != .dead) decoration.state.time2 = if (actor.threat != 0) policy.alert_tag else policy.idle_tag;
    decoration.state.origin2 = actor.threat_position;
}
pub fn diagnose(view: context.View, writer: *std.Io.Writer) !void {
    try writer.print(" camera_seen={d} camera_alarm={d}", .{ @intFromBool(view.actor.cambot.seen), view.actor.cambot.alarmed });
}
