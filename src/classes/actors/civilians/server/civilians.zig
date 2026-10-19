// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: civilians. Workers hide from the player they see, run away when hurt and cower;
//! plain prisoners wander once alerted; all follow their work scripts and spawnflags.
//! Reference behaviour: skinnyworker.cpp, fatworker.cpp, PRISONER.CPP, ai_func.cpp
//! (docs/class-porting/civilians.md).
const std = @import("std");
const catalog = @import("actor_catalog");
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const Playback = @import("../../../../core/domain/animation.zig").Playback;
const context = @import("../../../../mechanics/server/actor_classes/frame.zig");
const common = @import("../../../../mechanics/server/actor_classes/common.zig");
const Frame = context.Frame;
const Actors = context.Actors;
pub const policy = catalog.civilians;
pub const path_gait: @import("../../../../mechanics/server/actor_classes/registry.zig").Gait = .walk;
/// Wandering walks the ground node graph.
pub const routes: context.Routes = .{ .ground = true };
const workers = policy.workers;
const spawnflags = catalog.spawnflags;
pub const helpers = [_][]const u8{"panic"};
fn roleOf(actor: *const data.Actor) policy.Role {
    return policy.roleOf(catalog.entries[actor.definition].classname);
}
/// A worker hides (or, hurt, runs away) for its retreat time on a fresh route, then cowers; one
/// that may not move cowers at once.
pub fn panic(actor: *data.Actor, source: u32, point: v.Vec3, mobile: bool, now: i64) void {
    if (actor.mode == .dead) return;
    actor.worker.start(now);
    actor.roam.destination = null;
    if (!mobile) {
        actor.threat = source;
        actor.threat_position = point;
        actor.worker.stop(now);
        return;
    }
    actor.route = .{};
    @import("../../../../mechanics/domain/actors.zig").panic(actor, source, point, workers.retreat_ms, now);
}
/// Alerted without fear: the civilian knows its enemy (a prisoner then wanders).
fn alert(actor: *data.Actor, source: u32, point: v.Vec3) void {
    actor.threat = source;
    actor.threat_position = point;
}
/// Workers fear what hurts them or what they see hurt; prisoners are only alerted.
fn react(actor: *data.Actor, role: policy.Role, flee: bool, source: u32, point: v.Vec3, mobile: bool, now: i64) void {
    if (role.worker and flee) panic(actor, source, point, mobile, now) else alert(actor, source, point);
}
pub fn loadAnimations(load: context.Load) !void {
    load.definition.walk = try load.find("walka") orelse return error.MissingActorWalk;
    if (!policy.roleOf(load.classname).cower_clips) return;
    for (workers.cower_poses, 0..) |name, index| load.definition.cower[index] = try load.find(name) orelse return error.MissingWorkerCower;
}
/// Workers notice a visible player (the step skips this while a work script acts, and
/// `ignore_player` blinds them); prisoners never notice him by sight.
pub fn perceive(frame: *Frame) !void {
    if (!roleOf(frame.actor).worker) return;
    // Look from the eyes (as the visibility checks below do): a worker on a chair has his origin
    // inside it.
    var eyes = frame.pose.*;
    eyes.position[2] += 16;
    try @import("../../../../mechanics/server/actor_perception.zig").acquire(frame.world, frame.slots, frame.entity, frame.actor, eyes, frame.definition.*, frame.now);
}
pub fn prepare(frame: *Frame) !void {
    const world = frame.world;
    const actor = frame.actor;
    const pose = frame.pose.*;
    const hurt = frame.hurt;
    const now = frame.now;
    const role = roleOf(actor);
    const mobile = spawnflags.moves((try world.get(frame.entity, data.MapObject)).flags);
    if (hurt.revision != actor.receipt) {
        actor.receipt = hurt.revision;
        const source = @import("../../../../mechanics/server/region_access.zig").find(world, hurt.source);
        const point = if (source) |found| (try found.get(data.Transform)).position else pose.position;
        // Hurt by a player, it no longer ignores him.
        if (source) |found| if ((found.get(data.Player) catch null) != null) {
            actor.ignore_player = false;
        };
        react(actor, role, role.flees_pain, hurt.source, point, mobile, now);
    }
    // A dead civilian records its last attacker. Only a new, visible death (or a worker's injury)
    // within the alert radius alerts a witness; a witnessing worker hides.
    for (frame.slots.occupants, 0..) |other, other_slot| {
        const corpse = other orelse continue;
        if (other_slot == frame.slot or !world.alive(corpse)) continue;
        const other_actor = world.get(corpse, data.Actor) catch continue;
        if ((try world.get(corpse, data.Health)).current > 0 and !roleOf(other_actor).worker) continue;
        const receipt = (try world.get(corpse, data.Hurt)).*;
        if (receipt.at_ms <= actor.witness_ms) continue;
        const point = (try world.get(corpse, data.Transform)).position;
        if (v.length(v.subtract(point, pose.position)) > catalog.entries[actor.definition].witness_range) continue;
        if (!try Actors.visible(v.add(pose.position, .{ 0, 0, 16 }), point, frame.slot, @intCast(other_slot))) continue;
        actor.witness_ms = receipt.at_ms;
        react(actor, role, true, receipt.source, point, mobile, now);
    }
    // A calm worker hides from an enemy in sight.
    if (role.worker and actor.worker.phase == .calm and actor.mode != .flee and !actor.ignore_player and actor.threat != 0) {
        if (@import("../../../../mechanics/server/region_access.zig").find(world, actor.threat)) |enemy| {
            const point = (try enemy.get(data.Transform)).position;
            if (try Actors.visible(v.add(pose.position, .{ 0, 0, 16 }), point, frame.slot, (try enemy.get(data.Binding)).slot)) panic(actor, actor.threat, point, mobile, now);
        }
    }
    if (role.worker) try @import("workers.zig").think(world, frame.slots, frame.projections, frame.entity, actor, pose, frame.definition.*, role, mobile, now);
    try roam(frame, role, mobile);
}
/// Node wander: spawnflags 1 and 4 while calm, an alerted prisoner for good, and a fat worker
/// through his cower (he has no cower clips). Never while a script acts.
fn roam(frame: *Frame, role: policy.Role, mobile: bool) !void {
    const actor = frame.actor;
    const acting = if (frame.world.get(frame.entity, data.Script) catch null) |script| script.active else false;
    const flags = (try frame.world.get(frame.entity, data.MapObject)).flags;
    const calm = actor.threat == 0 and actor.worker.phase == .calm and spawnflags.wanders(flags);
    const alerted = !role.worker and actor.threat != 0;
    const restless = role.worker and !role.cower_clips and actor.worker.phase == .cower;
    const wanders = mobile and !acting and actor.mode != .flee and actor.mode != .dead and (calm or alerted or restless);
    if (wanders and try common.roam(frame)) {
        if (actor.mode != .chase) actor.changed_ms = frame.now;
        actor.mode = .chase;
        return;
    }
    actor.roam.destination = null;
    if (actor.mode == .chase) {
        actor.mode = .idle;
        actor.changed_ms = frame.now;
    }
}
/// Fleeing or cowering civilians leave their scripts and paths.
pub fn scriptable(actor: *const data.Actor) bool {
    return actor.mode != .flee and actor.worker.phase != .cower;
}
pub fn follows(actor: *const data.Actor) bool {
    return actor.worker.phase != .cower;
}
/// Wander legs walk; a worker's flight settles where it was headed and he cowers there; one that
/// may not move stays put.
pub fn move(frame: *Frame) !void {
    const actor = frame.actor;
    if (actor.mode == .chase) if (actor.roam.destination) |point| return common.moveTo(frame, point, frame.definition.walk_speed);
    if (!spawnflags.moves((try frame.world.get(frame.entity, data.MapObject)).flags)) return common.hold(frame);
    if (try common.moveFleeing(frame, .{ .settles = roleOf(actor).worker })) actor.worker.stop(frame.now);
}
/// Cowering, no idle ambient plays.
pub fn idleVaries(actor: *const data.Actor) bool {
    return actor.worker.phase != .cower;
}
/// Fleeing pauses the civilian's script.
pub fn pausesScript(actor: *const data.Actor) bool {
    return actor.mode == .flee;
}
/// Wander legs walk; a cowering skinny worker plays his cower clip (the fat worker wanders).
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (actor.mode == .dead or actor.reaction != null) return null;
    if (actor.mode == .chase and actor.roam.destination != null) return view.moded(view.definition.walk, view.modeStarted());
    const role = roleOf(actor);
    if (!role.worker or actor.worker.phase != .cower) return null;
    return .{ .sequence = if (role.cower_clips) view.definition.cower[actor.worker.variant] else view.definition.idle, .started = actor.worker.started_ms, .looping = true };
}
pub fn diagnose(view: context.View, writer: *std.Io.Writer) !void {
    const actor = view.actor;
    const cowering = actor.worker.phase == .cower and roleOf(actor).cower_clips;
    const clip = if (cowering) view.definition.cower[actor.worker.variant] else view.definition.run;
    try writer.print(" worker={s} worker_frame={d}", .{ @tagName(actor.worker.phase), clip.frame(view.now - actor.worker.started_ms, true) });
    if (actor.roam.destination) |point| try writer.print(" roam={d:.0},{d:.0},{d:.0}", .{ point[0], point[1], point[2] });
}
/// The fat worker always bursts when killed.
pub fn mustGib(actor: *const data.Actor) bool {
    return roleOf(actor).always_gibs;
}
