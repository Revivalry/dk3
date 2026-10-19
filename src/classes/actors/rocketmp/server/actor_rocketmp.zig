// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: rocketmp. Rocket MP: running rockets, knife, chase-evade.
//! Reference behaviour: rocketmp.cpp (docs/class-porting.md).
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
pub const policy = catalog.rocketmp;
pub const attacks: []const []const u8 = &policy.attacks;
pub fn think(frame: *Frame) !void {
    try @import("rocketmp.zig").think(frame);
}
/// Running to or out of cover it heads for its hide node or its enemy.
pub fn move(frame: *Frame) !void {
    const actor = frame.actor;
    if (actor.mode == .chase and actor.evasion.until_ms == null and actor.rocketmp.evade_until == null) if (@import("../../../../mechanics/server/actor_cover.zig").destination(frame)) |point| return common.moveTo(frame, point, frame.definition.speed);
    try common.move(frame);
}
