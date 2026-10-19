// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: medusa. Medusa: bites, venom spit and the petrifying gaze.
//! Reference behaviour: medusa.cpp (docs/class-porting.md).
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
pub const policy = catalog.medusa;
pub const attacks: []const []const u8 = &policy.attacks;
pub const routes: context.Routes = .{ .ground = true };
/// Outside combat the boss runs its own phases, not paths.
pub fn follows(actor: *const data.Actor) bool {
    return actor.medusa.phase == .combat;
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("medusas.zig").step(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.now, frame.elapsed, frame.slow);
}
/// The gaze: open eyes, the flash and its target.
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    const state = decoration.state;
    state.time2 = policy.gaze_tag;
    state.origin2[0] = if (actor.mode != .dead and actor.medusa.eyes) 1 else 0;
    state.torsoAnim = @intCast(actor.medusa.flash_until_ms);
    state.otherEntityNum = if (decoration.view.world.find(actor.medusa.target)) |target| (try decoration.view.world.get(target, data.Binding)).slot else abi.c.ENTITYNUM_NONE;
}
/// The gaze names its target.
pub fn linkedIdentity(actor: *const data.Actor) ?u32 {
    return actor.medusa.target;
}
