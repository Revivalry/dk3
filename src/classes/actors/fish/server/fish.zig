// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: fish. Fish and the Dopefish: authored water nodes; only the Dopefish bites.
//! Reference behaviour: goldfish.cpp, greyfish.cpp, dopefish.cpp (docs/class-porting.md).
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
pub const policy = catalog.fish;
pub const clips = [_]context.Clip{.{ .slot = .swim, .name = "swima" }};
pub const routes: context.Routes = .{ .ground = true };
pub fn attacks(kind: catalog.Kind) []const []const u8 {
    return if (kind == .dopefish) &policy.attacks else &.{};
}
/// The Dopefish's bite has no supplied event row; it strikes on its second frame.
pub fn attackLoad(_: catalog.Kind, _: usize) context.AttackLoad {
    return .{ .events = .first_frame };
}
/// Fish are scenery: they ignore the player and do not block.
pub fn spawn(spawning: *context.Spawn) !void {
    const actor = try spawning.actor();
    actor.fish.start = try spawning.position();
    actor.ignore_player = spawning.kind == .fish;
    if (spawning.kind == .fish) (try spawning.world.get(spawning.entity, data.Body)).contents = abi.c.CONTENTS_CORPSE;
}
pub const perceive = common.perceiveNothing;
pub fn pathMove(frame: *Frame, point: ?v.Vec3, _: f32) !void {
    if (point) |destination| frame.actor.threat_position = destination;
    try @import("fishes.zig").move(frame.actors, frame.actor, frame.pose, frame.body, frame.velocity, frame.slot, frame.elapsed, frame.now, 1);
}
pub fn think(frame: *Frame) !void {
    try @import("fishes.zig").think(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.now);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("fishes.zig").move(frame.actors, frame.actor, frame.pose, frame.body, frame.velocity, frame.slot, frame.elapsed, frame.now, frame.slow);
}
