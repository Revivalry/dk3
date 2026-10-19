// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the world side of fighting from cover (src/actors/cover.zig): whether an
//! enemy is completely visible across both shoulders, and which hide node it cannot see.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const Ref = @import("../domain/world_references.zig").Ref;
const v = @import("../../core/domain/vector.zig");
const c = @import("../../engine/abi.zig").c;
const Routes = @import("air_routes.zig").Routes;
const nav = @import("../../core/domain/navigation.zig");
const collision = @import("region_collision.zig");
const policy = @import("actor_catalog").cover;
const Frame = @import("actor_classes/frame.zig").Frame;
/// Both shoulder sight lines of the actor reach the enemy (reference AI_IsCompletelyVisible).
pub fn completelyVisible(world: *data.World, pose: data.Transform, body: data.Body, slot: u16, enemy: Ref) !bool {
    const other = (try enemy.get(data.Body)).*;
    const target = policy.sightPoint((try enemy.get(data.Transform)).position, other.mins[2], other.maxs[2]);
    const center = policy.sightPoint(pose.position, body.mins[2], body.maxs[2]);
    for (policy.shoulders(center, v.subtract(target, center), body.maxs[0] - body.mins[0])) |start| {
        const hit = try collision.trace(.{ .start = start, .end = target, .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = c.MASK_SOLID });
        if (!collision.reaches(world, hit, enemy)) return false;
    }
    return true;
}
/// The closest reachable hide node within `policy.hide_radius` that the enemy cannot see, along
/// the line to its centre nor along either shoulder line of the actor's width (reference
/// NODE_GetClosestCompleteHideNode). Null when none qualifies: the actor then fights from where
/// it stands.
pub fn hideNode(routes: *const Routes, navigation: nav.Service, pose: data.Transform, body: data.Body, slot: u16, enemy: Ref) !?v.Vec3 {
    const from = (try enemy.get(data.Transform)).position;
    const enemy_slot = (try enemy.get(data.Binding)).slot;
    const enemy_id = try enemy.id();
    const Candidate = struct { distance: f32, position: v.Vec3 };
    var candidates: [64]Candidate = undefined;
    var count: usize = 0;
    for (routes.nodes) |node| {
        if (node.flags & policy.hide_node == 0) continue;
        const distance = v.length(v.subtract(node.position, pose.position));
        if (distance >= policy.hide_radius) continue;
        if (count < candidates.len) {
            candidates[count] = .{ .distance = distance, .position = node.position };
            count += 1;
        } else {
            // Keep the closest when more qualify than fit.
            var farthest: usize = 0;
            for (candidates, 0..) |candidate, i| if (candidate.distance > candidates[farthest].distance) {
                farthest = i;
            };
            if (distance < candidates[farthest].distance) candidates[farthest] = .{ .distance = distance, .position = node.position };
        }
    }
    std.mem.sort(Candidate, candidates[0..count], {}, struct {
        fn closer(_: void, a: Candidate, b: Candidate) bool {
            return a.distance < b.distance;
        }
    }.closer);
    for (candidates[0..count]) |candidate| {
        const node = candidate.position;
        const width = body.maxs[0] - body.mins[0];
        const near = policy.shoulders(from, v.subtract(node, from), width);
        const far = policy.shoulders(node, v.subtract(node, from), width);
        if (!try hidden(enemy.world, enemy_slot, enemy_id, from, node)) continue;
        if (!try hidden(enemy.world, enemy_slot, enemy_id, near[0], far[0]) or !try hidden(enemy.world, enemy_slot, enemy_id, near[1], far[1])) continue;
        // Reachable the way the actor actually walks.
        if (try navigation.next(.{ .position = pose.position, .destination = node, .slot = slot }) == null) continue;
        return node;
    }
    return null;
}
fn hidden(world: *data.World, slot: u16, id: u32, from: v.Vec3, to: v.Vec3) !bool {
    return (try collision.owned(world, .{ .start = from, .end = to, .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = c.MASK_SOLID }, id)).fraction < 1;
}

/// Between shots from cover (the reference's take-cover goal): finish the run to a hide node, now
/// and then run back out to look (`chance.fraction()` rolls each look period), and otherwise hide
/// whenever the enemy can see the actor. True while running; `destination` says where to.
pub fn between(frame: *Frame, in_sight: bool, chance: anytype) !bool {
    const actor = frame.actor;
    const cover = &actor.cover;
    const now = frame.now;
    // A run that stops making progress is given up (reference stuck detector); the actor then
    // fights from where it stands until the next search.
    if (cover.moving() and actor.route.blocked) {
        cover.reset();
        cover.search_ms = now + policy.look_period_ms;
        return false;
    }
    if (cover.looking_until_ms) |until| if (now >= until) {
        cover.looking_until_ms = null;
    };
    if (cover.destination) |point| if (policy.arrived(frame.pose.position, point)) {
        cover.destination = null;
    };
    if (cover.moving()) return true;
    if (cover.look(now, chance.fraction())) return true;
    if (!in_sight or now < cover.search_ms) return false;
    cover.search_ms = now + policy.search_period_ms;
    const enemy = @import("region_access.zig").find(frame.world, actor.threat) orelse return false;
    const node = try hideNode(&frame.actors.ground_routes, frame.navigation, frame.pose.*, frame.body.*, frame.slot, enemy) orelse return false;
    if (policy.arrived(frame.pose.position, node)) return false;
    cover.destination = node;
    return true;
}
/// Where a cover run heads: its hide node, or its enemy while it looks out. Null when it stays.
pub fn destination(frame: *const Frame) ?v.Vec3 {
    if (frame.actor.cover.destination) |point| return point;
    if (frame.actor.cover.looking_until_ms != null) return frame.threat;
    return null;
}
/// A world random source for `between`.
pub const Chance = struct {
    random: *data.Random,
    pub fn fraction(self: Chance) f32 {
        return self.random.next();
    }
};

/// What one think of fighting from cover did; the class delivers its shot while `attacking`.
pub const Cycle = enum { attacking, ended, started, running, waiting };
/// One think of the reference's cover fight for a class whose shot is clip `pose`: shoot only
/// while the enemy is completely visible and `rest_until` has passed, rest 2–8 s after each shot,
/// and hide between shots.
pub fn cycle(frame: *Frame, target: Ref, visible: bool, rest_until: *i64, pose: u3, tick: bool) !Cycle {
    const actor = frame.actor;
    const now = frame.now;
    const random = try frame.world.get(frame.entity, data.Random);
    if (actor.melee.active) {
        actor.mode = .attack;
        if (now - actor.melee.started_ms < frame.definition.attacks[actor.melee.pose].lastFrameMs()) return .attacking;
        actor.melee.active = false;
        rest_until.* = now + policy.rest(random.next());
        return .ended;
    }
    if (tick and now >= rest_until.* and try completelyVisible(frame.world, frame.pose.*, frame.body.*, frame.slot, target)) {
        actor.cover.reset();
        actor.melee.begin(pose, now);
        actor.changed_ms = now;
        actor.mode = .attack;
        return .started;
    }
    const running = try between(frame, visible, Chance{ .random = random });
    actor.mode = if (running) .chase else .idle;
    return if (running) .running else .waiting;
}
