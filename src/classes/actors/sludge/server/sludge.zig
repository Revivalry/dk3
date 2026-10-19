// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: sludge. Sludge minion: glob throws and its scooping idle.
//! Reference behaviour: sludgeminion.cpp (docs/class-porting.md).
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
pub const policy = catalog.sludge;
pub const attacks: []const []const u8 = &policy.attacks;
pub const varied_idle = false;
pub fn attackLoad(_: catalog.Kind, index: usize) context.AttackLoad {
    return .{ .events = if (index == 3) .none else .table };
}
pub fn think(frame: *Frame) !void {
    try @import("sludgeminions.zig").think(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
}
/// Idle, it sometimes scoops sludge with its third attack clip.
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (!view.open() or actor.mode != .idle or actor.idle_pose != null or !actor.sludge.idle_scoop) return null;
    return view.moded(view.definition.attacks[2], view.modeStarted());
}
