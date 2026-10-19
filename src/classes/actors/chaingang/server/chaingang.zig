// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: chaingang. Chaingang: jet flight, landing and strafing gunfire.
//! Reference behaviour: chaingang.cpp (docs/class-porting.md).
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
pub const policy = catalog.chaingang;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{ .{ .slot = .death_d, .name = "diec" }, .{ .slot = .ground_run, .name = "runa" } };
pub const routes: context.Routes = .{ .air = true, .ground = true };
pub fn attackLoad(_: catalog.Kind, index: usize) context.AttackLoad {
    return .{ .events = if (index == 2 or index == 3) .none else .table };
}
pub fn spawn(spawning: *context.Spawn) !void {
    try @import("chaingangs.zig").initialize(spawning.world, spawning.entity, spawning.now);
}
pub fn die(frame: *Frame) !void {
    frame.actor.death_pose = if ((try frame.world.get(frame.entity, data.Random)).next() > 0.33) frame.definition.death else frame.definition.death_d;
}
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    if (frame.actor.chaingang.flying) return common.airPath(frame, point, speed);
    try common.groundPath(frame, point, speed);
}
/// A body killed in flight falls and bounces.
pub fn move(frame: *Frame) !void {
    if (!frame.dead) return @import("chaingangs.zig").step(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.now, frame.elapsed, frame.slow);
    if (frame.actor.chaingang.flying) return @import("../../../../mechanics/server/actor_flight.zig").bounce(frame.pose, frame.body.*, frame.velocity, frame.slot, frame.elapsed, policy.corpse_gravity, 0.5, true);
    try common.move(frame);
}
/// On foot or dodging, it runs; coming in to land, it holds its flight clip's last frame.
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (actor.mode != .chase or actor.reaction != null or actor.scripted_pose != null or actor.melee.active) return null;
    if (actor.chaingang.flying and actor.chaingang.phase == .approach_land) return .{ .sequence = view.definition.run, .started = actor.changed_ms, .looping = false };
    if (actor.chaingang.flying and actor.chaingang.phase != .dodge) return null;
    return .{ .sequence = view.definition.ground_run, .started = actor.changed_ms, .looping = true };
}
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    if (actor.mode != .dead and actor.chaingang.flying) decoration.state.time2 = policy.jet_tag;
}
