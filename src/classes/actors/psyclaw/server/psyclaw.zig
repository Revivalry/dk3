// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: psyclaw. Psyclaw: claws, psychic spheres and the warp.
//! Reference behaviour: psyclaw.cpp (docs/class-porting.md).
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
pub const policy = catalog.psyclaw;
pub const attacks: []const []const u8 = &policy.attacks;
/// A new psyclaw cannot be hurt for 750 ms.
pub fn spawn(spawning: *context.Spawn) !void {
    (try spawning.actor()).psyclaw.protected_until_ms = spawning.now + 750;
}
pub fn think(frame: *Frame) !void {
    try @import("psyclaws.zig").think(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
}
/// Newly spawned, it shrugs off damage.
pub fn admitDamage(actor: *const data.Actor, damage: context.Damage) bool {
    return damage.now > actor.psyclaw.protected_until_ms;
}
