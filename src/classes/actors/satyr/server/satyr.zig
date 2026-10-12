// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: satyr. Satyr: side-changing melee with optional transition clips.
//! Reference behaviour: SATYR.CPP (docs/class-porting.md).
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
pub const policy = catalog.satyr;
pub const attacks: []const []const u8 = &policy.attacks;
/// Clips from the fourth on are the side-change transitions: optional, and without events.
pub fn attackLoad(_: catalog.Kind, index: usize) context.AttackLoad {
    return if (index >= 3) .{ .optional = true, .events = .none } else .{};
}
/// The supplied satyr model has no transition poses; the side change then happens without one.
pub fn loadAnimations(load: context.Load) !void {
    const present = &load.definition.attack_present;
    if (present[3] and present[4]) return;
    present[3] = false;
    present[4] = false;
}
pub fn think(frame: *Frame) !void {
    try ground.think(melee, frame);
}
const melee: ground.Spec = .{
    .pain = .{ .generic = .{ .chance = policy.pain_chance, .limit = policy.pain_limit } },
    .select = select,
    .transition = transition,
    .moving = moving,
    .events = .{ .silent_from = 3 },
};
fn select(frame: *Frame, choice: ground.Choice, random: f32) !u3 {
    return if (choice.distance >= frame.definition.range) policy.chase_pose else policy.select(random);
}
fn transition(definition: *const Definition, from: u3, to: u3) ?u3 {
    return if (definition.attack_present[3]) policy.transition(from, to) else null;
}
fn moving(chosen: u3) bool {
    return chosen == policy.chase_pose;
}
