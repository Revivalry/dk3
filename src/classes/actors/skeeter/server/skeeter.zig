// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: skeeter. Slaughterskeet: hatching and stinging flight.
//! Reference behaviour: skeeter.cpp (docs/class-porting.md).
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
pub const policy = catalog.skeeter;
pub const attacks = [_][]const u8{policy.attack};
pub const clips = [_]context.Clip{.{ .slot = .hatch, .name = policy.hatch }};
pub const routes: context.Routes = .{ .air = true };
pub fn loadAnimations(load: context.Load) !void {
    load.definition.hatch_sound = (try load.event(policy.hatch)).field("sound1") orelse "";
}
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    try common.airPath(frame, point, speed);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    const mobile = catalog.spawnflags.moves((try frame.world.get(frame.entity, data.MapObject)).flags);
    if (frame.actor.skeeter.phase != .hatching and try common.flinch(frame, policy.pain_chance)) return;
    try @import("skeeters.zig").fly(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body.*, frame.velocity, frame.now, frame.elapsed, mobile, try common.airWander(frame, mobile));
}
/// Hatching plays once; stings run on the skeeter's own clock.
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (!view.open()) return null;
    if (actor.skeeter.phase == .hatching) return .{ .sequence = view.definition.hatch, .started = actor.skeeter.started_ms, .looping = false };
    if (actor.mode == .attack) return .{ .sequence = view.definition.attacks[0], .started = actor.skeeter.started_ms, .looping = false };
    return null;
}
pub fn diagnose(view: context.View, writer: *std.Io.Writer) !void {
    const skeeter = view.actor.skeeter;
    const until = if (skeeter.phase == .attack) skeeter.until_ms else 0;
    try writer.print(" skeeter={s} attack_left={d}", .{ @tagName(skeeter.phase), @max(0, until - view.now) });
}
