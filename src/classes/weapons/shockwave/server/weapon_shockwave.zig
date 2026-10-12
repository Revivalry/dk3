// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: shockwave. Server adapter: the orb and its rings.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("shockwave.zig");
pub const description = @import("weapon_catalog").classes.shockwave;
/// Rings start where the orb was launched.
pub fn prepareFlight(flight: *context.Flight) void {
    flight.projectile.flight.shockwave.last_ring = flight.start;
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
/// The sphere bounces about and bursts into rings running 350 out for seconds (it splashes 300
/// round each wall it bounces off): in halls and rooms they come back on the party.
pub const lingering: context.Lingering = .{ .clear = 420, .hold = 500 };
pub fn lingersOn(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity) bool {
    if ((world.get(entity, data.Shockwave) catch null) != null) return true;
    return if (world.get(entity, data.Projectile) catch null) |projectile| projectile.weapon == description.id else false;
}
/// Prints this class's entity state for `dk3_runtime_area_weapons` (combat_probe.zig).
pub fn probeArea(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, now: i64) !void {
    const engine_print = @import("../../../../engine/server.zig").print;
    var output: [300]u8 = undefined;
    const pose = (world.get(entity, data.Transform) catch return).*;
    if (world.get(entity, data.Shockwave) catch null) |wave| {
        engine_print(try @import("std").fmt.bufPrintZ(&output, "dk3 zig shockwave state: id={d} age={d} rings={d} next={d} inner={d:.2} outer={d:.2} position={d:.2},{d:.2},{d:.2}\n", .{ try world.persistentId(entity), now - wave.born_ms, wave.count, wave.next_ms - now, wave.rings[wave.count - 1].inner, wave.rings[wave.count - 1].outer, pose.position[0], pose.position[1], pose.position[2] }));
    }
}
