// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: kage. Kage: ghost summoning, recharging, fading and the sword aura.
//! Reference behaviour: kage.cpp (docs/class-porting.md).
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
pub const policy = catalog.kage;
pub const attacks: []const []const u8 = &policy.attacks;
pub const requires = [_][]const u8{"monster_ghost"};
pub const routes: context.Routes = .{ .ground = true };
pub fn attackLoad(_: catalog.Kind, index: usize) context.AttackLoad {
    return .{ .events = if (index == 3) .first_frame else .table };
}
pub fn spawn(spawning: *context.Spawn) !void {
    (try spawning.actor()).kage = policy.initialize(spawning.definition.health, @import("../../../../engine/server.zig").integer("g_spSkill"));
}
pub fn die(frame: *Frame) !void {
    try @import("kages.zig").death(frame.world, frame.slots);
}
/// Outside combat the boss runs its own phases, not paths.
pub fn follows(actor: *const data.Actor) bool {
    return actor.kage.phase == .combat;
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("kages.zig").step(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.now, frame.elapsed, frame.slow);
}
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (actor.mode == .dead or !actor.kage.recharging()) return null;
    return .{ .sequence = view.definition.attacks[3], .started = actor.melee.started_ms, .looping = true };
}
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    const state = decoration.state;
    const sound = @import("../../../../mechanics/server/resources.zig").sound;
    state.loopSound = if (actor.mode == .dead) 0 else if (actor.kage.phase == .charging) try sound("e4/m_kage_ghost_am.wav") else if (actor.kage.humming) try sound("global/we_dk_03a.wav") else 0;
    if (actor.mode == .dead) return;
    state.time2 = policy.fade_tag;
    state.origin2[0] = actor.kage.alpha;
    state.torsoAnim = @intFromFloat(actor.kage.alpha * 1000);
    if (actor.kage.aura) {
        state.time2 = catalog.sword_aura_tag;
        state.time = @intCast(actor.kage.aura_started_ms);
        state.origin2 = @splat(-1);
        state.legsAnim = 1;
    }
}
/// Hidden in smoke it cannot be hurt; for 15 / 7.5 / 4.5 s after each recharge its shield
/// turns damage away (the reference reuses the megashield timer).
pub fn admitDamage(actor: *const data.Actor, damage: context.Damage) bool {
    return !actor.kage.invulnerable() and !actor.kage.shielded(damage.now);
}
pub fn immovable(actor: *const data.Actor) bool {
    return actor.kage.invulnerable();
}
/// Recharging, damage is refunded and cannot kill.
pub fn afterDamage(hit: *context.Hit) !void {
    if (hit.result.blood <= 0 or !hit.actor.kage.recharging()) return;
    hit.actor.kage.refund(&hit.health.current, hit.amount);
    hit.result.killed = false;
}
