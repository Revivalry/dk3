// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: seagull. Seagull: authored flight paths; scenery that ignores the player.
//! Reference behaviour: seagull.cpp (docs/class-porting.md).
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
pub const policy = catalog.seagull;
pub const routes: context.Routes = .{ .air = true };
pub fn spawn(spawning: *context.Spawn) !void {
    (try spawning.actor()).ignore_player = true;
}
pub fn pathMove(frame: *Frame, point: ?v.Vec3, _: f32) !void {
    try @import("seagulls.zig").move(frame.actors, frame.world, frame.slots, frame.actor, frame.pose, frame.body, frame.velocity, frame.slot, frame.elapsed, frame.now, 1, point);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("seagulls.zig").move(frame.actors, frame.world, frame.slots, frame.actor, frame.pose, frame.body, frame.velocity, frame.slot, frame.elapsed, frame.now, frame.slow, null);
}
