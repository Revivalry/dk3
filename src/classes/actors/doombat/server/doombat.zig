// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: doombat. Doombat: swooping flight and fireballs.
//! Reference behaviour: doombat.cpp (docs/class-porting.md).
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
pub const policy = catalog.doombat;
pub const attacks: []const []const u8 = &policy.attacks;
pub const routes: context.Routes = .{ .air = true };
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    try common.airPath(frame, point, speed);
}
/// A dead doombat drops.
pub fn move(frame: *Frame) !void {
    if (frame.dead) return @import("doombats.zig").motion(frame.pose, frame.body.*, frame.velocity, frame.slot, frame.elapsed, frame.definition.speed, true);
    try @import("doombats.zig").fly(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body.*, frame.velocity, frame.now, frame.elapsed);
}
