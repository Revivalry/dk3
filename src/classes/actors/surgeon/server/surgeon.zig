// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: surgeon. Surgeon: works at its table and ignores the player until hurt, then
//! cowers and hides from him.
//! Reference behaviour: surgeon.cpp, skinnyworker.cpp (docs/class-porting/surgeon.md).
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
pub const policy = catalog.surgeon;
pub const attacks: []const []const u8 = &policy.poses;
pub const path_gait: @import("../../../../mechanics/server/actor_classes/registry.zig").Gait = .walk;
/// Its work poses have no supplied event rows.
pub fn attackLoad(_: catalog.Kind, _: usize) context.AttackLoad {
    return .{ .events = .none };
}
pub fn spawn(spawning: *context.Spawn) !void {
    (try spawning.actor()).ignore_player = true;
}
pub fn prepare(frame: *Frame) !void {
    try @import("surgeons.zig").think(frame);
}
/// Cowering or hiding, it neither runs scripts nor follows paths.
pub fn scriptable(actor: *const data.Actor) bool {
    return !actor.surgeon.active and !actor.surgeon.hiding;
}
pub fn follows(actor: *const data.Actor) bool {
    return scriptable(actor);
}
/// Once hurt by the player it sees him (the shared scan; `ignore_player` blinds it before).
pub fn perceive(frame: *Frame) !void {
    if (frame.actor.surgeon.active or frame.actor.surgeon.hiding) return;
    try @import("../../../../mechanics/server/actor_perception.zig").acquire(frame.world, frame.slots, frame.entity, frame.actor, frame.pose.*, frame.definition.*, frame.now);
}
/// A hide flight ends where it was headed.
pub fn move(frame: *Frame) !void {
    _ = try common.moveFleeing(frame, .{ .settles = true });
}
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (!actor.surgeon.active or actor.mode == .dead) return null;
    return .{ .sequence = view.definition.attacks[actor.surgeon.pose], .started = actor.surgeon.started_ms, .looping = true };
}
pub fn pausesScript(actor: *const data.Actor) bool {
    return actor.surgeon.active or actor.surgeon.hiding;
}
pub fn diagnose(view: context.View, writer: *std.Io.Writer) !void {
    const state = view.actor.surgeon;
    const phase = if (state.active) "cower" else if (state.hiding) "hide" else if (state.returning) "return" else "calm";
    try writer.print(" surgeon={s}", .{phase});
}
