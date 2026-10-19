// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the default behaviour behind actor class hooks, and helpers several classes
//! compose. Defaults live here once; a class overrides a hook instead of copying its default.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const std = @import("std");
const catalog = @import("actor_catalog");
const data = @import("../../../game/domain/components.zig");
const v = @import("../../../core/domain/vector.zig");
const context = @import("frame.zig");
const Frame = context.Frame;

/// `perceive` default: an actor following a path notices threats on the way; ambient wildlife
/// never does.
pub fn perceive(frame: *Frame) !void {
    if (frame.actor.path == 0 or catalog.ambient(frame.kind)) return;
    try @import("../actor_perception.zig").acquire(frame.world, frame.slots, frame.entity, frame.actor, frame.pose.*, frame.definition.*, frame.now);
}
/// `perceive` for classes that sense threats only through their own `think`.
pub fn perceiveNothing(_: *Frame) !void {}

/// `pathMove` default: steer on the ground toward the path or script point.
pub fn groundPath(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    if (point) |destination| frame.actor.threat_position = destination;
    try @import("../actor_motion.zig").step(frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.actor.threat_position, speed, frame.slot, frame.now, frame.elapsed);
}
/// `pathMove` for fliers: fly the air route graph toward the point, facing the next waypoint.
pub fn airPath(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    const pose = frame.pose;
    frame.velocity.linear = @splat(0);
    if (point) |destination| if (try frame.actors.air_routes.next(pose.position, destination, frame.body.*, frame.slot)) |waypoint| {
        const delta = v.subtract(waypoint, pose.position);
        frame.velocity.linear = v.scale(v.normalize(delta), @min(speed, v.length(delta) * 10));
        pose.angles[1] = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
    };
    try @import("../actor_flight.zig").move(pose, frame.body.*, frame.velocity, frame.slot, frame.elapsed);
}

/// `move` default: ground locomotion toward the threat at the run speed, slowed by freezing.
pub fn move(frame: *Frame) !void {
    try moveAt(frame, frame.definition.speed);
}
/// Ground locomotion toward the threat at `speed`, slowed by freezing.
pub fn moveAt(frame: *Frame, speed: f32) !void {
    try @import("../actor_motion.zig").step(frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.threat, speed * frame.slow, frame.slot, frame.now, frame.elapsed);
}
/// Pain for classes without their own pain controller: a hit from the current enemy (not the one
/// that makes its attacker the enemy) flinches with `hita` `chance` percent of the time, with no
/// damage threshold. True while the reaction plays: the class step yields, holding still.
pub fn flinch(frame: *Frame, chance: u8) !bool {
    const pain = @import("../actor_pain.zig");
    const actor = frame.actor;
    if (pain.reacting(actor, frame.now)) {
        frame.velocity.linear = @splat(0);
        return true;
    }
    const hurt = frame.hurt;
    if (hurt.revision == actor.receipt or hurt.source != actor.threat) return false;
    actor.receipt = hurt.revision;
    if (!try pain.direct(frame.world, frame.entity, actor, frame.definition.*, hurt.amount, chance, frame.now)) return false;
    frame.velocity.linear = @splat(0);
    return true;
}
/// Ground locomotion to `point` at `speed`, keeping the remembered enemy position.
pub fn moveTo(frame: *Frame, point: v.Vec3, speed: f32) !void {
    const remembered = frame.actor.threat_position;
    defer frame.actor.threat_position = remembered;
    frame.actor.threat_position = point;
    try moveAt(frame, speed);
}
/// Node wander: walk node to node, ahead where possible, within the active range of where the
/// wander began (`actor.roam`). True while a leg is walking; `moveTo` the roam point at walk speed.
pub fn roam(frame: *Frame) !bool {
    return roamOn(frame, &frame.actors.ground_routes, frame.definition.walk_speed);
}
/// Node wander on a given graph at `speed` (fliers wander the air graph at twice walk speed).
pub fn roamOn(frame: *Frame, routes: *const @import("../air_routes.zig").Routes, speed: f32) !bool {
    const actor = frame.actor;
    const pose = frame.pose;
    const state = &actor.roam;
    const home = state.home orelse pose.position;
    state.home = home;
    if (state.due(pose.position, frame.now, speed)) {
        const point = try @import("../actor_wander.zig").next(routes, pose.*, home, frame.definition.*, try frame.world.get(frame.entity, data.Random), null);
        state.leg(pose.position, point, frame.now, speed);
    }
    return state.destination != null;
}
/// A flier's wander point: spawnflags 1/4, or once it has seen the player, it roams the air
/// nodes while it has no enemy; null otherwise.
pub fn airWander(frame: *Frame, mobile: bool) !?v.Vec3 {
    const actor = frame.actor;
    if (actor.threat != 0 or !mobile) {
        actor.roam.destination = null;
        return null;
    }
    const flags = (try frame.world.get(frame.entity, data.MapObject)).flags;
    if (!catalog.spawnflags.wanders(flags) and actor.threat_seen_ms == 0) return null;
    return if (try roamOn(frame, &frame.actors.air_routes, frame.definition.walk_speed * 2)) actor.roam.destination else null;
}
/// Ground locomotion with a class flight rule; true when a settling flight ended.
pub fn moveFleeing(frame: *Frame, flee: @import("../actor_motion.zig").Flee) !bool {
    return @import("../actor_motion.zig").stepFleeing(flee, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.threat, frame.definition.speed * frame.slow, frame.slot, frame.now, frame.elapsed);
}
/// `move` for a class that holds still in its current phase.
pub fn hold(frame: *Frame) void {
    frame.velocity.linear = @splat(0);
}

/// The two-variant death roll: `death` below `chance`, else `death_b`.
pub fn deathCoin(frame: *Frame, chance: f32) !void {
    frame.actor.death_pose = if ((try frame.world.get(frame.entity, data.Random)).next() < chance) frame.definition.death else frame.definition.death_b;
}
/// Cosine of the angle between the actor's facing and the direction to its last attacker, or
/// null when the attacker is gone.
pub fn attackerFacing(frame: *Frame) !?f32 {
    const attacker = @import("../region_access.zig").find(frame.world, frame.hurt.source) orelse return null;
    const position = (try attacker.get(data.Transform)).position;
    return v.dot(v.basis(frame.pose.angles).forward, v.normalize(v.subtract(position, frame.pose.position)));
}

/// Writes the step's working copies back to the actor's components.
pub fn store(frame: *Frame) !void {
    (try frame.world.get(frame.entity, data.Actor)).* = frame.actor.*;
    (try frame.world.get(frame.entity, data.Transform)).* = frame.pose.*;
    (try frame.world.get(frame.entity, data.Velocity)).* = frame.velocity.*;
    (try frame.world.get(frame.entity, data.Body)).* = frame.body.*;
}
