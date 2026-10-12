// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Validated cosmetic weapon model replacements from the installed HD package.
const std = @import("std");
const engine = @import("../../engine/client.zig");
const c = @import("../../engine/abi.zig").c;

const Entry = struct {
    source: [64:0]u8 = @splat(0),
    target: [64:0]u8 = @splat(0),
    handle: c.qhandle_t = 0,
};

var entries: [64]Entry = @splat(.{});
var count: usize = 0;
var loaded = false;

pub fn reset() void {
    entries = @splat(.{});
    count = 0;
    loaded = false;
}

pub fn model(name: []const u8) !?c.qhandle_t {
    if (!loaded) {
        loaded = true;
        if (try @import("../../engine/files.zig").readOptional(.client, &engine.gateway, std.heap.c_allocator, "dk3/hd-weapon-models.cfg", 8192)) |bytes| {
            defer std.heap.c_allocator.free(bytes);
            var lines = std.mem.tokenizeScalar(u8, bytes, '\n');
            while (lines.next()) |line| {
                var fields = std.mem.tokenizeAny(u8, line, " \r\t");
                const source = fields.next() orelse continue;
                const target = fields.next() orelse return error.InvalidHdWeaponManifest;
                if (fields.next() != null or count == entries.len or source.len >= 64 or target.len >= 64 or
                    !std.mem.startsWith(u8, source, "models/") or !std.mem.endsWith(u8, source, ".dkm") or
                    !std.mem.startsWith(u8, target, "models/hd-weapons/") or !std.mem.endsWith(u8, target, ".iqm") or
                    std.mem.indexOf(u8, source, "..") != null or std.mem.indexOf(u8, target, "..") != null)
                    return error.InvalidHdWeaponManifest;
                for (entries[0..count]) |entry| {
                    if (std.mem.eql(u8, std.mem.sliceTo(&entry.source, 0), source)) return error.InvalidHdWeaponManifest;
                }
                @memcpy(entries[count].source[0..source.len], source);
                @memcpy(entries[count].target[0..target.len], target);
                count += 1;
            }
        }
    }
    for (entries[0..count]) |*entry| {
        if (!std.mem.eql(u8, std.mem.sliceTo(&entry.source, 0), name)) continue;
        if (entry.handle == 0) {
            entry.handle = @intCast(engine.gateway.call(c.CG_R_REGISTERMODEL, .{&entry.target}));
            if (entry.handle == 0) return error.HdWeaponModelUnavailable;
            var message: [180]u8 = undefined;
            engine.print(try std.fmt.bufPrintZ(&message, "dk3 HD weapon: {s} -> {s}\n", .{
                std.mem.sliceTo(&entry.source, 0), std.mem.sliceTo(&entry.target, 0),
            }));
        }
        return entry.handle;
    }
    return null;
}
