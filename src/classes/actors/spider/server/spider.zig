// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: spider. Spiders: fast bites and pounces.
//! Reference behaviour: spider.cpp, smallspider.cpp (docs/class-porting.md).
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
pub const policy = catalog.spider;
pub const attacks: []const []const u8 = &policy.attacks;
/// The bite advances two frames per step (the reference's frame increment of 2): twice the clip
/// rate. The second clip's leap is timed by its second sound frame.
pub fn attackLoad(_: catalog.Kind, index: usize) context.AttackLoad {
    return .{ .fps_scale = if (index == 0) 2 else 1, .jump_strike = index == 1 };
}
pub fn think(frame: *Frame) !void {
    try @import("spiders.zig").think(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
}
/// Triggered, a small spider stops ignoring the player (the e2m4b swarm that a trigger sets on him).
pub fn use(using: *context.Use) !bool {
    if (catalog.entries[using.actor.definition].kind != .smallspider) return false;
    using.actor.ignore_player = false;
    return true;
}
