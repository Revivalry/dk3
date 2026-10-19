// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: fish. Fish use authored water nodes; only Dopefish acquires a combat goal.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const c = abi.c;
const engine = @import("../../../../engine/server.zig");
const v = @import("../../../../core/domain/vector.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const Actors = @import("../../../../mechanics/server/actors.zig").Actors;
const catalog = @import("actor_catalog");
/// The Dopefish's bite is aimed ahead of its prey and leaves a blood cloud when it draws blood.
const melee_events: @import("../../../../mechanics/server/ground_combat.zig").Events = .{ .leading = true, .struck = bloodCloud };
fn bloodCloud(strike: *const @import("../../../../mechanics/server/ground_combat.zig").Strike, before: i32) !void {
    if ((try strike.target.get(data.Health)).current < before) try @import("blood_clouds.zig").spawn(strike.world, strike.slots, strike.projections, strike.target, strike.entity, strike.now);
}
pub fn think(actors: *Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, now: i64) !void {
    const definition = actors.table.definitions[actor.definition];
    const state = &actor.fish;
    const hurt = (try world.get(entity, data.Hurt)).*;
    const injured = hurt.revision != actor.receipt;
    const tick = now >= actor.think_ms;
    if (tick) actor.think_ms = now + 100;
    if (catalog.entries[actor.definition].kind == .dopefish) {
        if (@import("../../../../mechanics/server/region_access.zig").find(world, state.owner)) |owner| {
            if ((owner.get(data.Health) catch return error.MissingFishTargetHealth).current <= 0) {
                state.owner = 0;
                state.aggressive = false;
                actor.ignore_player = false;
            } else if (tick) {
                const distance = v.length(v.subtract((try owner.get(data.Transform)).position, pose.position));
                state.aggressive = catalog.fish.aggression(state.aggressive, distance, (try world.get(entity, data.Random)).next());
                actor.ignore_player = !state.aggressive;
                if (state.aggressive) actor.threat = state.owner else actor.threat = 0;
            }
        } else {
            state.owner = 0;
            state.aggressive = false;
            actor.ignore_player = false;
        }
        const previous_threat = actor.threat;
        const sensed = try @import("../../../../mechanics/server/actor_perception.zig").perceive(world, slots, entity, actor, pose.*, definition, now);
        if (state.owner == 0) {
            if (sensed.enemy) |target| {
                state.owner = try target.id();
                // The first sighting within its disengage distance starts the fight at once.
                state.aggressive = catalog.fish.firstSighting(sensed.distance);
            }
        }
        if (injured and sensed.enemy != null) state.aggressive = true;
        if (actor.reaction_until_ms) |until| {
            if (now < until) {
                actor.mode = .idle;
                return;
            }
            actor.reaction = null;
            actor.reaction_until_ms = null;
        }
        const pain = @import("../../../../mechanics/server/actor_pain.zig");
        if (injured and !pain.acquiring(world, hurt, previous_threat) and try pain.direct(world, entity, actor, definition, hurt.amount, 75, now)) return;
        if (state.aggressive) if (sensed.enemy) |target| {
            state.destination = null;
            const delta = v.subtract(actor.threat_position, pose.position);
            pose.angles[1] = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
            if (actor.melee.active) {
                if (sensed.distance < definition.attack_range) try @import("../../../../mechanics/server/ground_combat.zig").emit(melee_events, .{ .world = world, .slots = slots, .projections = projections, .entity = entity, .actor = actor, .pose = pose.*, .definition = &definition, .target = target, .now = now }, true);
                if (now - actor.melee.started_ms >= definition.attacks[0].lastFrameMs()) actor.melee.active = false;
            }
            if (tick and !actor.melee.active and sensed.visible and sensed.distance < definition.attack_range) {
                actor.melee.begin(0, now);
                actor.changed_ms = now;
            }
            actor.mode = if (actor.melee.active) .attack else .chase;
            return;
        };
    } else {
        actor.receipt = (try world.get(entity, data.Hurt)).revision;
        actor.threat = 0;
    }
    actor.melee.active = false;
    const object = (try world.get(entity, data.MapObject)).*;
    if (object.flags & 5 == 0) {
        actor.mode = .idle;
        return;
    }
    if (tick and (state.destination == null or now >= (state.wander_until_ms orelse now) or v.length(v.subtract(state.destination.?, pose.position)) < definition.walk_speed * 0.2)) {
        state.destination = try @import("../../../../mechanics/server/actor_wander.zig").next(&actors.ground_routes, pose.*, state.start, definition, try world.get(entity, data.Random), .{ .body = (try world.get(entity, data.Body)).*, .slot = (try world.get(entity, data.Binding)).slot });
        if (state.destination) |destination| state.wander_until_ms = now + @as(i64, @intFromFloat(v.length(v.subtract(destination, pose.position)) / definition.walk_speed * 1000)) + 1000;
    }
    if (state.destination) |destination| actor.threat_position = destination;
    actor.mode = if (state.destination == null) .idle else .chase;
}
pub fn move(actors: *Actors, actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, slot: u16, elapsed: u32, now: i64, slow: f32) !void {
    const definition = actors.table.definitions[actor.definition];
    if (actor.mode != .chase) velocity.linear = @splat(0) else if (now >= (actor.fish.motion_ms orelse now)) {
        actor.fish.motion_ms = now + 100;
        var goal = actor.threat_position;
        if (try @import("../../../../mechanics/server/actor_collision.zig").service().contents(goal, slot) & c.MASK_WATER == 0) goal[2] = pose.position[2];
        if (try actors.ground_routes.nextWater(pose.position, goal, body.*, slot)) |destination| {
            const speed = (if (actor.fish.aggressive) definition.speed else definition.walk_speed * 2) * slow;
            @import("../../../../mechanics/server/actor_flight.zig").steer(pose, velocity, destination, speed, catalog.fish.turn(v.length(velocity.linear)));
            pose.angles[2] = 0; // Swimmers never bank.
        } else velocity.linear = @splat(0);
    }
    velocity.linear = catalog.fish.surface(velocity.linear, try @import("../../../../mechanics/server/actor_water.zig").level(pose.position, body.*, slot));
    try @import("../../../../mechanics/server/actor_flight.zig").move(pose, body.*, velocity, slot, elapsed);
    body.grounded = false;
    actor.ground_entity = c.ENTITYNUM_NONE;
}
