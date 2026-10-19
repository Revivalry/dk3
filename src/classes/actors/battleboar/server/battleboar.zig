// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: battleboar. Battleboar: gun and rocket volleys, its third pain clip and the muzzle flash.
//! Reference behaviour: battleboar.cpp (docs/class-porting.md).
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
pub const policy = catalog.battleboar;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{ .{ .slot = .death_b, .name = "dieb" }, .{ .slot = .pain_c, .name = "hitc" } };
pub fn die(frame: *Frame) !void {
    try common.deathCoin(frame, 0.5);
}
pub fn think(frame: *Frame) !void {
    try @import("battleboars.zig").think(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
}
/// The gun's muzzle flashes every other 50 ms over frames 92-96 of the first attack clip.
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    const now = decoration.view.now;
    const frame = decoration.playback.frame(now);
    if (actor.mode == .attack and actor.melee.pose == 0 and actor.battleboar.flashed and frame > 91 and frame < 97 and @mod(@divTrunc(now - actor.melee.started_ms, 50), 2) == 0) decoration.state.time2 = policy.flash_tag;
}
