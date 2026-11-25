// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: ballista. Warn travellers about a pinned bolt's delayed explosion.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const v = @import("../../../../core/domain/vector.zig");
const W = @import("weapon_catalog").classes.ballista;

pub const hazard = data.Projectile;
pub fn forecast(world: *data.World, entity: ecs.Entity, now: i64) !?struct { eta: f32, point: v.Vec3, radius: f32, field: bool } {
    const projectile = try world.get(entity, data.Projectile);
    if (projectile.flight != .ballista or !projectile.stuck) return null;
    const expires = (try world.get(entity, data.Lifetime)).expires_ms;
    // A stuck bolt remains dangerous until its entity is removed, including
    // the update on which its timer expires. Its owner must avoid it too.
    return .{
        .eta = @min(2.5, @as(f32, @floatFromInt(@max(0, expires - now))) * 0.001),
        .point = (try world.get(entity, data.Transform)).position,
        .radius = W.spec.projectile.splash_radius,
        .field = true,
    };
}

test "pinned bolts expose their delayed blast, including their expiry update" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    const entity = try world.create(1, .{
        data.Projectile{ .owner = 2, .weapon = W.id, .damage = 10, .born_ms = 100, .stepped_ms = 100, .stuck = true, .flight = .{ .ballista = .{} } },
        data.Transform{ .position = .{ 12, 24, 36 } },
        data.Lifetime{ .expires_ms = 2100 },
    });
    const active = (try forecast(&world, entity, 100)).?;
    try std.testing.expect(active.field);
    try std.testing.expectEqual(@as(f32, 2), active.eta);
    try std.testing.expectEqual(W.spec.projectile.splash_radius, active.radius);
    try std.testing.expectEqual(v.Vec3{ 12, 24, 36 }, active.point);
    try std.testing.expectEqual(@as(f32, 0), (try forecast(&world, entity, 2100)).?.eta);
    (try world.get(entity, data.Projectile)).stuck = false;
    try std.testing.expect(try forecast(&world, entity, 100) == null);
}
