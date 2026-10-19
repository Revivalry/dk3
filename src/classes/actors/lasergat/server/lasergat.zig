// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: lasergat. Laser turret: tracking beam; destroyed turrets vanish.
//! Reference behaviour: lasergat.cpp (docs/class-porting.md).
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
pub const policy = catalog.lasergat;
pub const attacks: []const []const u8 = &policy.attacks;
pub const vanish_on_death = true;
/// Its first turn drops its clips to 10 fps for good (the reference's turn animation call), and
/// it turns before its first shot.
pub const clip_fps = 10;
/// The turret runs its whole step itself and never moves.
pub fn preempt(frame: *Frame) !bool {
    try @import("lasergats.zig").think(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
    common.hold(frame);
    return true;
}
/// Idle, it holds its closed frame.
pub fn playback(view: context.View) !?Playback {
    if (view.actor.mode == .attack) return null;
    return .{ .sequence = .{ .first = 1, .last = 1 }, .started = view.now };
}
