// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: femgang. Female gang member: kicks, evasion and her two idles.
//! Reference behaviour: femgang.cpp (docs/class-porting.md).
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
pub const policy = catalog.femgang;
pub const attacks: []const []const u8 = &policy.attacks;
pub const varied_idle = false;
pub const clips = [_]context.Clip{ .{ .slot = .death_b, .name = "dieb" }, .{ .slot = .alternate_idle, .name = "ambb" } };
pub const routes: context.Routes = .{ .ground = true };
pub fn die(frame: *Frame) !void {
    try common.deathCoin(frame, 0.5);
}
pub fn think(frame: *Frame) !void {
    try ground.think(melee, frame);
}
const melee: ground.Spec = .{
    .pain = .{ .generic = .{ .chance = 20, .limit = 35 } },
    .calm = calm,
    .alert = alert,
    .facing_degrees = 5,
    .reach = reach,
    .admit = admit,
    .select = select,
    .moving = moving,
    .moving_chases = true,
    .events = .{ .single_strike = true, .leading = true },
};
/// Without an enemy she settles on one of her idles (the second 15% of the time).
fn calm(frame: *Frame) !void {
    const actor = frame.actor;
    if (actor.femgang.idle_chosen) return;
    actor.femgang.idle_chosen = true;
    actor.femgang.idle_b = (try frame.world.get(frame.entity, data.Random)).next() >= 0.85;
    actor.changed_ms = frame.now;
}
fn alert(frame: *Frame) void {
    frame.actor.femgang.idle_chosen = false;
}
fn reach(_: *const Definition) f32 {
    return policy.attack_distance;
}
/// Targeted, she evades half the time instead of attacking.
fn admit(frame: *Frame, choice: ground.Choice) !context.Admission {
    const evasion = @import("../../../../mechanics/server/actor_evasion.zig");
    if (!choice.completed and try evasion.targeted(frame.world, frame.entity, choice.target, frame.pose.*) and (try frame.world.get(frame.entity, data.Random)).next() > 0.5 and try evasion.startBrief(&frame.actors.ground_routes, frame.world, frame.entity, choice.target, frame.actor, frame.pose.*, false, policy.evasion_ms, frame.now)) return .stop;
    return .admit;
}
fn select(frame: *Frame, choice: ground.Choice, _: f32) !u3 {
    return policy.select(choice.distance, frame.definition.range);
}
fn moving(chosen: u3) bool {
    return chosen == 1;
}
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (!view.open() or actor.mode != .idle or actor.idle_pose != null or !actor.femgang.idle_b) return null;
    return view.moded(view.definition.alternate_idle, view.modeStarted());
}
