// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: protopod. Protopod: opens and hatches a Slaughterskeet.
//! Reference behaviour: protopod.cpp (docs/class-porting.md).
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
pub const policy = catalog.protopod;
pub const varied_idle = false;
pub const clips = [_]context.Clip{.{ .slot = .hatch, .name = "hatcha" }};
pub const routes: context.Routes = .{ .air = true };
pub const requires = [_][]const u8{"monster_slaughterskeet"};
pub fn loadAnimations(load: context.Load) !void {
    load.definition.hatch_sound = (try load.event("hatcha")).field("sound1") orelse "";
}
pub const perceive = common.perceiveNothing;
pub fn think(frame: *Frame) !void {
    try @import("protopods.zig").pod(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose.*, frame.body, frame.now);
}
/// Opening, the pod plays its hatch clip once.
pub fn playback(view: context.View) !?Playback {
    const phase = view.actor.pod.phase;
    if (!view.open() or (phase != .opening and phase != .shell)) return null;
    return .{ .sequence = view.definition.hatch, .started = view.modeStarted(), .looping = false };
}
/// A pod's own use comes after authored scripts have had theirs.
pub const use_after_scripts = true;
/// Triggered, the pod opens.
pub fn use(using: *context.Use) !bool {
    using.actor.pod.use(using.now);
    return true;
}
