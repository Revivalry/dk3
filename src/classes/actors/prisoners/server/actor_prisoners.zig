// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: prisoners. Black and white prisoners: punches and thrown rocks.
//! Reference behaviour: blackpris.cpp, whitepris.cpp, PRISONER.CPP (docs/class-porting.md).
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
pub const policy = catalog.prisoners;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{.{ .slot = .death_b, .name = "dieb" }};
pub const routes: context.Routes = .{ .ground = true };
/// A light final blow (or 30% of the time) plays the first death.
pub fn die(frame: *Frame) !void {
    frame.actor.death_pose = if (frame.hurt.amount < 20 or (try frame.world.get(frame.entity, data.Random)).next() < 0.3) frame.definition.death else frame.definition.death_b;
}
pub fn think(frame: *Frame) !void {
    try @import("prisoners.zig").think(&frame.actors.ground_routes, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
}
