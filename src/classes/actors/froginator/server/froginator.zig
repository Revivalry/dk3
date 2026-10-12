// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: froginator. Froginator: spit, bite and jumps.
//! Reference behaviour: froginator.cpp (docs/class-porting.md).
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
pub const policy = catalog.froginator;
pub const attacks: []const []const u8 = &policy.attacks;
/// Wandering walks the ground node graph.
pub const routes: context.Routes = .{ .ground = true };
pub fn loadAnimations(load: context.Load) !void {
    load.definition.walk = try load.find("walka") orelse return error.MissingActorWalk;
}
pub fn think(frame: *Frame) !void {
    if (frame.body.motion_owner != null) return;
    const actor = frame.actor;
    // Pain (not in mid-leap); afterwards the frog decides afresh (a new attack or leap).
    if (actor.frog.phase != .jump and try common.flinch(frame, policy.pain_chance)) {
        if (actor.reaction_started_ms == frame.now) actor.frog.enter(.decide, frame.now);
        return;
    }
    const flags = (try frame.world.get(frame.entity, data.MapObject)).flags;
    const mobile = catalog.spawnflags.moves(flags);
    try @import("froginators.zig").think(frame.world, frame.slots, frame.projections, frame.entity, actor, frame.pose, frame.body.*, try frame.world.get(frame.entity, data.Velocity), frame.definition.*, mobile, frame.now);
    // Without an enemy: spawnflags 1/4, or once it has seen the player, it wanders the nodes.
    if (actor.threat == 0 and actor.mode == .idle and mobile and (catalog.spawnflags.wanders(flags) or actor.threat_seen_ms != 0) and try common.roam(frame)) {
        actor.mode = .chase;
    } else if (actor.threat != 0) actor.roam.destination = null;
}
pub fn move(frame: *Frame) !void {
    if (!frame.dead and frame.actor.mode == .chase and frame.actor.threat == 0) if (frame.actor.roam.destination) |point| return common.moveTo(frame, point, frame.definition.walk_speed);
    if (!frame.dead and !catalog.spawnflags.moves((try frame.world.get(frame.entity, data.MapObject)).flags)) return common.hold(frame);
    if (frame.dead or frame.actor.frog.phase != .jump) return common.move(frame);
    try @import("froginators.zig").jump(frame.actor, frame.pose, frame.body, frame.velocity, frame.slot, frame.elapsed);
}
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (view.open() and actor.mode == .chase and actor.threat == 0 and actor.roam.destination != null) return view.moded(view.definition.walk, view.modeStarted());
    if (!view.open() or actor.mode != .attack) return null;
    return .{ .sequence = view.definition.attacks[actor.frog.pose()], .started = actor.frog.started_ms, .looping = false };
}
pub fn diagnose(view: context.View, writer: *std.Io.Writer) !void {
    const frog = view.actor.frog;
    const until = if (frog.phase == .spit or frog.phase == .bite) frog.started_ms + view.definition.attacks[frog.pose()].duration() else 0;
    try writer.print(" frog={s} attack_left={d}", .{ @tagName(frog.phase), @max(0, until - view.now) });
}
