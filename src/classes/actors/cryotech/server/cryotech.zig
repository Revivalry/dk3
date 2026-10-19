// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: cryotech. Cryotech: freezing spray and its ambient work.
//! Reference behaviour: cryotech.cpp (docs/class-porting.md).
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
pub const policy = catalog.cryotech;
pub const attacks: []const []const u8 = &policy.attacks;
pub fn think(frame: *Frame) !void {
    try @import("cryotechs.zig").think(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
}
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    try common.groundPath(frame, point, speed);
    try @import("cryotechs.zig").ambient(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose.*, frame.definition.*, frame.now);
}
