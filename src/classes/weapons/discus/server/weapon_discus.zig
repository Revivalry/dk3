// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: discus. Server adapter: returning discs and their pickup.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("discus.zig");
pub const description = @import("weapon_catalog").classes.discus;
/// The disc bounces with its own random stream.
pub const seeded = true;
pub fn prepareFlight(flight: *context.Flight) void {
    const disc = &flight.projectile.flight.discus;
    disc.forward = v.normalize(flight.velocity);
    disc.base_speed = flight.speed;
    disc.speed = flight.speed;
}
/// A disc waiting to be picked up shows its resting frame.
pub fn decorateProjectile(projection: *context.Projection) !void {
    projection.state.frame = if (projection.projectile.flight.discus.pickup_only) 1 else 0;
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.table, stepping.now);
}
