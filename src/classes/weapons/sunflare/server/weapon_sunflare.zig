// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: sunflare. Server adapter: thrown pots that become fires.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("sunflare.zig");
pub const description = @import("weapon_catalog").classes.sunflare;
/// The owner can burn in its own oil. Automatic fallback must not throw a
/// persistent field into a narrow approach; named attacks retain their retreat.
pub const lingering: context.Lingering = .{ .clear = description.spec.projectile.splash_radius + 64, .hold = description.spec.projectile.splash_radius + 128 };
pub fn lingersOn(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity) bool {
    const projectile = world.get(entity, data.Projectile) catch return false;
    return projectile.flight == .sunflare and projectile.flight.sunflare.phase != .cooling;
}
test "a thrown or burning pot is lingering while a cooled pot is not" {
    const t = @import("std").testing;
    var world = data.World.init(t.allocator, 4);
    defer world.deinit();
    const entity = try world.create(1, .{data.Projectile{ .owner = 2, .weapon = description.id, .damage = 10, .born_ms = 0, .stepped_ms = 0, .flight = .{ .sunflare = .{} } }});
    try t.expect(lingersOn(&world, entity));
    (try world.get(entity, data.Projectile)).flight.sunflare.phase = .burning;
    try t.expect(lingersOn(&world, entity));
    (try world.get(entity, data.Projectile)).flight.sunflare.phase = .cooling;
    try t.expect(!lingersOn(&world, entity));
}
/// The pot tumbles and burns with its own random stream.
pub const seeded = true;
pub fn prepareFlight(flight: *context.Flight) void {
    var random: data.Random = .{ .state = flight.seed };
    for (&flight.projectile.flight.sunflare.angular_velocity) |*axis| axis.* = 90 + 60 * random.next();
}
/// Landed, the pot publishes as a fire.
pub fn publishProjectile(projection: *context.Projection) !bool {
    if (projection.projectile.flight.sunflare.phase == .flight) return false;
    try engine.publish(projection.world, projection.entity, projection.projections);
    return true;
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
/// A fire's effect names its owner.
pub fn linked(projectile: *const data.Projectile, effect: bool, _: i64) ?context.Linked {
    return if (effect) .{ .owner = projectile.owner } else null;
}
