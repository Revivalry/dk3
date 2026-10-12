// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: shark. Shark: patrols its water and bites.
//! Reference behaviour: shark.cpp (docs/class-porting.md).
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
pub const policy = catalog.shark;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{.{ .slot = .swim, .name = "swima" }};
pub const routes: context.Routes = .{ .ground = true };
pub fn spawn(spawning: *context.Spawn) !void {
    (try spawning.actor()).shark.start = try spawning.position();
}
pub fn pathMove(frame: *Frame, point: ?v.Vec3, _: f32) !void {
    if (point) |destination| frame.actor.threat_position = destination;
    try @import("sharks.zig").swim(frame.actors, frame.actor, frame.pose, frame.body, frame.velocity, frame.slot, frame.elapsed, 1);
}
pub fn think(frame: *Frame) !void {
    try @import("sharks.zig").think(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.now);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("sharks.zig").swim(frame.actors, frame.actor, frame.pose, frame.body, frame.velocity, frame.slot, frame.elapsed, frame.slow);
}
