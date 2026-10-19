// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: zeus. Server adapter: the lightning graph.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/weapon_classes/context.zig");
const engine = @import("zeus.zig");
pub const description = @import("weapon_catalog").classes.zeus;
pub fn fire(fired: *context.Fire) !void {
    try engine.launch(fired.world, fired.slots, fired.projections, fired.owner, fired.shot, fired.table, fired.now);
}
pub fn step(stepping: *context.Step) !void {
    try engine.step(stepping.world, stepping.slots, stepping.projections, stepping.now);
}
/// The player running a chain, or one of its hops.
pub fn actionOwner(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity) ?u32 {
    if (world.get(entity, data.Zeus) catch null) |chain| return chain.owner;
    return if (world.get(entity, data.ZeusBolt) catch null) |bolt| bolt.owner else null;
}
/// A hop originates at its own actor, independently of the chain's owner.
pub fn actionSource(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity) ?u32 {
    return if (world.get(entity, data.ZeusBolt) catch null) |bolt| bolt.source else null;
}
/// Chain and hop effects name their player's slot.
pub const effectOwner = actionOwner;
/// Prints this class's entity state for `dk3_runtime_beams` (combat_probe.zig).
pub fn probeBeam(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, now: i64) !void {
    const engine_print = @import("../../../../engine/server.zig").print;
    var output: [300]u8 = undefined;
    if (world.get(entity, data.Zeus) catch null) |chain| engine_print(try @import("std").fmt.bufPrintZ(&output, "dk3 zig zeus state: id={d} phase={s} targets={d} active={d} zaps={d} ready={d}\n", .{ try world.persistentId(entity), @tagName(chain.phase), chain.count, chain.active, chain.zaps, chain.ready_ms - now }));
}
/// A chain's or hop's line for `dk3_runtime_region_weapons`.
pub fn regionProbe(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, details: []u8) !?@import("../../../../mechanics/server/weapon_classes/context.zig").RegionProbe {
    if (world.get(entity, data.Zeus) catch null) |chain| return .{ .kind = "zeus", .owner = chain.owner, .text = try @import("std").fmt.bufPrint(details, "phase={s} targets={d} active={d} zaps={d}", .{ @tagName(chain.phase), chain.count, chain.active, chain.zaps }) };
    const bolt = world.get(entity, data.ZeusBolt) catch return null;
    return .{ .kind = "zeus_bolt", .owner = bolt.owner, .text = try @import("std").fmt.bufPrint(details, "phase={s} source={d} target={d} chain={d}", .{ @tagName(bolt.phase), bolt.source, bolt.target, bolt.chain }) };
}
