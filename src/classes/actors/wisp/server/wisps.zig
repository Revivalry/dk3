// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: wisp. Authored Wisp clusters and the collection handshake used by Wyndrax.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const c = abi.c;
const Slots = @import("../../../../engine/slots.zig").Slots;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const policy = @import("actor_catalog").wisp;
const swarms = @import("actor_catalog").energy_swarm;
const collection = @import("../../../../mechanics/server/energy_swarms.zig");
pub fn spawn(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, now: i64) !void {
    var sources: [ecs.max_entities]ecs.Entity = undefined;
    var count: usize = 0;
    {
        var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Transform }), data.World.mask(.{data.WispSwarm}), 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, object| if (std.mem.eql(u8, object.classname, policy.classname)) {
            sources[count] = entity;
            count += 1;
        };
    }
    for (sources[0..count]) |source| try spawnOne(world, slots, projections, source, now);
}
pub fn spawnOne(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, source: ecs.Entity, now: i64) !void {
    const object = (try world.get(source, data.MapObject)).*;
    const pose = (try world.get(source, data.Transform)).*;
    const id = try world.persistentId(source);
    var random: data.Random = .{ .state = id };
    var swarm: data.WispSwarm = .{ .count = @intFromFloat(std.math.clamp(@trunc(try prop.number(object, "count", 3)), 1, 10)), .next_ms = now + 1000, .sound_ms = now + 2500 + @as(i64, @intFromFloat(random.next() * 1750)) };
    const scale = try prop.number(object, "scale", 1);
    if (scale < 0 or scale > 10000) return error.InvalidWispScale;
    const alpha = if (prop.text(object, "alpha_level") != null) @max(0.01, @trunc(try prop.number(object, "alpha_level", 35)) / 100) else 0.35;
    const delta_alpha = @max(0, @trunc(try prop.number(object, "delta_alpha", 0)) / 100);
    if (alpha > 1 or delta_alpha > 1) return error.InvalidWispAlpha;
    for (0..swarm.count) |i| {
        const personality = @max(0.25, random.next());
        const state: data.Firefly = .{
            .source = id,
            .shape = 0,
            .wisp = .{ .goal = pose.position, .blend_after = @intFromFloat(personality * 5) },
            .distance = std.math.clamp(@trunc(try prop.number(object, "distance", 75)), 20, 200),
            .speed = std.math.clamp(@trunc(try prop.number(object, "velocity", 35)), 1, 500),
            .scale = if (scale == 0) 1 else scale,
            .alpha = alpha,
            .maximum_alpha = alpha,
            .delta_alpha = delta_alpha,
            .color = @splat(1),
            .displayed_color = @splat(1),
            .personality = personality,
            .next_ms = now + 300 + @as(i64, @intFromFloat(random.next() * 500)),
            .previous = pose.position,
        };
        // The source initializes random offsets then SetOrigin2 resets them to
        // the emitter origin; every particle starts at that final authored point.
        const fly = try world.create(null, .{ pose, state, data.Random{ .state = random.state }, data.Velocity{}, data.Body{ .mins = @splat(-1), .maxs = @splat(1), .collision_mask = c.MASK_SOLID | c.CONTENTS_PLAYERCLIP } });
        swarm.children[i] = try world.persistentId(fly);
        try @import("../../../../mechanics/server/weapon_entities.zig").bind(world, slots, projections, fly, swarms.model);
        try @import("../../../../mechanics/server/glow_particles.zig").publish(world, fly, projections);
    }
    try world.put(source, swarm);
    try world.put(source, random);
}
pub fn step(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, now: i64, elapsed: u32) !void {
    var sources: [ecs.max_entities]ecs.Entity = undefined;
    var count: usize = 0;
    {
        var query = world.queryAccess(data.World.mask(.{data.WispSwarm}), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities()) |entity| {
            sources[count] = entity;
            count += 1;
        };
    }
    // The swarm's particles move every frame.
    for (sources[0..count]) |source| {
        const children = (try world.get(source, data.WispSwarm)).children;
        const total = (try world.get(source, data.WispSwarm)).count;
        for (children[0..total]) |id| {
            const fly = world.find(id) orelse continue;
            const state = world.get(fly, data.Firefly) catch continue;
            if (state.wisp == null) continue;
            try particle(world, fly, source, state, try world.get(fly, data.Transform), try world.get(fly, data.Velocity), try world.get(fly, data.Random), now, elapsed);
            try @import("../../../../mechanics/server/glow_particles.zig").publish(world, fly, projections);
        }
    }
    for (sources[0..count]) |source| {
        // Event creation can move ECS storage. Commit the local controller after
        // all event writes instead of retaining component pointers across them.
        var swarm = (try world.get(source, data.WispSwarm)).*;
        if (now < swarm.next_ms) continue;
        swarm.next_ms = now + 100;
        var random = (try world.get(source, data.Random)).*;
        const point = (try world.get(source, data.Transform)).position;
        const consumer = world.find(swarm.consumer);
        // Only a living consumer that named itself (`collect`) receives particles.
        const alive = if (consumer) |entity| (world.get(entity, data.Health) catch null) != null and (try world.get(entity, data.Health)).current > 0 else false;
        if (swarm.sending) |index| {
            if (world.find(swarm.children[index])) |child| {
                if ((try world.get(child, data.Firefly)).wisp.?.mode == .dormant) {
                    if (alive) {
                        swarm.delivered +|= 1;
                        try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, policy.delivery_sound, point, c.ENTITYNUM_NONE, c.CHAN_AUTO, now);
                    }
                    swarm.sending = null;
                }
            } else swarm.sending = null;
        } else if (alive) {
            swarm.goal = (try world.get(consumer.?, data.Transform)).position;
            for (swarm.children[0..swarm.count], 0..) |id, i| if (world.find(id)) |child| {
                const fly = try world.get(child, data.Firefly);
                if (fly.wisp.?.mode == .wander) {
                    fly.wisp.?.mode = .collect;
                    fly.wisp.?.new_goal = true;
                    swarm.sending = @intCast(i);
                    break;
                }
            };
        }
        if (collection.active(world, swarm) > 0 and now > swarm.sound_ms) {
            try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, "e3/e_wisploopa.wav", point, c.ENTITYNUM_NONE, c.CHAN_AUTO, now);
            swarm.sound_ms = now + 3500 + @as(i64, @intFromFloat(random.next() * 1750));
            if (random.next() > 0.65) {
                var path: [24]u8 = undefined;
                const name = try std.fmt.bufPrint(&path, "e3/lostsole{d}.wav", .{1 + @as(u8, @intFromFloat(random.next() * 5))});
                try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, name, point, c.ENTITYNUM_NONE, c.CHAN_AUTO, now);
            }
        }
        (try world.get(source, data.WispSwarm)).* = swarm;
        (try world.get(source, data.Random)).* = random;
    }
}
pub fn particle(world: *data.World, entity: ecs.Entity, source: ecs.Entity, state: *data.Firefly, pose: *data.Transform, velocity: *data.Velocity, random: *data.Random, now: i64, elapsed: u32) !void {
    const swarm = (try world.get(source, data.WispSwarm)).*;
    const home = (try world.get(source, data.Transform)).position;
    const wisp = &state.wisp.?;
    if (now >= state.next_ms) {
        state.next_ms = now + 100;
        velocity.linear = state.direction;
        if (std.mem.eql(f32, &state.previous, &pose.position)) wisp.blocked +|= 1;
        state.previous = pose.position;
        if (v.length(v.subtract(wisp.goal, pose.position)) >= state.distance + 100 or @as(f32, @floatFromInt(wisp.blocked)) >= 10 * state.personality or wisp.new_goal) {
            wisp.new_goal = false;
            away(state, pose, velocity, random, swarm.goal, home, now);
        }
        if (state.outward) away(state, pose, velocity, random, swarm.goal, home, now) else {
            if (wisp.mode != .dormant) oscillate(state, velocity, random);
            const distance: f32 = if (wisp.mode == .collect) 50 else 20;
            if (v.length(v.subtract(wisp.goal, pose.position)) <= distance) {
                state.outward = true;
                switch (wisp.mode) {
                    .wander => {
                        for (&state.direction) |*axis| axis.* = (random.next() * 2 - 1) * state.speed;
                        randomizePersonality(state, random);
                    },
                    .collect => {
                        wisp.collected_ms = now;
                        wisp.collected_at = pose.position;
                        state.alpha = 0;
                        pose.position = home;
                        velocity.linear = @splat(0);
                        wisp.mode = .dormant;
                        wisp.respawn_ms = now + 100000;
                    },
                    .dormant => {},
                }
            }
        }
    }
    try @import("../../../../mechanics/server/actor_flight.zig").move(pose, (try world.get(entity, data.Body)).*, velocity, (try world.get(entity, data.Binding)).slot, elapsed);
}
fn randomizePersonality(state: *data.Firefly, random: *data.Random) void {
    if (random.next() > 0.5) state.personality = @max(0.25, random.next());
}
fn away(state: *data.Firefly, pose: *data.Transform, velocity: *data.Velocity, random: *data.Random, destination: v.Vec3, home: v.Vec3, now: i64) void {
    const wisp = &state.wisp.?;
    switch (wisp.mode) {
        .wander => {
            oscillate(state, velocity, random);
            if (v.length(v.subtract(wisp.goal, pose.position)) < state.distance) return;
            state.direction = v.scale(v.normalize(v.subtract(wisp.goal, pose.position)), state.speed);
            state.outward = false;
            wisp.blocked = 0;
            randomizePersonality(state, random);
        },
        .collect => {
            wisp.goal = destination;
            state.direction = v.scale(v.normalize(v.subtract(destination, pose.position)), state.speed);
            state.outward = false;
            wisp.blocked = 0;
            randomizePersonality(state, random);
        },
        .dormant => {
            velocity.linear = @splat(0);
            state.alpha = 0;
            pose.position = home;
            if (now > wisp.respawn_ms) {
                state.alpha = state.maximum_alpha;
                wisp.mode = .wander;
                wisp.goal = home;
                state.outward = false;
            }
        },
    }
}
fn oscillate(state: *data.Firefly, velocity: *data.Velocity, random: *data.Random) void {
    const wisp = &state.wisp.?;
    wisp.alpha_count +|= 1;
    if (state.delta_alpha != 0 and wisp.alpha_count >= wisp.blend_after) {
        state.alpha += if (state.alpha_up) state.delta_alpha else -state.delta_alpha;
        if (state.alpha < 0.01 or state.alpha > state.maximum_alpha) {
            state.alpha_up = state.alpha < 0.01;
            wisp.blend_after = @intFromFloat(state.personality * 5);
        }
        wisp.alpha_count = 0;
    }
    const radians = (1 + @as(f32, @floatFromInt(state.phase)) * 30) * std.math.pi / 180;
    const sine = @round(@sin(radians) * 1000) / 1000;
    const cosine = @round(@cos(radians) * 1000) / 1000;
    const strength = state.speed / (2 * state.personality);
    if (random.next() > state.personality) velocity.linear[1] += cosine * strength else velocity.linear[0] += sine * strength;
    velocity.linear[2] += sine * strength;
    state.phase = if (state.phase == 11) 0 else state.phase + 1;
}

test "map spawning skips unrelated objects and already initialized wisp sources" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 2);
    defer world.deinit();
    _ = try world.create(1, .{ data.MapObject{ .classname = "info_player_start" }, data.Transform{} });
    const source = try world.create(2, .{ data.MapObject{ .classname = policy.classname }, data.Transform{}, data.WispSwarm{ .count = 1, .children = .{ 9, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, .next_ms = 100, .sound_ms = 200 } });
    var slots: Slots = .{};
    try spawn(&world, &slots, &.{}, 500);
    try t.expectEqual(@as(u32, 9), (try world.get(source, data.WispSwarm)).children[0]);
    try t.expectEqual(@as(i64, 100), (try world.get(source, data.WispSwarm)).next_ms);
    try t.expectEqual(@as(usize, 2), world.count());
}
/// World-system hooks (world_system_classes.zig).
pub fn worldSpawn(spawning: *const @import("../../../../mechanics/server/system_context.zig").Spawn) !void {
    try spawn(spawning.world, spawning.slots, spawning.projections, spawning.now);
}
pub fn worldStep(frame: *const @import("../../../../mechanics/server/system_context.zig").Step) !void {
    try step(frame.world, frame.slots, frame.projections, frame.now, frame.elapsed);
}
