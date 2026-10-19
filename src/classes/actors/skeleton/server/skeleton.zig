// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: skeleton. Skeleton: sword melee and three directional deaths.
//! Reference behaviour: SKELETON.CPP (docs/class-porting.md).
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
pub const policy = catalog.skeleton;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{ .{ .slot = .death_b, .name = "dieb" }, .{ .slot = .death_d, .name = "died" } };
/// Killed from the side it plays its second death, from in front the first, from behind the third.
pub fn die(frame: *Frame) !void {
    const facing = try common.attackerFacing(frame) orelse return;
    const definition = frame.definition;
    frame.actor.death_pose = if (@abs(facing) < 0.3) definition.death_b else if (facing > 0) definition.death else definition.death_d;
}
pub fn think(frame: *Frame) !void {
    try ground.think(melee, frame);
}
const melee: ground.Spec = .{ .pain = .{ .generic = .{ .chance = policy.pain_chance, .limit = policy.pain_limit } }, .select = select, .moving = moving };
fn select(frame: *Frame, choice: ground.Choice, random: f32) !u3 {
    return if (choice.distance >= frame.definition.range) policy.chase_pose else policy.select(random);
}
fn moving(chosen: u3) bool {
    return chosen == policy.chase_pose;
}
