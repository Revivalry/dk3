// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: labmonkey. Lab monkey: bites and hops.
//! Reference behaviour: labmonkey.cpp (docs/class-porting.md).
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
pub const policy = catalog.labmonkey;
pub const attacks: []const []const u8 = &policy.attacks;
pub fn think(frame: *Frame) !void {
    try ground.think(melee, frame);
}
const melee: ground.Spec = .{
    .pain = .{ .generic = .{ .chance = 20, .limit = 35 } },
    .reach = reach,
    .admit = admit,
    .select = select,
    .begun = hop,
    .sure_reach = sureReach,
    // Its punch is led at the enemy and lands without facing.
    .events = .{ .unfaced = true, .leading = true },
};
fn reach(definition: *const Definition) f32 {
    return @max(definition.range, definition.jump_distance);
}
/// Within its punch's reach it always attacks; out to its leap it attacks on a re-rolled half.
fn sureReach(definition: *const Definition) f32 {
    return definition.range;
}
fn admit(frame: *Frame, choice: ground.Choice) !context.Admission {
    return if (policy.inRange(choice.distance, frame.definition.range, frame.definition.jump_distance, (try frame.world.get(frame.entity, data.Random)).next())) .admit else .refuse;
}
fn select(_: *Frame, choice: ground.Choice, random: f32) !u3 {
    return policy.select(choice.distance, random);
}
/// After a finished attack it may hop sideways; its leaping bites jump at its enemy.
fn hop(frame: *Frame, choice: ground.Choice, chosen: u3) !void {
    const random = try frame.world.get(frame.entity, data.Random);
    const sideways = if (choice.completed) policy.hop(choice.distance, random.next()) else null;
    if (sideways == null and chosen != 2 and chosen != 3) return;
    var angles = frame.pose.angles;
    if (sideways) |yaw| {
        angles[1] += if (random.next() < 0.5) yaw else -yaw;
        frame.actor.melee.begin(2, frame.now);
    }
    const velocity = try frame.world.get(frame.entity, data.Velocity);
    velocity.linear = v.scale(v.basis(angles).forward, if (sideways != null) 150 else frame.definition.speed * 1.5);
    velocity.linear[2] = frame.definition.upward_speed;
    frame.actor.ground_entity = abi.c.ENTITYNUM_NONE;
}
/// Triggered, a living monkey turns on the nearest enemy.
pub fn use(using: *context.Use) !bool {
    if ((try using.world.get(using.entity, data.Health)).current > 0) {
        const actor = using.actor;
        actor.ignore_player = false;
        const actors = using.actors orelse return error.MissingActorDefinitions;
        try @import("../../../../mechanics/server/actor_perception.zig").acquire(using.world, using.slots, using.entity, actor, (try using.world.get(using.entity, data.Transform)).*, actors.table.definitions[actor.definition], using.now);
    }
    return true;
}
