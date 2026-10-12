// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: flashlight. Server adapter: the light follows its holder.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("flashlight.zig");
pub const description = @import("weapon_catalog").classes.flashlight;
pub fn fire(fired: *context.Fire) !void {
    try engine.refresh(fired.world, fired.slots, fired.projections, fired.owner, fired.now);
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
/// The player holding a light.
pub fn actionOwner(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity) ?u32 {
    return if (world.get(entity, data.Flashlight) catch null) |light| light.owner else null;
}
/// The light effect names its player's slot.
pub const effectOwner = actionOwner;
/// Prints this class's entity state for `dk3_runtime_beams` (combat_probe.zig).
pub fn probeBeam(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, now: i64) !void {
    const engine_print = @import("../../../../engine/server.zig").print;
    var output: [300]u8 = undefined;
    if (world.get(entity, data.Flashlight) catch null) |light| engine_print(try @import("std").fmt.bufPrintZ(&output, "dk3 zig flashlight state: id={d} strength={d:.3} expires={d}\n", .{ try world.persistentId(entity), light.strength, light.expires_ms - now }));
}
