// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: authored text shown to a player.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const engine = @import("../../engine/server.zig");
const c = @import("../../engine/abi.zig").c;

/// Centre-prints `value` to a player client; quotes and line breaks are dropped.
pub fn centerPrint(world: *data.World, player: ecs.Entity, value: []const u8) !void {
    const slot = (try world.get(player, data.Binding)).slot;
    if (slot >= c.MAX_CLIENTS) return;
    var text: [1024]u8 = undefined;
    var escaped: [900]u8 = undefined;
    var size: usize = 0;
    for (value) |ch| {
        if (size == escaped.len) break;
        if (ch == '"' or ch == '\n' or ch == '\r') continue;
        escaped[size] = ch;
        size += 1;
    }
    engine.send(@intCast(slot), try std.fmt.bufPrintZ(&text, "cp \"{s}\"", .{escaped[0..size]}));
}
