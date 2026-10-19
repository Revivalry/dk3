// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: gunners. SEAL captain, commando, SEAL girl and Uzi gang: bursts and shotguns, and their deaths.
//! Reference behaviour: sealcap.cpp, scomndo.cpp, sgirl.cpp, uzigang.cpp (docs/class-porting.md).
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
pub const policy = catalog.gunners;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{.{ .slot = .death_b, .name = "dieb" }};
/// The Uzi gang member falls backward unless a heavy hit came from in front.
pub fn die(frame: *Frame) !void {
    if (frame.kind != .uzigang) return common.deathCoin(frame, 0.5);
    frame.actor.death_pose = frame.definition.death_b;
    if (frame.hurt.amount > 10) if (try common.attackerFacing(frame)) |facing| {
        if (facing > 0.707) frame.actor.death_pose = frame.definition.death;
    };
}
pub fn think(frame: *Frame) !void {
    try @import("gunners.zig").think(frame);
}
/// Running to or out of cover it heads for its hide node or its enemy.
pub fn move(frame: *Frame) !void {
    const actor = frame.actor;
    if (actor.mode == .chase and actor.evasion.until_ms == null) if (@import("../../../../mechanics/server/actor_cover.zig").destination(frame)) |point| return common.moveTo(frame, point, frame.definition.speed);
    try common.move(frame);
}
