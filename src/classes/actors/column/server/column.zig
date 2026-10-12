// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: column. Column: dormant until approached, then crushing melee.
//! Reference behaviour: column.cpp (docs/class-porting.md).
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
pub const policy = catalog.column;
pub const attacks: []const []const u8 = &policy.attacks;
pub const varied_idle = false;
pub const clips = [_]context.Clip{.{ .slot = .awakening, .name = "awaken" }};
pub fn think(frame: *Frame) !void {
    try ground.think(melee, frame);
}
const melee: ground.Spec = .{
    // Its own pain callback plays a hit clip for every admitted hammer hit, the acquiring one too.
    .pain = .{ .roll = .{ .chance = 1, .heavy = 20, .skips_acquiring = false } },
    .gate = awaken,
    .reach = reach,
    .select = select,
    .moving = moving,
    .moving_chases = true,
    .events = .{ .single_strike = true },
};
/// Asleep until a visible enemy comes within the awakening distance; awake once the clip ends.
fn awaken(frame: *Frame, visible: bool) !bool {
    const actor = frame.actor;
    const definition = frame.definition;
    const now = frame.now;
    if (actor.column.phase == .awake) return false;
    actor.mode = .idle;
    if (actor.column.phase == .asleep and visible and @import("../../../../core/domain/navigation.zig").horizontalDistance(frame.pose.position, actor.threat_position) <= policy.awakening_distance) {
        actor.column.phase = .awakening;
        actor.column.started_ms = now;
        actor.reaction = definition.awakening;
        actor.reaction_started_ms = now;
        actor.reaction_until_ms = now + definition.awakening.lastFrameMs();
    }
    if (actor.column.phase == .asleep) return true;
    if (now < actor.column.started_ms + definition.awakening.lastFrameMs()) return true;
    actor.column.phase = .awake;
    actor.reaction = null;
    actor.reaction_until_ms = null;
    return false;
}
fn reach(_: *const Definition) f32 {
    return policy.attack_distance;
}
fn select(frame: *Frame, choice: ground.Choice, _: f32) !u3 {
    return policy.select(choice.distance, frame.definition.range);
}
fn moving(chosen: u3) bool {
    return chosen == 1;
}
pub fn move(frame: *Frame) !void {
    if (frame.actor.column.phase == .asleep) return common.hold(frame);
    try common.move(frame);
}
/// Asleep, it holds the first frame of its awakening.
pub fn playback(view: context.View) !?Playback {
    if (view.actor.column.phase != .asleep) return null;
    const first = view.definition.awakening.first;
    return .{ .sequence = .{ .first = first, .last = first }, .started = view.now };
}
/// Only the hammer harms it.
pub fn admitDamage(_: *const data.Actor, damage: context.Damage) bool {
    return policy.acceptsWeapon(damage.weapon == @import("weapon_catalog").classes.hammer.id);
}
