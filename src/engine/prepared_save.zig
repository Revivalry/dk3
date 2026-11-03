// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: copy-only volatile save preparation handoff through engine ABI.
const std = @import("std");
const abi = @import("abi.zig");
const maximum = 64 * 1024 * 1024;
pub fn clear(gateway: *abi.Gateway) void {
    _ = gateway.call(abi.c.UI_DK3_PREPARED_SAVE_V1, .{ @as(?[*]const u8, null), @as(isize, 0) });
}
pub fn store(gateway: *abi.Gateway, bytes: []const u8) !void {
    if (bytes.len > maximum) return error.PreparedSaveCapacity;
    if (gateway.call(abi.c.UI_DK3_PREPARED_SAVE_V1, .{ bytes.ptr, @as(isize, @intCast(bytes.len)) }) != 0) return error.PreparedSaveUnavailable;
}
pub fn read(gateway: *abi.Gateway, allocator: std.mem.Allocator) !?[]u8 {
    const length = gateway.call(abi.c.G_DK3_PREPARED_SAVE_V1, .{ @as(?[*]u8, null), @as(isize, 0) });
    if (length == 0) return null;
    if (length < 32 or length > maximum) return error.PreparedSaveCapacity;
    const bytes = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(bytes);
    if (gateway.call(abi.c.G_DK3_PREPARED_SAVE_V1, .{ bytes.ptr, length }) != length) return error.PreparedSaveUnavailable;
    return bytes;
}
