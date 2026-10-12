// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: stavros. Server adapter: growing meteors and their fragments.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("stavros.zig");
pub const description = @import("weapon_catalog").classes.stavros;
pub fn fire(fired: *context.Fire) !void {
    try engine.launch(fired.world, fired.slots, fired.projections, fired.owner, fired.shot, fired.table, fired.now);
}
/// Meteors grow from their launch point; fragments draw differently and keep their own bounds.
pub fn decorateProjectile(projection: *context.Projection) !void {
    const meteor = projection.projectile.flight.stavros;
    projection.state.generic1 |= @as(i32, @intFromBool(meteor.fragment)) << 3;
    projection.state.angles2 = meteor.scale;
    projection.state.origin2 = projection.projectile.launch_position;
    projection.shared.mins = meteor.mins();
    projection.shared.maxs = meteor.maxs();
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
