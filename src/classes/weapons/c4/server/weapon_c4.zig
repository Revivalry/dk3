// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: c4. Server adapter: placed charges and their detonation chain.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("c4.zig");
pub const description = @import("weapon_catalog").classes.c4;
pub fn fire(fired: *context.Fire) !void {
    try engine.launch(fired.world, fired.slots, fired.projections, fired.owner, fired.shot, fired.table, fired.now);
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
/// C4 explosions schedule nearby charges explicitly; radius damage must not collapse the
/// staggered chain into simultaneous deaths.
pub fn admitsDamage(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, weapon: u5) bool {
    return weapon != description.id or (world.get(entity, data.Charge) catch null) == null;
}
/// "detonate" sets off the holder's charges.
pub fn command(commanding: *context.Command, name: []const u8) !bool {
    if (!@import("std").mem.eql(u8, name, "detonate")) return false;
    _ = try engine.detonate(commanding.world, try commanding.world.persistentId(commanding.holder), commanding.now, false);
    return true;
}
/// Prints this class's entity state for `dk3_runtime_area_weapons` (combat_probe.zig).
pub fn probeArea(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, now: i64) !void {
    const engine_print = @import("../../../../engine/server.zig").print;
    var output: [300]u8 = undefined;
    const pose = (world.get(entity, data.Transform) catch return).*;
    if (world.get(entity, data.Charge) catch null) |charge| {
        engine_print(try @import("std").fmt.bufPrintZ(&output, "dk3 zig charge state: id={d} attached={d} health={d} next={d} remaining={d} detonate={d} parent={d} position={d:.2},{d:.2},{d:.2}\n", .{ try world.persistentId(entity), @intFromBool(charge.attached), (try world.get(entity, data.Health)).current, charge.next_ms - now, charge.expires_ms - now, if (charge.detonate_ms) |at| at - now else -1, if (world.get(entity, data.Attachment) catch null) |value| value.parent_id else 0, pose.position[0], pose.position[1], pose.position[2] }));
    }
}
/// A charge's line for `dk3_runtime_region_weapons`.
pub fn regionProbe(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, details: []u8) !?@import("../../../../mechanics/server/weapon_classes/context.zig").RegionProbe {
    const charge = world.get(entity, data.Charge) catch return null;
    return .{ .kind = "c4", .owner = charge.owner, .text = try @import("std").fmt.bufPrint(details, "attached={d} detonate={d}", .{ @intFromBool(charge.attached), charge.detonate_ms orelse -1 }) };
}
