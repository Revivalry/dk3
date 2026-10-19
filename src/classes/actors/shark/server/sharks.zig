// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: shark. Server adapter for the shark class.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const engine = @import("../../../../engine/server.zig");
const c = abi.c;
const v = @import("../../../../core/domain/vector.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const Actors = @import("../../../../mechanics/server/actors.zig").Actors;
const policy = @import("actor_catalog").shark;
/// The shark's bite lands once per clip, whichever way it faces, aimed ahead of its prey.
const melee_events: @import("../../../../mechanics/server/ground_combat.zig").Events = .{ .single_strike = true, .unfaced = true, .leading = true };
pub fn think(actors: *Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, now: i64) !void {
    const definition = actors.table.definitions[actor.definition];
    const state = &actor.shark;
    if (state.suspended_target != 0) {
        if (@import("../../../../mechanics/server/region_access.zig").find(world, state.suspended_target)) |target| {
            if ((try target.get(data.Health)).current <= 0) {
                state.suspended_target = 0;
                actor.ignore_player = false;
            } else if (policy.resumes(try @import("../../../../mechanics/server/actor_water.zig").levelOwned(target))) {
                actor.threat = state.suspended_target;
                actor.ignore_player = false;
                state.suspended_target = 0;
            }
        } else {
            state.suspended_target = 0;
            actor.ignore_player = false;
        }
    }
    const hurt = (try world.get(entity, data.Hurt)).*;
    const injured = hurt.revision != actor.receipt;
    const previous_threat = actor.threat;
    var sensed = try @import("../../../../mechanics/server/actor_perception.zig").perceive(world, slots, entity, actor, pose.*, definition, now);
    if (sensed.enemy) |target| if (policy.abandons(try @import("../../../../mechanics/server/actor_water.zig").levelOwned(target))) {
        state.suspended_target = try target.id();
        actor.ignore_player = true;
        actor.threat = 0;
        sensed.enemy = null;
    };
    state.wandering = sensed.enemy == null;
    // The generic handler at 100%: every hit flinches, but the acquiring hit only for 25 or more.
    if (injured and try @import("../../../../mechanics/server/actor_pain.zig").generic(world, entity, actor, definition, hurt, previous_threat, policy.pain_chance, policy.pain_limit, now)) actor.melee.active = false;
    if (actor.reaction_until_ms) |until| {
        if (now < until) {
            actor.mode = .idle;
            return;
        }
        actor.reaction = null;
        actor.reaction_until_ms = null;
    }
    const tick = now >= actor.think_ms;
    if (tick) actor.think_ms = now + 100;
    if (state.wandering) {
        actor.melee.active = false;
        // Only a wandering shark, or one whose prey left the water, roams; the rest idle.
        if (!@import("actor_catalog").spawnflags.wanders((try world.get(entity, data.MapObject)).flags) and state.suspended_target == 0) {
            state.destination = null;
            actor.mode = .idle;
            return;
        }
        if (tick and (state.destination == null or now >= state.wander_until_ms or v.length(v.subtract(state.destination.?, pose.position)) < definition.walk_speed * 0.2)) {
            state.destination = try @import("../../../../mechanics/server/actor_wander.zig").next(&actors.ground_routes, pose.*, state.start, definition, try world.get(entity, data.Random), .{ .body = (try world.get(entity, data.Body)).*, .slot = (try world.get(entity, data.Binding)).slot });
            if (state.destination) |destination| state.wander_until_ms = now + @as(i64, @intFromFloat(v.length(v.subtract(destination, pose.position)) / (definition.walk_speed * policy.wander_pace) * 1000)) + 1000;
        }
        if (state.destination) |destination| actor.threat_position = destination;
        actor.mode = if (state.destination == null) .idle else .chase;
        return;
    }
    state.destination = null;
    const delta = v.subtract(actor.threat_position, pose.position);
    const yaw = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
    if (tick) pose.angles[1] += std.math.clamp(@mod(yaw - pose.angles[1] + 180, 360) - 180, -definition.yaw_speed, definition.yaw_speed);
    const target = sensed.enemy.?;
    if (actor.melee.active) {
        try @import("../../../../mechanics/server/ground_combat.zig").emit(melee_events, .{ .world = world, .slots = slots, .projections = projections, .entity = entity, .actor = actor, .pose = pose.*, .definition = &definition, .target = target, .now = now }, true);
        if (now - actor.melee.started_ms >= definition.attacks[actor.melee.pose].lastFrameMs()) actor.melee.active = false;
    }
    if (!actor.melee.active and tick and sensed.visible and sensed.distance < definition.range and sensed.distance < 100) {
        actor.melee.begin(policy.select((try world.get(entity, data.Random)).next()), now);
        actor.changed_ms = now;
    }
    actor.mode = if (actor.melee.active) .attack else .chase;
    if (actor.melee.active) try @import("../../../../mechanics/server/ground_combat.zig").emit(melee_events, .{ .world = world, .slots = slots, .projections = projections, .entity = entity, .actor = actor, .pose = pose.*, .definition = &definition, .target = target, .now = now }, true);
}
pub fn swim(actors: *Actors, actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, slot: u16, elapsed: u32, slow: f32) !void {
    const definition = actors.table.definitions[actor.definition];
    velocity.linear = @splat(0);
    if (actor.mode == .chase) {
        var destination = actor.threat_position;
        // A target with only its feet in water must be approached horizontally;
        // the shark's own route and hull stay in the water.
        if (try @import("../../../../mechanics/server/actor_collision.zig").service().contents(destination, slot) & c.MASK_WATER == 0) destination[2] = pose.position[2];
        if (try actors.ground_routes.nextWater(pose.position, destination, body.*, slot)) |next| {
            const speed = (if (actor.shark.wandering) definition.walk_speed * policy.wander_pace else definition.speed) * slow;
            var direction = v.normalize(v.subtract(next, pose.position));
            if (try @import("../../../../mechanics/server/actor_water.zig").level(pose.position, body.*, slot) < 3) direction[2] = 0;
            velocity.linear = v.scale(v.normalize(direction), speed);
            if (v.length(velocity.linear) > 0) pose.angles = .{ -std.math.atan2(direction[2], @sqrt(direction[0] * direction[0] + direction[1] * direction[1])) * 180 / std.math.pi, std.math.atan2(direction[1], direction[0]) * 180 / std.math.pi, 0 };
        } else if (!actor.shark.wandering) {
            // No way through the water to its prey: it gives up the chase.
            actor.threat = 0;
        }
    }
    var remaining = elapsed;
    while (remaining > 0) {
        const slice = @min(50, remaining);
        remaining -= slice;
        const endpoint = v.add(pose.position, v.scale(velocity.linear, @as(f32, @floatFromInt(slice)) * 0.001));
        if (try @import("../../../../mechanics/server/actor_collision.zig").service().contents(endpoint, slot) & c.MASK_WATER == 0) {
            velocity.linear = @splat(0);
            break;
        }
        try @import("../../../../mechanics/server/actor_flight.zig").move(pose, body.*, velocity, slot, slice);
    }
    body.grounded = false;
    actor.ground_entity = c.ENTITYNUM_NONE;
}
