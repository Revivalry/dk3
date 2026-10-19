// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: cerberus. Cerberus: bites and the pouncing leap.
//! Reference behaviour: cerberus.cpp (docs/class-porting.md).
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
pub const policy = catalog.cerberus;
pub const attacks: []const []const u8 = &policy.attacks;
pub fn think(frame: *Frame) !void {
    try ground.think(melee, frame);
}
const melee: ground.Spec = .{
    .pain = .{ .roll = .{ .chance = 0.1 } },
    .reach = reach,
    .admit = admit,
    .select = select,
    .begun = begun,
    .events = .{ .single_strike = true, .unfaced_pose = 2, .leading = true, .leap = leap },
};
fn reach(definition: *const Definition) f32 {
    return @max(definition.attack_range, definition.jump_distance);
}
fn admit(frame: *Frame, choice: ground.Choice) !context.Admission {
    return if (policy.inRange(choice.distance, frame.definition.range, frame.definition.jump_distance, (try frame.world.get(frame.entity, data.Random)).next())) .admit else .refuse;
}
fn select(frame: *Frame, choice: ground.Choice, random: f32) !u3 {
    return policy.select(choice.distance, frame.definition.attack_range, random);
}
fn begun(frame: *Frame, _: ground.Choice, _: u3) !void {
    frame.actor.cerberus.launched = false;
}
/// The pounce leaves the ground at the clip's sound frame.
fn leap(strike: *const ground.Strike) !void {
    const actor = strike.actor;
    if (actor.melee.pose != 2 or actor.cerberus.launched or strike.now < actor.melee.started_ms + strike.definition.attack_sound_ms[2]) return;
    actor.cerberus.launched = true;
    try ground.leap(strike, strike.definition.speed);
}
/// Of the Episode 2 weapons only the trident harms it.
pub fn admitDamage(_: *const data.Actor, damage: context.Damage) bool {
    const weapons = @import("weapon_catalog").classes;
    return policy.admits(damage.weapon, &.{ weapons.discus.id, weapons.venom.id, weapons.sunflare.id, weapons.hammer.id }, weapons.trident.id);
}
