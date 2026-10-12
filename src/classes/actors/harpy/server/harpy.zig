// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: harpy. Harpy: terrain transitions, magic arrows and the dropping attack.
//! Reference behaviour: harpy.cpp (docs/class-porting.md).
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
pub const policy = catalog.harpy;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{.{ .slot = .ground_run, .name = "runa" }};
pub const routes: context.Routes = .{ .air = true, .ground = true };
/// The drop attack's clip must cover the authored drop frames.
pub fn loadAnimations(load: context.Load) !void {
    const drop = load.definition.attacks[2];
    if (drop.first > 191 or drop.last < 209) return error.InvalidHarpyDrop;
}
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    if (frame.actor.harpy.flying) return common.airPath(frame, point, speed);
    try common.groundPath(frame, point, speed);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("harpies.zig").step(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.now, frame.elapsed, frame.slow);
}
/// Takeoff plays the drop clip backward; on foot she runs; warming up a shot she holds her flight pose.
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    const definition = view.definition;
    if (actor.mode == .dead or actor.reaction != null or actor.scripted_pose != null) return null;
    return switch (actor.harpy.phase) {
        .takeoff, .rising => .{ .sequence = definition.attacks[2], .started = actor.melee.started_ms, .looping = false, .reverse = true },
        .dodge, .approach_land => .{ .sequence = definition.ground_run, .started = actor.changed_ms, .looping = true },
        .chase => if (!actor.harpy.flying and actor.mode == .chase) .{ .sequence = definition.ground_run, .started = actor.changed_ms, .looping = true } else null,
        .attack => if (!actor.melee.active) .{ .sequence = if (actor.harpy.flying) definition.run else definition.ground_run, .started = actor.harpy.warmup_started_ms } else null,
        else => null,
    };
}
