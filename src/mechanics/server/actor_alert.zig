// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: ally alerts. A monster that sights a new enemy, is hurt by one, keeps one in
//! sight while chasing, or dies passes that enemy to the monsters around it, as the reference's
//! enemy alerts do. Never names a class; every actor takes part.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const rules = @import("../domain/actors.zig");
const v = @import("../../core/domain/vector.zig");
const c = @import("../../engine/abi.zig").c;
const access = @import("region_access.zig");
const collision = @import("region_collision.zig");
const party = @import("../../game/server/session_classes.zig").party;

/// How far an actor's calls carry: its map `speak` key, else its aidata alert radius.
pub fn radius(world: *data.World, entity: ecs.Entity, definition: rules.Definition) !f32 {
    const object = (try world.get(entity, data.MapObject)).*;
    return @import("properties.zig").number(object, "speak", definition.speak_range);
}
/// Whether `enemy` can be called out: a living, visible player, party member or actor.
fn callable(world: *data.World, id: u32, now: i64) ?v.Vec3 {
    const target = access.find(world, id) orelse return null;
    if ((target.get(data.Health) catch return null).current <= 0) return null;
    if (target.get(data.Character) catch null) |character| if (character.invisible_until > now) return null;
    return (target.get(data.Transform) catch return null).position;
}
fn clear(from: v.Vec3, to: v.Vec3, mask: u32) !bool {
    const hit = try collision.trace(.{ .start = from, .end = to, .mins = @splat(0), .maxs = @splat(0), .slot = c.ENTITYNUM_NONE, .mask = mask });
    return hit.fraction >= 1 and !hit.start_solid;
}
/// The reference's enemy alert: monsters without an enemy, within the caller's radius of the
/// caller or of the enemy, that see the caller or see the enemy, take the enemy. (The reference
/// measures every listener against the caller's own radius.)
pub fn enemy(world: *data.World, caller: ecs.Entity, position: v.Vec3, reach: f32, enemy_id: u32, now: i64) !void {
    const spotted = callable(world, enemy_id, now) orelse return;
    var listeners: [ecs.max_entities]ecs.Entity = undefined;
    const count = gather(world, caller, &listeners);
    for (listeners[0..count]) |listener| {
        const actor = try world.get(listener, data.Actor);
        if (actor.threat != 0) continue;
        const at = (try world.get(listener, data.Transform)).position;
        if (v.length(v.subtract(at, position)) >= reach and v.length(v.subtract(at, spotted)) >= reach) continue;
        if (!try clear(position, at, c.MASK_OPAQUE) and !try clear(at, spotted, c.MASK_OPAQUE)) continue;
        take(actor, enemy_id, spotted);
    }
}
/// The reference's alert as a fight begins: monsters within their own radius of the caller, in
/// clear line of it and not ignoring players, take the enemy even if they had another.
pub fn nearby(world: *data.World, caller: ecs.Entity, position: v.Vec3, definitions: []const rules.Definition, enemy_id: u32, now: i64) !void {
    const spotted = callable(world, enemy_id, now) orelse return;
    var listeners: [ecs.max_entities]ecs.Entity = undefined;
    const count = gather(world, caller, &listeners);
    for (listeners[0..count]) |listener| {
        const actor = try world.get(listener, data.Actor);
        if (actor.ignore_player) continue;
        const at = (try world.get(listener, data.Transform)).position;
        if (v.length(v.subtract(at, position)) >= try radius(world, listener, definitions[actor.definition])) continue;
        if (!try clear(position, at, c.MASK_SOLID)) continue;
        take(actor, enemy_id, spotted);
    }
}
fn take(actor: *data.Actor, enemy_id: u32, spotted: v.Vec3) void {
    if (actor.threat == enemy_id) return;
    actor.threat = enemy_id;
    actor.threat_position = spotted;
}
/// Living monsters other than the caller: party members (sidekicks) are not monsters.
pub fn monster(world: *data.World, entity: ecs.Entity) bool {
    return !party.isMember(world, entity);
}
fn gather(world: *data.World, caller: ecs.Entity, out: []ecs.Entity) usize {
    var count: usize = 0;
    var query = world.queryAccess(data.World.mask(.{ data.Actor, data.Health, data.Transform, data.MapObject }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.Health)) |entity, health| {
        if (@as(u64, @bitCast(entity)) == @as(u64, @bitCast(caller)) or health.current <= 0 or !monster(world, entity)) continue;
        out[count] = entity;
        count += 1;
    };
    return count;
}
/// The chase repeats its alert during one second in every ten while the enemy is in sight.
pub fn chaseCall(now: i64) bool {
    return @mod(@divFloor(now, 1000), 10) == 0;
}

test "the chase alert sounds one second in ten" {
    try std.testing.expect(chaseCall(0) and chaseCall(999) and !chaseCall(1000) and chaseCall(10_500));
}
