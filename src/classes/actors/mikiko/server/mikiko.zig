// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: mikiko. Mikiko: sword strikes, awakening and the sword aura.
//! Reference behaviour: mikiko_monster.cpp (docs/class-porting.md).
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
pub const policy = catalog.mikiko;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{.{ .slot = .death_b, .name = "dieb", .fallback = .death }};
pub const routes: context.Routes = .{ .ground = true };
/// The third clip has no supplied event row; it strikes on its second frame.
pub fn attackLoad(_: catalog.Kind, index: usize) context.AttackLoad {
    return if (index == 2) .{ .events = .first_frame } else .{};
}
pub fn die(frame: *Frame) !void {
    try common.deathCoin(frame, 0.5);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("mikiko_actor.zig").step(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.now, frame.elapsed, frame.slow);
}
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    const state = decoration.state;
    state.loopSound = if (actor.mode != .dead and actor.mikiko.awakened) try @import("../../../../mechanics/server/resources.zig").sound("global/we_dk_03a.wav") else 0;
    // The aura lasts through her death clip and goes when it ends.
    if (!actor.mikiko.aura or (actor.mode == .dead and decoration.view.now - actor.changed_ms >= decoration.view.definition.death.lastFrameMs())) return;
    state.time2 = catalog.sword_aura_tag;
    state.time = @intCast(actor.mikiko.aura_started_ms);
    state.origin2 = .{ actor.mikiko.light_red, -1, -1 };
    state.legsAnim = 0;
}
