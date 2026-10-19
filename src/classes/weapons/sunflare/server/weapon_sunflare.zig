// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: sunflare. Server adapter: thrown pots that become fires.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("sunflare.zig");
pub const description = @import("weapon_catalog").classes.sunflare;
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
