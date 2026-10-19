// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: crox. Crox: wandering, swimming and authored bites.
//! Reference behaviour: crox.cpp (docs/class-porting.md).
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
pub const policy = catalog.crox;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{ .{ .slot = .swim, .name = "swima" }, .{ .slot = .walk, .name = "walka" }, .{ .slot = .death_b, .name = "dieb" } };
pub const routes: context.Routes = .{ .ground = true };
pub fn loadAnimations(load: context.Load) !void {
    const definition = load.definition;
    if (definition.walk_speed <= 0 or definition.range <= 0 or definition.damage <= 0) return error.InvalidCroxTuning;
}
pub fn spawn(spawning: *context.Spawn) !void {
    (try spawning.actor()).crox = .{ .start = try spawning.position(), .cycle_ms = spawning.now + spawning.definition.idle.duration() };
}
pub fn die(frame: *Frame) !void {
    frame.actor.crox.death_b = (try frame.world.get(frame.entity, data.Random)).next() >= 0.5;
}
pub fn think(frame: *Frame) !void {
    if (frame.body.motion_owner != null) return;
    // A flinch interrupts the bite; the next one starts afresh.
    if (try common.flinch(frame, policy.pain_chance)) {
        frame.actor.crox.attacking = false;
        return;
    }
    try @import("crox.zig").think(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body.*, try frame.world.get(frame.entity, data.Velocity), frame.now);
}
pub fn move(frame: *Frame) !void {
    if (!frame.dead and frame.actor.crox.swimming) return @import("crox.zig").swim(frame.actors, frame.actor, frame.pose, frame.body, frame.velocity, frame.definition.*, frame.slot, frame.elapsed, frame.slow);
    try common.moveAt(frame, if (frame.actor.crox.wandering) frame.definition.walk_speed else frame.definition.speed);
}
/// Swimming, wandering, running or idling; its own attack timing; and its second death.
pub fn playback(view: context.View) !?Playback {
    if (!view.open() or view.actor.reaction != null) return null;
    const actor = view.actor;
    const definition = view.definition;
    return switch (actor.mode) {
        .dead => if (actor.crox.death_b) .{ .sequence = definition.death_b, .started = actor.changed_ms, .looping = false } else null,
        .attack => .{ .sequence = definition.attacks[actor.crox.pose], .started = actor.crox.started_ms, .looping = false },
        else => view.moded(if (actor.crox.swimming) definition.swim else if (actor.crox.wandering) definition.walk else if (actor.mode == .chase) definition.run else actor.idle_pose orelse definition.idle, view.modeStarted()),
    };
}
pub fn diagnose(view: context.View, writer: *std.Io.Writer) !void {
    const crox = view.actor.crox;
    const until = if (crox.attacking) crox.started_ms + view.definition.attacks[crox.pose].duration() else 0;
    try writer.print(" crox_water={d} crox_swim={d} crox_wander={d} crox_pose={d} crox_struck={d} attack_left={d}", .{ crox.water, @intFromBool(crox.swimming), @intFromBool(crox.wandering), crox.pose, @intFromBool(crox.struck), @max(0, until - view.now) });
}
/// Swimming or wandering, its own clips play instead of idle ambients.
pub fn idleVaries(actor: *const data.Actor) bool {
    return !actor.crox.swimming and !actor.crox.wandering;
}
