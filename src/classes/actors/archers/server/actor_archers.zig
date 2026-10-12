// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: archers. Centurion and Fletcher: authored shots and melee, with the Fletcher's two deaths.
//! Reference behaviour: centurion.cpp, fletcher.cpp (docs/class-porting.md).
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
pub const policy = catalog.archers;
pub const attacks: []const []const u8 = &policy.attacks;
pub const routes: context.Routes = .{ .ground = true };
pub fn clips(kind: catalog.Kind) []const context.Clip {
    return if (kind == .fletcher) &.{.{ .slot = .death_b, .name = "dieb" }} else &.{};
}
pub fn die(frame: *Frame) !void {
    // The fletcher falls by its killer's side: from in front its first death, else its second.
    if (frame.kind == .fletcher) {
        const facing = try common.attackerFacing(frame) orelse return;
        frame.actor.death_pose = if (facing > 0) frame.definition.death else frame.definition.death_b;
    }
}
pub fn think(frame: *Frame) !void {
    try @import("archers.zig").think(&frame.actors.ground_routes, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
}
