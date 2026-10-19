// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: garroth. Garroth selects his authored punch, stave, NPC Wisp and Buboid summon.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const Ref = @import("../../../../mechanics/domain/world_references.zig").Ref;
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const c = abi.c;
const engine = @import("../../../../engine/server.zig");
const v = @import("../../../../core/domain/vector.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const policy = @import("actor_catalog").garroth;
const Definition = @import("../../../../mechanics/domain/actors.zig").Definition;
pub fn step(actors: *@import("../../../../mechanics/server/actors.zig").Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, navigation: @import("../../../../core/domain/navigation.zig").Service, now: i64, elapsed: u32, slow: f32) !void {
    const definition = actors.table.definitions[actor.definition];
    if (now >= actor.think_ms) {
        actor.think_ms = now + 100;
        try think(actors, world, slots, projections, entity, actor, pose, definition, now);
    }
    if (actor.mode != .chase) {
        velocity.linear[0] = 0;
        velocity.linear[1] = 0;
    }
    try @import("../../../../mechanics/server/actor_motion.zig").step(actor, pose, body, velocity, navigation, actor.threat_position, definition.speed * slow, (try world.get(entity, data.Binding)).slot, now, elapsed);
}
fn select(world: *data.World, entity: ecs.Entity, actor: *data.Actor, definition: Definition, distance: f32, facing: bool, now: i64) !void {
    const random = try world.get(entity, data.Random);
    const skill = engine.integer("g_spSkill");
    const chance = @import("actor_catalog").difficulty.pick(f32, skill, policy.attack_chance);
    actor.garroth.weapon = .none;
    if (facing) {
        if (distance < definition.range) actor.garroth.weapon = .punch else if (random.next() < chance) actor.garroth.weapon = policy.choose(distance, definition.range, definition.tuning(@import("actor_catalog").garroth).stave.range, definition.tuning(@import("actor_catalog").garroth).wisp.range, @intFromFloat(random.next() * 3));
    }
    actor.melee.begin(switch (actor.garroth.weapon) {
        .none => 2,
        .punch => 1,
        else => 0,
    }, now);
    actor.changed_ms = now;
    actor.mode = .attack;
}
fn think(actors: *@import("../../../../mechanics/server/actors.zig").Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, definition: Definition, now: i64) !void {
    const hurt = (try world.get(entity, data.Hurt)).*;
    const injured = hurt.revision != actor.receipt;
    const previous_threat = actor.threat;
    const sensed = try @import("../../../../mechanics/server/actor_perception.zig").perceive(world, slots, entity, actor, pose.*, definition, now);
    if (actor.reaction_until_ms) |until| if (now >= until) {
        actor.reaction = null;
        actor.reaction_until_ms = null;
    };
    // The reference's single pain roll (`hita`), never on the hit that makes a player its enemy.
    const pain = @import("../../../../mechanics/server/actor_pain.zig");
    if (injured and !pain.acquiring(world, hurt, previous_threat)) _ = try pain.direct(world, entity, actor, definition, hurt.amount, policy.pain_chance, now);
    if (actor.reaction_until_ms != null) {
        actor.mode = .idle;
        return;
    }
    const target = sensed.enemy orelse {
        actor.mode = .idle;
        actor.melee.active = false;
        return;
    };
    const delta = v.subtract((try target.get(data.Transform)).position, pose.position);
    const yaw = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
    pose.angles[1] += std.math.clamp(@mod(yaw - pose.angles[1] + 180, 360) - 180, -definition.yaw_speed, definition.yaw_speed);
    const facing = @abs(@mod(yaw - pose.angles[1] + 180, 360) - 180) < 5;
    if (!actor.melee.active) {
        if (!sensed.visible or !policy.inRange(sensed.distance, definition.range)) {
            actor.mode = .chase;
            return;
        }
        try select(world, entity, actor, definition, sensed.distance, facing, now);
    }
    actor.mode = .attack;
    const index = actor.melee.pose;
    const sequence = definition.attacks[index];
    try @import("../../../../mechanics/server/actor_attack_sounds.zig").emit(world, slots, projections, entity, actor, pose.position, definition, now);
    if (actor.garroth.weapon != .none) {
        const first = actor.melee.event(1, @divTrunc(@as(i64, definition.strikes[index]) * 1000, sequence.fps), now, false);
        const second = if (!first) if (definition.second_strikes[index]) |frame| actor.melee.event(2, @divTrunc(@as(i64, frame) * 1000, sequence.fps), now, false) else false else false;
        if (first or second) switch (actor.garroth.weapon) {
            .punch => try @import("../../../../mechanics/server/actor_melee.zig").punch(world, slots, entity, target, pose.*, definition, now),
            .stave => try @import("../../../../mechanics/server/meteors.zig").launch(world, slots, projections, entity, target, pose.*, definition.tuning(@import("actor_catalog").garroth).stave, now),
            .wisp => try @import("../../../../mechanics/server/wisp_lightning.zig").wisp(world, slots, projections, entity, target, pose.*, now),
            .summon => try summon(actors, world, slots, projections, target, now),
            .none => unreachable,
        };
    }
    if (now - actor.melee.started_ms >= sequence.lastFrameMs()) {
        if (!sensed.visible or sensed.distance > definition.attack_range) {
            actor.melee.active = false;
            actor.mode = .chase;
        } else try select(world, entity, actor, definition, sensed.distance, facing, now);
    }
}
fn summon(actors: *@import("../../../../mechanics/server/actors.zig").Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, target: Ref, now: i64) !void {
    if (target.world != world) {
        const context = @import("../../../../mechanics/server/region_access.zig").contextFor(target.world) orelse return error.SummonWorldUnavailable;
        const scope = try context.select();
        defer scope.deinit();
        try context.expose(now);
        try context.systems.actors.ensure(@import("actor_catalog").find("monster_buboid").?);
        return summon(&context.systems.actors, target.world, &context.slots, &context.projection, target, now);
    }
    const direction = try @import("../../../../mechanics/server/clear_direction.zig").choose(target.world, target.entity, c.MASK_SOLID);
    const enemy = (try target.get(data.Transform)).*;
    const point = v.add(enemy.position, v.scale(direction, 100));
    const definition = actors.table.definitions[@import("actor_catalog").find("monster_buboid").?];
    // Retain the authored location, but reject a full-hull obstruction instead
    // of creating a solid monster inside a mover or another character.
    const hit = try engine.collisionService().trace(.{ .start = point, .end = point, .mins = definition.mins, .maxs = definition.maxs, .slot = c.ENTITYNUM_NONE, .mask = c.MASK_PLAYERSOLID });
    if (hit.start_solid or hit.all_solid) return;
    const spawned = try actors.spawnDynamic(world, slots, projections, "monster_buboid", point, @splat(0), now);
    const actor = try world.get(spawned, data.Actor);
    actor.threat = try target.id();
    actor.threat_position = enemy.position;
    actor.ignore_player = false;
    // Dynamic authoring starts empty, so the summoner's death outputs are never inherited.
}
