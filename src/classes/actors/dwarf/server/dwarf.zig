// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: dwarf. Dwarf: axe swings and thrown axes.
//! Reference behaviour: dwarf.cpp (docs/class-porting.md).
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
pub const policy = catalog.dwarf;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{.{ .slot = .death_b, .name = "dieb" }};
pub fn die(frame: *Frame) !void {
    try common.deathCoin(frame, 0.5);
}
pub fn think(frame: *Frame) !void {
    try ground.think(melee, frame);
}
const melee: ground.Spec = .{
    .pain = .{ .generic = .{ .chance = policy.pain_chance, .limit = policy.pain_limit } },
    .reach = reach,
    .admit = admit,
    .select = select,
    .moving = moving,
    .events = .{ .single_strike = true, .launch = throw },
};
fn reach(definition: *const Definition) f32 {
    return definition.tuning(policy).range;
}
fn admit(frame: *Frame, choice: ground.Choice) !context.Admission {
    const random = try frame.world.get(frame.entity, data.Random);
    return if (policy.inRange(choice.distance, frame.definition.range, frame.definition.tuning(policy).range, random.next(), random.next())) .admit else .refuse;
}
fn select(_: *Frame, choice: ground.Choice, random: f32) !u3 {
    return policy.select(choice.distance, random);
}
fn moving(chosen: u3) bool {
    return chosen == 1;
}
/// The third clip throws an axe instead of striking.
fn throw(strike: *const ground.Strike) !bool {
    if (strike.actor.melee.pose != 2) return false;
    _ = try @import("dwarf_axes.zig").launch(strike.world, strike.slots, strike.projections, strike.entity, strike.target, strike.pose, strike.definition.tuning(policy).*, strike.now);
    return true;
}
