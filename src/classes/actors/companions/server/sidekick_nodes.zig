// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Reference sidekick stop and teleport nodes (NODETYPE_STOPSIDEKICK,
//! NODETYPE_TELEPORTSIDEKICK). A stop node the player reaches makes the party wait (at its point
//! when it has one) until an order or a teleport node sends them on; it takes precedence, and
//! teleport nodes are not tested in a frame a stop fired (CLIENT_HandleStopGoingFurther). The first
//! time a player comes within a running stride of one (32 units: the
//! reference's close-distance test at full speed), each living companion is
//! teleported to the node's point and goes on from there with its order.
//! e1m4b's node at the vent exit over the keypad room sends Superfly round to
//! the far end of the casket corridor, whence he walks to the player.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const abi = @import("../../../../engine/abi.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const v = @import("../../../../core/domain/vector.zig");

/// Nodes already used since the map (or a save of it) was entered.
pub const State = struct { triggered: u64 = 0, stopped: u64 = 0 };

pub fn step(state: *State, world: *data.World, slots: *Slots) !void {
    const nodes = @import("../../../../mechanics/server/authored_nodes.zig");
    for (nodes.stopNodes(), 0..) |*node, index| {
        if (index >= 64) break;
        const bit = @as(u64, 1) << @intCast(index);
        if (state.stopped & bit != 0) continue;
        const player = near(world, slots, node.position) orelse continue;
        // A node no sidekick heeds (none alive, or all already waiting) stays armed.
        const speaker = try @import("companion_triggers.zig").stopParty(world, player, node.point orelse @splat(0)) orelse continue;
        state.stopped |= bit;
        if (node.length > 0) node.speaker = @intFromEnum(speaker);
        report("stop", index, node.position);
        return;
    }
    const teleports = @import("../../../../mechanics/server/authored_nodes.zig").current().teleports;
    for (teleports, 0..) |node, index| {
        if (index >= 64) break;
        const bit = @as(u64, 1) << @intCast(index);
        if (state.triggered & bit != 0) continue;
        const player = near(world, slots, node.position) orelse continue;
        state.triggered |= bit;
        try @import("companion_triggers.zig").teleportParty(world, player, node.point);
        report("teleport", index, node.position);
    }
}
fn report(kind: []const u8, index: usize, position: v.Vec3) void {
    const engine = @import("../../../../engine/server.zig");
    if (engine.integer("developer") < 1) return;
    var text: [128]u8 = undefined;
    engine.print(std.fmt.bufPrintZ(&text, "dk3 sidekick node: {s} index={d} at={d:.0},{d:.0},{d:.0}\n", .{ kind, index, position[0], position[1], position[2] }) catch "dk3 sidekick node\n");
}
fn near(world: *data.World, slots: *Slots, point: v.Vec3) ?@import("../../../../core/ecs/world.zig").Entity {
    for (slots.occupants) |occupant| {
        const entity = occupant orelse continue;
        _ = world.get(entity, data.Player) catch continue;
        const health = world.get(entity, data.Health) catch continue;
        if (health.current <= 0) continue;
        const pose = world.get(entity, data.Transform) catch continue;
        if (v.length(v.subtract(pose.position, point)) < 32) return entity;
    }
    return null;
}
