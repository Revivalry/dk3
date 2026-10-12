// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: nightmare. Server adapter: the ritual and its victims.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("nightmare.zig");
pub const description = @import("weapon_catalog").classes.nightmare;
pub fn fire(fired: *context.Fire) !void {
    try engine.launch(fired.world, fired.slots, fired.projections, fired.owner, fired.shot, fired.table, fired.now);
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
pub const holds = engine.holds;
/// The ritual effect names its victim's slot.
pub const effect_links: context.Links = .{ .other2 = true };
/// A ritual involves its caster and its victim.
pub fn actionInvolves(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, identity: u32) bool {
    const ritual = world.get(entity, data.Nightmare) catch return false;
    return ritual.owner == identity or ritual.victim == identity;
}
/// A ritual releases its victim as it is removed.
pub fn removeAction(world: *data.World, slots: *@import("../../../../engine/slots.zig").Slots, projections: []@import("../../../../engine/abi.zig").EntityProjection, entity: @import("../../../../core/ecs/world.zig").Entity) !bool {
    if ((world.get(entity, data.Nightmare) catch null) == null) return false;
    try engine.remove(world, slots, projections, entity);
    return true;
}
/// The ritual effect names its caster's slot, and its victim's as the second link.
pub fn effectOwner(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity) ?u32 {
    return if (world.get(entity, data.Nightmare) catch null) |ritual| ritual.owner else null;
}
pub fn effectSecond(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity) ?u32 {
    return if (world.get(entity, data.Nightmare) catch null) |ritual| ritual.victim orelse 0 else null;
}
/// Prints this class's entity state for `dk3_runtime_beams` (combat_probe.zig).
pub fn probeBeam(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, now: i64) !void {
    const engine_print = @import("../../../../engine/server.zig").print;
    var output: [300]u8 = undefined;
    if (world.get(entity, data.Nightmare) catch null) |ritual| engine_print(try @import("std").fmt.bufPrintZ(&output, "dk3 zig nightmare state: id={d} phase={s} targets={d} cursor={d} victim={d} next={d}\n", .{ try world.persistentId(entity), @tagName(ritual.phase), ritual.count, ritual.cursor, ritual.victim orelse 0, ritual.next_ms - now }));
}
/// A ritual's line for `dk3_runtime_region_weapons`.
pub fn regionProbe(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, details: []u8) !?@import("../../../../mechanics/server/weapon_classes/context.zig").RegionProbe {
    const ritual = world.get(entity, data.Nightmare) catch return null;
    const victim = @import("../../../../mechanics/server/region_access.zig").find(world, ritual.victim orelse 0);
    const motion = if (victim) |ref| (try ref.get(data.Body)).motion_owner orelse 0 else 0;
    return .{ .kind = "nightmare", .owner = ritual.owner, .text = try @import("std").fmt.bufPrint(details, "phase={s} victim={d} freeze={d} targets={d}", .{ @tagName(ritual.phase), ritual.victim orelse 0, motion, ritual.count }) };
}
