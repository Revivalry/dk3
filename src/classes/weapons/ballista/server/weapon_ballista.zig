// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: ballista. Server adapter: bolts that carry their victims.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("ballista.zig");
pub const description = @import("weapon_catalog").classes.ballista;
pub fn prepareFlight(flight: *context.Flight) void {
    flight.projectile.flight.ballista.velocity = flight.velocity;
    flight.projectile.flight.ballista.previous_position = flight.start;
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
