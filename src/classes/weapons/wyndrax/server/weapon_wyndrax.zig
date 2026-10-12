// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: wyndrax. Server adapter: wisps that seek targets.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("wyndrax.zig");
pub const description = @import("weapon_catalog").classes.wyndrax;
pub fn launch(fired: *context.Fire) !void {
    try engine.launch(fired.world, fired.slots, fired.projections, fired.owner, fired.shot, fired.table, fired.now);
}
pub fn decorateProjectile(projection: *context.Projection) !void {
    engine.project(projection.world, projection.projectile.flight.wyndrax, projection.state);
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
/// A wisp names its targets' slots.
pub const missile_links: context.Links = .{ .other = true, .other2 = true, .origin2 = true };
pub fn linked(projectile: *const data.Projectile, _: bool, _: i64) ?context.Linked {
    return .{ .targets = projectile.flight.wyndrax.targets };
}
