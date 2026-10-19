// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: thunderskeet. Thunderskeet: heavy flight and the lightning spray.
//! Reference behaviour: thunderskeet.cpp (docs/class-porting.md).
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
pub const policy = catalog.thunderskeet;
pub const attacks = [_][]const u8{policy.attack};
pub const routes: context.Routes = .{ .air = true };
/// The burst clip must cover the authored spray frames.
pub fn loadAnimations(load: context.Load) !void {
    const burst = load.definition.attacks[0];
    if (burst.first > 27 or burst.last < 32) return error.InvalidThunderBurstAnimation;
}
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    try common.airPath(frame, point, speed);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    const mobile = catalog.spawnflags.moves((try frame.world.get(frame.entity, data.MapObject)).flags);
    if (try common.flinch(frame, policy.pain_chance)) return;
    try @import("thunderskeets.zig").fly(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body.*, frame.velocity, frame.now, frame.elapsed, mobile, try common.airWander(frame, mobile));
}
pub fn playback(view: context.View) !?Playback {
    if (!view.open() or view.actor.mode != .attack) return null;
    return .{ .sequence = view.definition.attacks[0], .started = view.actor.thunder.started_ms, .looping = false };
}
pub fn diagnose(view: context.View, writer: *std.Io.Writer) !void {
    const thunder = view.actor.thunder;
    const until = if (thunder.phase == .attack) thunder.started_ms + view.definition.attacks[0].lastFrameMs() else 0;
    try writer.print(" attack_left={d}", .{@max(0, until - view.now)});
}
