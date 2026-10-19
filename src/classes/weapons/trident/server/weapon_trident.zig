// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: trident. Server adapter: linked tips, charge and wetness.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("trident.zig");
pub const description = @import("weapon_catalog").classes.trident;
pub fn fire(fired: *context.Fire) !void {
    try engine.launch(fired.world, fired.slots, fired.projections, fired.owner, fired.shot, fired.table, fired.now);
}
/// Charged and wet tips draw differently.
pub fn decorateProjectile(projection: *context.Projection) !void {
    projection.state.generic1 |= @as(i32, @intFromBool(projection.projectile.flight.trident.charged)) << 3;
    projection.state.generic1 |= @as(i32, @intFromBool(projection.projectile.wet)) << 4;
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
