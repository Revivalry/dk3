// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: explosive. Authored explosive brushes emit material chunks through the scenery lifecycle.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const c = abi.c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const policy = @import("../domain/explosives.zig");
pub fn burst(world: *data.World, slots: *@import("../../../../engine/slots.zig").Slots, projections: []abi.EntityProjection, entity: ecs.Entity, center: v.Vec3, extent: v.Vec3, now: i64) !void {
    const object = (try world.get(entity, data.MapObject)).*;
    const material = policy.material(object.flags);
    var random: data.Random = .{ .state = (try world.persistentId(entity)) *% 1664525 +% @as(u32, @truncate(@as(u64, @bitCast(now)))) };
    const count = if (object.flags & 64 != 0) 0 else policy.count(try prop.number(object, "count", 10), try prop.number(object, "rndcount", 0), random.next());
    const speed = try prop.number(object, "speed", 1);
    const scale = 1.5 * try prop.number(object, "scale", 1);
    const gravity = 800 * try prop.number(object, "gravity", 1);
    var toward: ?v.Vec3 = null;
    if (prop.text(object, "vectortarget")) |name| {
        var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Transform }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.read(data.MapObject), view.read(data.Transform)) |candidate, pose| {
            if (std.ascii.eqlIgnoreCase(candidate.targetname, name)) toward = v.subtract(pose.position, center);
        };
    }
    for (0..count) |_| {
        const sample = @max(0.1, random.next());
        const size = scale * sample;
        const direction: v.Vec3 = if (toward) |delta| v.basis(.{ -std.math.atan2(delta[2], @sqrt(delta[0] * delta[0] + delta[1] * delta[1])) * 180 / std.math.pi + (random.next() * 2 - 1) * 15, std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi + (random.next() * 2 - 1) * 50, 0 }).forward else .{ random.next() * 2 - 1, random.next() * 2 - 1, 1 };
        const model = policy.model(material, random.next() <= 0.5);
        const chunk = try world.create(null, .{
            data.Transform{ .position = v.add(center, v.scale(extent, sample * (if (toward != null) @as(f32, 0.1) else 0.3))), .angles = .{ 0, 0, 180 * random.next() } },
            data.Velocity{ .linear = v.scale(direction, 350 * speed) },
            data.Body{ .mins = @splat(0), .maxs = @splat(0), .mass = 25 * size, .collision_mask = c.MASK_SOLID },
            data.Gravity{ .acceleration = gravity },
            data.Scenery{ .model = model, .movement = .bounce, .started_ms = now, .scale = @splat(size), .spin = .{ (25 * size + 5) * 100, 0, (25 * size + 5) * 100 }, .alpha = if (material == .glass) 0.55 else 1, .fragment = true, .explosive_fragment = true, .expires_ms = now + 6000 },
        });
        try @import("../../../../mechanics/server/weapon_entities.zig").bind(world, slots, projections, chunk, model);
        try @import("../../../../mechanics/server/props.zig").publish(world, chunk, projections, now);
    }
    if (object.flags & 256 == 0) {
        try @import("../../../../mechanics/server/props.zig").explosionVariant(world, slots, projections, center, 1, false, now);
        if (count > 0) try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, "global/e_explodeb.wav", center, c.ENTITYNUM_WORLD, c.CHAN_AUTO, now);
    }
    if (object.flags & 128 == 0 and count > 0) {
        var name: [80]u8 = undefined;
        const sound = if (material == .stone) try std.fmt.bufPrint(&name, "global/e_rocktumble{d}.wav", .{1 + @as(u32, @intFromFloat(random.next() * 4))}) else try std.fmt.bufPrint(&name, "global/e_{s}breaks{c}.wav", .{ @tagName(material), @as(u8, 'a') + @as(u8, @intFromFloat(random.next() * 5)) });
        try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, sound, center, c.ENTITYNUM_WORLD, c.CHAN_AUTO, now);
    }
    var message: [128]u8 = undefined;
    @import("../../../../engine/server.zig").print(try std.fmt.bufPrintZ(&message, "dk3 explosive: target={s} material={s} chunks={d}\n", .{ object.targetname, @tagName(material), count }));
}
/// Prop role (prop_classes.zig): explosive chunks stop spinning, then fade.
pub fn propTick(tick: *@import("../../../../mechanics/server/props.zig").Tick, state: *data.Scenery) !bool {
    if (!state.explosive_fragment) return false;
    if (tick.now >= state.started_ms + 550) state.spin = @splat(0);
    if (tick.now >= state.started_ms + 5000) state.alpha = @max(0, state.alpha - @as(f32, @floatFromInt(tick.elapsed)) * 0.001);
    return false;
}
/// Breakable brush role (destructible_classes.zig): used, a hidden brush appears; otherwise it
/// breaks into chunks, hurts what stands near and fires its targets.
pub fn destructibleUse(destructing: *const @import("../../../../mechanics/server/world_actions.zig").Destructing) !bool {
    const world = destructing.world;
    const slots = destructing.slots;
    const projections = destructing.projections;
    const router = destructing.router;
    const entity = destructing.entity;
    const activator = destructing.activator;
    const now = destructing.now;
    const value = try world.get(entity, data.Destructible);
    const state = value.*;
    const publishVolume = @import("../../../../mechanics/server/world_actions.zig").publishVolume;
    const engine = @import("../../../../engine/server.zig");
    if (state.broken) return true;
    if (state.hidden) {
        value.hidden = false;
        try publishVolume(world, entity, projections, true, if (state.nonsolid) 0 else c.CONTENTS_SOLID);
        return true;
    }
    value.broken = true;
    (try world.get(entity, data.Health)).current = 0;
    const slot = (try world.get(entity, data.Binding)).slot;
    const center = v.scale(v.add(projections[slot].shared.absmin, projections[slot].shared.absmax), 0.5);
    const extent = v.subtract(projections[slot].shared.absmax, projections[slot].shared.absmin);
    try publishVolume(world, entity, projections, false, 0);
    try burst(world, slots, projections, entity, center, extent, now);
    if (state.damage > 0) {
        const occupants = slots.occupants;
        for (occupants, 0..) |occupant, target_slot| {
            const target = occupant orelse continue;
            if (target_slot == slot) continue;
            const health = world.get(target, data.Health) catch continue;
            if (health.current <= 0) continue;
            const position = (try world.get(target, data.Transform)).position;
            const distance = v.length(v.subtract(position, center));
            if (distance >= state.radius) continue;
            const hit = try engine.collisionService().trace(.{ .start = center, .end = position, .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = c.MASK_SOLID });
            if (hit.fraction < 1 and hit.entity != target_slot) continue;
            _ = try @import("../../../../mechanics/server/damage.zig").apply(world, target, @intFromFloat(@ceil(state.damage * (1 - distance / state.radius))), now, .{ .source = activator });
        }
    }
    try router.fire(world, slots, projections, entity, activator, now);
    return true;
}
/// A shot brush breaks as if used by its attacker.
pub fn destructibleStep(destructing: *const @import("../../../../mechanics/server/world_actions.zig").Destructing) !bool {
    const state = try destructing.world.get(destructing.entity, data.Destructible);
    if (!state.broken and !state.hidden and (try destructing.world.get(destructing.entity, data.Health)).current <= 0) {
        var breaking = destructing.*;
        breaking.activator = (try destructing.world.get(destructing.entity, data.Hurt)).source;
        _ = try @import("../../../../mechanics/server/world_actions.zig").activate(breaking.world, breaking.slots, breaking.projections, breaking.router, breaking.entity, breaking.activator, breaking.now);
    }
    return false;
}
