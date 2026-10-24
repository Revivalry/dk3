// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: scenery. Authored episode decorations: collision, animation, breakage and moving debris.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const policy = @import("../domain/scenery.zig");
const Material = @import("../../../../mechanics/domain/props.zig").Material;
const props = @import("../../../../mechanics/server/props.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const engine = @import("../../../../engine/server.zig");
const c = abi.c;
const Slots = @import("../../../../engine/slots.zig").Slots;
const prop = @import("../../../../mechanics/server/properties.zig");
const v = @import("../../../../core/domain/vector.zig");

pub fn spawn(allocator: std.mem.Allocator, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, now: i64) !void {
    var tables: [4]?[]const u8 = @splat(null);
    var entities: [ecs.max_entities]ecs.Entity = undefined;
    var count: usize = 0;
    {
        var query = world.queryAccess(data.World.mask(.{data.MapObject}), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, object| if (policy.owns(object.classname)) {
            entities[count] = entity;
            count += 1;
        };
    }
    for (entities[0..count]) |entity| {
        const object = (try world.get(entity, data.MapObject)).*;
        const episode = object.classname[6] - '1';
        if (tables[episode] == null) {
            var path: [64]u8 = undefined;
            tables[episode] = try @import("../../../../engine/files.zig").read(.server, &engine.gateway, allocator, try std.fmt.bufPrintZ(&path, "dk3/tables/e{d}decoinfo.cfg", .{episode + 1}), 4 * 1024 * 1024);
        }
        const definition = try policy.find(tables[episode].?, object.model) orelse {
            var warning: [256]u8 = undefined;
            engine.print(try std.fmt.bufPrintZ(&warning, "dk3 scenery: omitted decoration class={s} model={s}; no definition in e{d}decoinfo\n", .{ object.classname, object.model, episode + 1 }));
            continue;
        };
        const material: Material = if (object.flags & 8 != 0) .wood else if (object.flags & 16 != 0) .metal else if (object.flags & 32 != 0) .glass else if (object.flags & 64 != 0) .flesh else definition.material;
        const scale = try prop.number(object, "scale", 1);
        var state: data.Scenery = .{
            .model = definition.model,
            .movement = definition.movement,
            .material = material,
            .started_ms = now,
            .scale = @splat(if (scale < 0.01) 1 else scale),
            .breakable = object.flags & 2 == 0 and (material != .unbreakable or definition.exploding or object.flags & 1 != 0),
            .explosive = object.flags & 1 != 0,
            .damage = @max(0, try prop.number(object, "damage", 25)),
            .alpha = if (object.flags & 256 != 0) std.math.clamp(try prop.number(object, "alpha", 1), 0, 1) else 1,
            .spin = .{ try prop.number(object, "y_speed", 0), try prop.number(object, "z_speed", 0), try prop.number(object, "x_speed", 0) },
        };
        const sequence: usize = @intFromFloat(std.math.clamp(try prop.number(object, "animseq", 0), 0, 4));
        if (definition.count > sequence) {
            state.sequence = definition.sequences[sequence].frames;
            state.looping = definition.sequences[sequence].looping;
        } else if (definition.count == 0) state.sequence = .{ .last = @intFromFloat(std.math.clamp(try prop.number(object, "frame", 0), 0, 65535)), .fps = 20 };
        var body: data.Body = .{
            .mins = @splat(std.math.inf(f32)),
            .maxs = @splat(-std.math.inf(f32)),
            .contents = if (definition.solid) c.CONTENTS_SOLID else 0,
            .collision_mask = c.MASK_PLAYERSOLID,
            .mass = @max(1, try prop.number(object, "mass", definition.mass)),
        };
        const angles = (try world.get(entity, data.Transform)).angles;
        for (0..8) |corner| {
            const point = @import("../../../../mechanics/domain/poses.zig").rotate(.{ if (corner & 1 == 0) definition.mins[0] else definition.maxs[0], if (corner & 2 == 0) definition.mins[1] else definition.maxs[1], if (corner & 4 == 0) definition.mins[2] else definition.maxs[2] }, @splat(0), angles);
            for (point, 0..) |value, axis| {
                body.mins[axis] = @min(body.mins[axis], value);
                body.maxs[axis] = @max(body.maxs[axis], value);
            }
        }
        try world.put(entity, state);
        try world.put(entity, body);
        try world.put(entity, data.Velocity{});
        try world.put(entity, data.Random{ .state = try world.persistentId(entity) });
        if (state.breakable) {
            const health: i32 = @intFromFloat(@max(1, try prop.number(object, "health", @floatFromInt(definition.health))));
            try world.put(entity, data.Health{ .current = health, .maximum = health });
            try world.put(entity, data.Hurt{});
        }
        try @import("../../../../mechanics/server/weapon_entities.zig").bind(world, slots, projections, entity, state.model);
        try props.publish(world, entity, projections, now);
    }
}

fn fragments(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, now: i64) !void {
    const state = (try world.get(entity, data.Scenery)).*;
    if (state.material == .unbreakable) return;
    const pose = (try world.get(entity, data.Transform)).*;
    const body = (try world.get(entity, data.Body)).*;
    var random = (try world.get(entity, data.Random)).*;
    const sizes = v.subtract(body.maxs, body.mins);
    const flesh = state.material == .flesh;
    const large: usize = if (flesh) @intFromFloat(@min(6, body.mass / 100)) else if (body.mass >= 400) @intFromFloat(@min(7, body.mass / 100)) else 0;
    const small: usize = if (flesh) 0 else @intFromFloat(@min(16, body.mass / 30));
    for (0..large + small) |index| {
        const big = index < large;
        var path: [64]u8 = undefined;
        const model = if (flesh) ([_][]const u8{ "models/global/e_gibtorso.dkm", "models/global/e_gibleg.dkm", "models/global/e_gibfoot.dkm", "models/global/e_gibhand.dkm", "models/global/e_gibhead.dkm", "models/global/e_gibchest.dkm" })[index] else try std.fmt.bufPrint(&path, "models/global/e_{s}{d}.dkm", .{ switch (state.material) {
            .wood => "wood",
            .metal => "metal",
            .glass => "glass",
            else => unreachable,
        }, if (big) @as(u8, 1) else 2 });
        // Registry owns its copy; dynamic state uses a stable model name below.
        const model_index = try @import("../../../../mechanics/server/resources.zig").model(model);
        const model_name = @import("../../../../mechanics/server/resources.zig").modelName(model_index);
        var origin = pose.position;
        var scale: v.Vec3 = undefined;
        var direction: v.Vec3 = undefined;
        var spin: v.Vec3 = undefined;
        for (0..3) |axis| {
            origin[axis] += (random.next() - 0.5) * sizes[axis] * 0.5;
            scale[axis] = if (flesh) 1 else if (big) 1 + random.next() * 2 else 0.5 + random.next();
            direction[axis] = random.next() * 2 - 1;
            spin[axis] = random.next() * 600;
        }
        var velocity = v.scale(v.normalize(direction), if (big) 250 else 350);
        for (&velocity) |*value| value.* += (random.next() - 0.5) * 100;
        velocity[2] += 100;
        const fragment = try world.create(null, .{ data.Transform{ .position = origin }, data.Velocity{ .linear = velocity }, data.Body{ .mins = @splat(0), .maxs = @splat(0), .collision_mask = c.MASK_SOLID }, data.Scenery{
            .model = model_name,
            .movement = .bounce,
            .started_ms = now,
            .scale = scale,
            .spin = spin,
            .alpha = if (state.material == .glass) 0.75 else 1,
            .fragment = true,
            .expires_ms = now + 5000 + @as(i64, @intFromFloat(random.next() * 5000)),
        } });
        try @import("../../../../mechanics/server/weapon_entities.zig").bind(world, slots, projections, fragment, model_name);
        try props.publish(world, fragment, projections, now);
    }
    var sound: [64]u8 = undefined;
    const path = if (flesh) try std.fmt.bufPrint(&sound, "global/m_gibslop{c}.wav", .{@as(u8, 'a') + @as(u8, @intFromFloat(random.next() * 4))}) else try std.fmt.bufPrint(&sound, "global/e_{s}breaks{c}.wav", .{ switch (state.material) {
        .wood => "wood",
        .metal => "metal",
        .glass => "glass",
        else => unreachable,
    }, @as(u8, 'a') + @as(u8, @intFromFloat(random.next() * 5)) });
    try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, path, pose.position, c.ENTITYNUM_NONE, c.CHAN_AUTO, now);
    (try world.get(entity, data.Random)).* = random;
}

fn destroy(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *@import("../../../../mechanics/server/targets.zig").Router, entity: ecs.Entity, now: i64) !void {
    const state = (try world.get(entity, data.Scenery)).*;
    const pose = (try world.get(entity, data.Transform)).*;
    const attacker = (try world.get(entity, data.Hurt)).source;
    const binding = (try world.get(entity, data.Binding)).*;
    (try world.get(entity, data.Body)).contents = 0;
    projections[binding.slot].shared.contents = 0;
    engine.link(&projections[binding.slot]);
    if (state.explosive) {
        try @import("../../../../mechanics/server/area_damage.zig").apply(world, slots, .{ .owner = attacker, .weapon = 0, .origin = pose.position, .damage = state.damage, .radius = 100, .skip_slot = binding.slot, .self_scale = 1 }, now);
        try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, "global/e_explode1.wav", pose.position, c.ENTITYNUM_NONE, c.CHAN_AUTO, now);
        try props.explosion(world, slots, projections, pose.position, 1, now);
    }
    try fragments(world, slots, projections, entity, now);
    // Capture the drop before targets can delete the decoration itself.
    const spawnname = prop.text((try world.get(entity, data.MapObject)).*, "spawnname") orelse "";
    if (spawnname.len > 0) {
        const actors = router.actors orelse return error.MissingActorDefinitions;
        if (@import("actor_catalog").find(spawnname) != null) _ = try actors.spawnDynamic(world, slots, projections, spawnname, pose.position, pose.angles, now) else if (std.mem.startsWith(u8, spawnname, "monster_")) return error.UnknownActorClass else _ = try @import("../../../../mechanics/server/items.zig").spawnDynamic(world, slots, projections, spawnname, pose, now, actors.episode);
    }
    (try world.get(entity, data.Scenery)).broken = true;
    try props.publish(world, entity, projections, now);
    // Keep an inert source identity for delayed targets and visited-world restoration.
    try router.fire(world, slots, projections, entity, attacker, now);
}

/// World-system hooks (world_system_classes.zig).
pub fn worldSpawn(spawning: *const @import("../../../../mechanics/server/system_context.zig").Spawn) !void {
    try spawn(spawning.allocator, spawning.world, spawning.slots, spawning.projections, spawning.now);
}
/// Prop role (prop_classes.zig): a damaged breakable decoration breaks after a short delay.
pub fn propTick(tick: *props.Tick, state: *data.Scenery) !bool {
    if (!state.breakable or (try tick.world.get(tick.entity, data.Health)).current > 0) return false;
    if (state.breaking_ms == null) state.breaking_ms = tick.now + 100 + @as(i64, @intFromFloat((try tick.world.get(tick.entity, data.Random)).next() * 4)) * 100;
    if (tick.now < state.breaking_ms.?) return false;
    try destroy(tick.world, tick.slots, tick.projections, tick.router, tick.entity, tick.now);
    return true;
}
