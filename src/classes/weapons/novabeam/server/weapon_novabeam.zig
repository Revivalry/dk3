// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: novabeam. Server adapter: timed discharge.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("novabeam.zig");
pub const description = @import("weapon_catalog").classes.novabeam;
pub fn fire(fired: *context.Fire) !void {
    try engine.launch(fired.world, fired.slots, fired.projections, fired.owner, fired.shot, fired.table, fired.now);
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
/// The player running a discharge.
pub fn actionOwner(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity) ?u32 {
    return if (world.get(entity, data.Nova) catch null) |nova| nova.owner else null;
}
/// The discharge effect names its player's slot.
pub const effectOwner = actionOwner;
/// Prints this class's entity state for `dk3_runtime_beams` (combat_probe.zig).
pub fn probeBeam(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, now: i64) !void {
    const engine_print = @import("../../../../engine/server.zig").print;
    var output: [300]u8 = undefined;
    if (world.get(entity, data.Nova) catch null) |beam| engine_print(try @import("std").fmt.bufPrintZ(&output, "dk3 zig nova state: id={d} phase={s} remaining={d:.3} next={d} expires={d}\n", .{ try world.persistentId(entity), @tagName(beam.phase), beam.remaining_damage, beam.next_ms - now, beam.expires_ms - now }));
}
