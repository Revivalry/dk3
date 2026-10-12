// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Read-only physical controller ownership, for explicit development fixtures.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const access = @import("region_access.zig");
const engine = @import("../../engine/server.zig");
const Slots = @import("../../engine/slots.zig").Slots;
fn inspectLocal(world: *data.World, slots: *const Slots, name: []const u8) !void {
    for (slots.occupants) |maybe| if (maybe) |entity| {
        const pose = world.get(entity, data.Transform) catch continue;
        var buffer: [640]u8 = undefined;
        var details: [320]u8 = undefined;
        var owner: u32 = 0;
        const kind: []const u8, const state: []const u8 = blk: {
            if (world.get(entity, data.Projectile) catch null) |projectile| {
                owner = projectile.owner;
                // Each weapon's flight state describes itself.
                const text = switch (projectile.flight) {
                    inline else => |*flight| if (comptime @import("../domain/snapshot_time.zig").classState(@TypeOf(flight.*), "describe")) try flight.describe(&details) else "",
                };
                break :blk .{ @tagName(projectile.flight), text };
            }
            inline for (@import("../../game/server/weapon_classes/classes.zig").adapters) |A| if (@hasDecl(A, "regionProbe")) {
                if (try A.regionProbe(world, entity, &details)) |probe| {
                    owner = probe.owner;
                    break :blk .{ probe.kind, probe.text };
                }
            };
            continue;
        };
        engine.print(try std.fmt.bufPrintZ(&buffer, "dk3 region weapon: id={d} map={s} kind={s} owner={d} pos={d:.3},{d:.3},{d:.3} {s}\n", .{ try world.persistentId(entity), name, kind, owner, pose.position[0], pose.position[1], pose.position[2], state }));
    };
}
pub fn inspect(world: *data.World, slots: *const Slots) !void {
    const context = access.contextFor(world);
    try inspectLocal(world, slots, if (context) |owner| std.mem.sliceTo(&owner.map_name, 0) else "local");
    if (context) |owner| {
        var neighbors = access.Neighbors.init(owner);
        while (neighbors.next()) |neighbor| if (&neighbor.world.? != world) {
            try inspectLocal(&neighbor.world.?, &neighbor.slots, std.mem.sliceTo(&neighbor.map_name, 0));
        };
    }
    engine.print("dk3 region weapons complete\n");
}
