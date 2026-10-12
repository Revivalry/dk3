// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: lycanthir. Lycanthir: claws, the pouncing leap and resurrection.
//! Reference behaviour: lycanthir.cpp (docs/class-porting.md).
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
pub const policy = catalog.lycanthir;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{.{ .slot = .death_b, .name = "dieb" }};
pub fn attackLoad(_: catalog.Kind, index: usize) context.AttackLoad {
    return .{ .jump_strike = index == 4 };
}
/// The real death howls (its collapse does not reach here).
pub fn die(frame: *Frame) !void {
    frame.actor.death_pose = frame.definition.death_b;
    try @import("../../../../mechanics/server/events.zig").soundAt(frame.world, frame.slots, frame.projections, frame.entity, policy.death_howl, frame.now);
}
/// Rising again, it neither runs scripts nor follows paths.
pub fn scriptable(actor: *const data.Actor) bool {
    return actor.lycanthir.phase == .living;
}
pub fn follows(actor: *const data.Actor) bool {
    return actor.lycanthir.phase == .living;
}
pub fn think(frame: *Frame) !void {
    if (try @import("lycanthirs.zig").revive(frame.world, frame.entity, frame.actor, frame.pose.*, frame.body, frame.definition.*, frame.now)) return;
    try ground.think(melee, frame);
}
const melee: ground.Spec = .{
    .pain = .{ .generic = .{ .chance = policy.pain_chance, .limit = policy.pain_limit } },
    .reach = reach,
    .admit = admit,
    .select = select,
    .moving = moving,
    .begun = begun,
    .close_distance = 60,
    .events = .{ .jump_pose = 4, .leap = leap },
};
/// It closes in until its aidata jump-attack distance, then claws, chases or leaps.
fn reach(definition: *const Definition) f32 {
    return definition.jump_distance;
}
/// When a claw or chase attack ends, it sometimes takes evasive action for a moment instead.
fn admit(frame: *Frame, choice: ground.Choice) !context.Admission {
    if (!choice.completed or frame.actor.melee.pose > 3) return .admit;
    const chance = if (frame.actor.melee.pose == 3) policy.chase_evasion else policy.claw_evasion;
    if ((try frame.world.get(frame.entity, data.Random)).next() >= chance) return .admit;
    return if (try @import("../../../../mechanics/server/actor_evasion.zig").startBrief(&frame.actors.ground_routes, frame.world, frame.entity, choice.target, frame.actor, frame.pose.*, false, policy.evasion_ms, frame.now)) .stop else .admit;
}
fn select(frame: *Frame, choice: ground.Choice, random: f32) !u3 {
    const velocity = (try choice.target.get(data.Velocity)).linear;
    return policy.select(choice.distance, frame.definition.attack_range, policy.jumpRange(frame.definition.speed, frame.definition.upward_speed), v.dot(v.basis(frame.pose.angles).forward, velocity), velocity[0] * velocity[0] + velocity[1] * velocity[1], random, (try frame.world.get(frame.entity, data.Random)).next());
}
fn moving(chosen: u3) bool {
    return chosen == 3;
}
fn begun(frame: *Frame, _: ground.Choice, _: u3) !void {
    frame.actor.lycanthir.launched = false;
}
/// The pounce leaves the ground at the clip's sound frame.
fn leap(strike: *const ground.Strike) !void {
    const actor = strike.actor;
    if (actor.melee.pose != 4 or actor.lycanthir.launched or strike.now < actor.melee.started_ms + strike.definition.attack_sound_ms[4]) return;
    actor.lycanthir.launched = true;
    try ground.leap(strike, strike.definition.speed * 1.5);
}
pub fn playback(view: context.View) !?Playback {
    return @import("lycanthirs.zig").playback(view.actor.*, view.definition.*);
}
/// Collapsed, only the Silverclaw harms it.
pub fn admitDamage(actor: *const data.Actor, damage: context.Damage) bool {
    return actor.lycanthir.phase == .living or damage.weapon == silverclaw;
}
/// A killing blow from anything but the Silverclaw collapses it to rise again.
pub fn afterDamage(hit: *context.Hit) !void {
    if (!hit.result.killed or hit.options.weapon == silverclaw) return;
    hit.actor.lycanthir.collapse(hit.now, @import("../../../../engine/server.zig").integer("g_spSkill"));
    hit.health.current = 1;
    hit.result.killed = false;
}
const silverclaw = @import("weapon_catalog").classes.silverclaw.id;
