// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: hammer. Server adapter: delayed strikes; the strike plays its own sound.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("hammer.zig");
pub const description = @import("weapon_catalog").classes.hammer;
/// The strike plays its sound when it lands.
pub const fire_sound = false;
pub fn fire(fired: *context.Fire) !void {
    try engine.launch(fired.world, fired.owner, fired.shot, fired.table, fired.now);
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
/// The player swinging, until the quake it raised outlives the swing.
pub fn actionOwner(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity) ?u32 {
    const hammer = world.get(entity, data.Hammer) catch return null;
    return if (hammer.quake_until_ms == null) hammer.owner else null;
}
/// Prints this class's entity state for `dk3_runtime_area_weapons` (combat_probe.zig).
pub fn probeArea(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, now: i64) !void {
    const engine_print = @import("../../../../engine/server.zig").print;
    var output: [300]u8 = undefined;
    if (world.get(entity, data.Hammer) catch null) |hammer| {
        engine_print(try @import("std").fmt.bufPrintZ(&output, "dk3 zig hammer state: id={d} charge={d} next={d} quake_remaining={d}\n", .{ try world.persistentId(entity), hammer.charge_ms, hammer.next_ms - now, if (hammer.quake_until_ms) |at| at - now else 0 }));
    }
}
