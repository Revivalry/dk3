// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: metamaser. Server adapter: thrown cubes, their locks and bursts.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("metamaser.zig");
pub const description = @import("weapon_catalog").classes.metamaser;
pub fn launch(fired: *context.Fire) !void {
    try engine.launch(fired.world, fired.slots, fired.projections, fired.owner, fired.shot, fired.table, fired.now);
}
/// Cubes publish their own projection.
pub fn publishProjectile(projection: *context.Projection) !bool {
    try engine.publish(projection.world, projection.entity, projection.projections, projection.now);
    return true;
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
/// A tracking cube names the slots of its locks once its pause is over.
pub const missile_links: context.Links = .{ .other = true, .other2 = true, .origin2 = true };
pub fn linked(projectile: *const data.Projectile, _: bool, now: i64) ?context.Linked {
    const cube = projectile.flight.metamaser;
    var targets: [4]u32 = @splat(0);
    if (cube.phase == .tracking and now >= projectile.born_ms + cube.pause_ms) for (cube.acquired, &targets) |lock, *target| {
        target.* = lock.target;
    };
    return .{ .targets = targets };
}
/// The cube's death ring and lasers name their player's slot.
pub fn effectOwner(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity) ?u32 {
    if (world.get(entity, data.MetaRing) catch null) |ring| return ring.owner;
    return if (world.get(entity, data.MetaLaser) catch null) |laser| laser.owner else null;
}
