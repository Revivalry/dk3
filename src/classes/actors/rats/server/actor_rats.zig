// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: rats. Pipe and plague rats: bites, pounces, swimming and strafing.
//! Reference behaviour: piperat.cpp, prat.cpp (docs/class-porting.md).
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
pub const policy = catalog.rats;
pub const routes: context.Routes = .{ .ground = true };
pub fn attacks(kind: catalog.Kind) []const []const u8 {
    return if (kind == .piperat) &policy.pipe_attacks else &policy.plague_attacks;
}
pub fn clips(kind: catalog.Kind) []const context.Clip {
    return if (kind == .plague_rat) &.{.{ .slot = .death_b, .name = "dieb" }} else &.{};
}
pub fn attackLoad(_: catalog.Kind, index: usize) context.AttackLoad {
    return .{ .jump_strike = index == 1 };
}
pub fn die(frame: *Frame) !void {
    if (frame.kind == .plague_rat) try common.deathCoin(frame, 0.5);
}
/// How deep the rat is, and whether it swims.
pub fn sense(frame: *Frame) !void {
    const rat = &frame.actor.rat;
    rat.water = try @import("../../../../mechanics/server/actor_water.zig").level(frame.pose.position, frame.body.*, frame.slot);
    rat.swimming = rat.water == 3 or (rat.water > 1 and !frame.body.grounded);
}
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    if (!frame.actor.rat.swimming) return common.groundPath(frame, point, speed);
    if (point) |destination| frame.actor.threat_position = destination;
    frame.actor.rat.water = try @import("../../../../mechanics/server/actor_water.zig").move(&frame.actors.ground_routes, frame.actor, frame.pose, frame.body, frame.velocity, speed, frame.slot, frame.elapsed);
}
pub fn think(frame: *Frame) !void {
    try @import("rats.zig").think(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    if (!frame.actor.rat.swimming) {
        // Rats nest in pipes and under props, off the player's navigation areas: the node graph
        // takes them out (the reference moves rats by its nodes).
        const motion = @import("../../../../mechanics/server/actor_motion.zig");
        var fallback: motion.NodeFallback = .{ .primary = frame.navigation, .routes = &frame.actors.ground_routes, .body = frame.body.* };
        return motion.step(frame.actor, frame.pose, frame.body, frame.velocity, fallback.service(), frame.threat, frame.definition.speed * frame.slow, frame.slot, frame.now, frame.elapsed);
    }
    frame.actor.rat.water = try @import("../../../../mechanics/server/actor_water.zig").move(&frame.actors.ground_routes, frame.actor, frame.pose, frame.body, frame.velocity, frame.definition.speed * frame.slow, frame.slot, frame.elapsed);
}
/// Strafing, the rat keeps facing its strafe yaw.
pub fn settle(frame: *Frame) void {
    const rat = frame.actor.rat;
    if (rat.strafe and rat.evasion_until != null) frame.pose.angles[1] = rat.strafe_yaw;
}
