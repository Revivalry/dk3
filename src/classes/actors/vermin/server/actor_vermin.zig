// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: vermin. Venom vermin: bites, the optional leap and rockets.
//! Reference behaviour: Vermin.cpp (docs/class-porting.md).
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
pub const policy = catalog.vermin;
pub const attacks: []const []const u8 = &policy.attacks;
pub const routes: context.Routes = .{ .ground = true };
/// The fourth clip (the leap) is optional.
pub fn attackLoad(_: catalog.Kind, index: usize) context.AttackLoad {
    return .{ .optional = index == 3 };
}
pub fn think(frame: *Frame) !void {
    try @import("vermin.zig").think(&frame.actors.ground_routes, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
}
