// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Development diagnostics for world state; only admitted in explicit probe mode.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const Slots = @import("../../engine/slots.zig").Slots;
pub fn diagnostics(world: *data.World, slots: *Slots, projections: []const abi.EntityProjection) !void {
    var text: [400]u8 = undefined;
    for (slots.occupants, 0..) |occupant, slot| {
        const entity = occupant orelse continue;
        const object = world.get(entity, data.MapObject) catch continue;
        const id = try world.persistentId(entity);
        inline for (@import("../../game/server/world_system_classes.zig").probes) |Class| try Class.probe(world, entity, id);
        const center = @import("../../core/domain/vector.zig").scale(@import("../../core/domain/vector.zig").add(projections[slot].shared.absmin, projections[slot].shared.absmax), 0.5);
        if (world.get(entity, data.Exit)) |state| engine.print(try std.fmt.bufPrintZ(&text, "dk3 zig exit: id={d} map={s} spawn={s} latched={d} center={d:.3},{d:.3},{d:.3}\n", .{ id, @import("properties.zig").text(object.*, "map") orelse "", object.target, @intFromBool(state.latched), center[0], center[1], center[2] })) else |_| {}
        if (world.get(entity, data.Hazard)) |hazard| engine.print(try std.fmt.bufPrintZ(&text, "dk3 zig hazard: id={d} name={s} enabled={d} center={d:.3},{d:.3},{d:.3}\n", .{ id, object.targetname, @intFromBool(hazard.enabled), center[0], center[1], center[2] })) else |_| {}
        if (world.get(entity, data.Destructible)) |state| engine.print(try std.fmt.bufPrintZ(&text, "dk3 zig destructible: id={d} health={d} broken={d} hidden={d} center={d:.3},{d:.3},{d:.3}\n", .{ id, (try world.get(entity, data.Health)).current, @intFromBool(state.broken), @intFromBool(state.hidden), center[0], center[1], center[2] })) else |_| {}
        if (world.get(entity, data.TargetSequence)) |state| engine.print(try std.fmt.bufPrintZ(&text, "dk3 zig sequence: id={d} name={s} active={d} cursor={d}/{d} start={d}\n", .{ id, object.targetname, @intFromBool(state.active), state.cursor, state.events.len, state.started_ms })) else |_| {}
    }
    engine.print("dk3 zig world states complete\n");
}
/// One line per transported entity, keyed by persistent ID, so a probe can
/// compare what clients receive after a fresh spawn and after restoration.
pub fn projectionReport(world: *data.World, slots: *Slots, values: []const abi.EntityProjection, only: []const u8) !void {
    const c = abi.c;
    var text: [400]u8 = undefined;
    for (slots.occupants, 0..) |occupant, slot| {
        const entity = occupant orelse continue;
        const projection = values[slot];
        const class = if (world.get(entity, data.MapObject)) |object| object.classname else |_| "-";
        const model = if (world.get(entity, data.MapObject)) |object| object.model else |_| "";
        if (only.len > 0 and !std.mem.eql(u8, class, only)) continue;
        const sent = projection.shared.linked != 0 and projection.shared.svFlags & c.SVF_NOCLIENT == 0;
        engine.print(try std.fmt.bufPrintZ(&text, "dk3 projection: id={d} slot={d} class={s} model={s} sent={d} eType={d} index={d} index2={d} bmodel={d} solid={d} contents={d} svFlags={d} generic1={d} frame={d} mins={d:.0},{d:.0},{d:.0} maxs={d:.0},{d:.0},{d:.0} origin={d:.0},{d:.0},{d:.0} rate={d}\n", .{ try world.persistentId(entity), slot, class, model, @intFromBool(sent), projection.state.eType, projection.state.modelindex, projection.state.modelindex2, projection.shared.bmodel, projection.state.solid, projection.shared.contents, projection.shared.svFlags, projection.state.generic1, projection.state.frame, projection.shared.mins[0], projection.shared.mins[1], projection.shared.mins[2], projection.shared.maxs[0], projection.shared.maxs[1], projection.shared.maxs[2], projection.state.pos.trBase[0], projection.state.pos.trBase[1], projection.state.pos.trBase[2], projection.state.dk3AnimationRate }));
    }
    engine.print("dk3 projection: complete\n");
}
