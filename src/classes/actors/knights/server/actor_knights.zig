// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: knights. Flame and lightning knights: melee and ranged spells.
//! Reference behaviour: knight1.cpp, knight2.cpp (docs/class-porting.md).
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
pub const policy = catalog.knights;
pub const clips = [_]context.Clip{.{ .slot = .death_b, .name = "dieb" }};
pub fn attacks(kind: catalog.Kind) []const []const u8 {
    return if (kind == .knight1) &policy.flame_attacks else &policy.lightning_attacks;
}
/// The lightning knight's in-place punch (`runa`) has no event row: it strikes on the second frame.
pub fn attackLoad(kind: catalog.Kind, index: usize) context.AttackLoad {
    return if (kind == .knight2 and index == 0) .{ .events = .first_frame } else .{};
}
/// Knight1 always plays its first death (its own death callback is never installed); knight2
/// flips a coin.
pub fn die(frame: *Frame) !void {
    if (frame.kind == .knight2) try common.deathCoin(frame, 0.5);
}
pub fn think(frame: *Frame) !void {
    try @import("knights.zig").think(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
}
