// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Engine owns atomic replacement, previous-save recovery and private state paths.
const std = @import("std");
const engine = @import("server.zig");
const c = @import("abi.zig").c;
const snapshot = @import("../core/domain/save_stream.zig");
fn name(slot: []const u8, buffer: []u8) ![:0]const u8 {
    if (!snapshot.validName(slot)) return error.InvalidSaveSlot;
    return std.fmt.bufPrintZ(buffer, "{s}", .{slot});
}
pub fn write(slot: []const u8, bytes: []const u8, info: bool) !void {
    var buffer: [64]u8 = undefined;
    const slot_name = try name(slot, &buffer);
    const length = engine.gateway.call(c.G_DK3_SAVE_WRITE, .{ @as(isize, if (info) 2 else 1), slot_name.ptr, bytes.ptr, @as(isize, @intCast(bytes.len)) });
    if (length != bytes.len) return error.SaveWriteFailed;
}
/// Makes `to` the same save as `from` (the engine's hard link), without copying its bytes.
pub fn link(from: []const u8, to: []const u8) !void {
    var from_buffer: [64]u8 = undefined;
    var to_buffer: [64]u8 = undefined;
    if (engine.gateway.call(c.G_DK3_SAVE_LINK_V1, .{ (try name(from, &from_buffer)).ptr, (try name(to, &to_buffer)).ptr }) != 0) return error.SaveLinkFailed;
}
pub fn read(allocator: std.mem.Allocator, slot: []const u8, previous: bool) ![]u8 {
    var buffer: [64]u8 = undefined;
    const slot_name = try name(slot, &buffer);
    const scratch = try allocator.alloc(u8, snapshot.maximum);
    defer allocator.free(scratch);
    const length = engine.gateway.call(c.G_DK3_SAVE_READ, .{ @as(isize, 1), slot_name.ptr, scratch.ptr, @as(isize, @intCast(scratch.len)), @as(isize, @intFromBool(previous)) });
    if (length <= 0 or length > scratch.len) return error.SaveMissingOrUnreadable;
    return allocator.dupe(u8, scratch[0..@intCast(length)]);
}
/// A save's metadata sidecar (`<slot>.info`), when it has one.
pub fn readInfo(allocator: std.mem.Allocator, slot: []const u8) !?[]u8 {
    var buffer: [64]u8 = undefined;
    const slot_name = try name(slot, &buffer);
    var scratch: [1024]u8 = undefined;
    const length = engine.gateway.call(c.G_DK3_SAVE_READ, .{ @as(isize, 2), slot_name.ptr, &scratch, @as(isize, scratch.len), @as(isize, 0) });
    if (length <= 0 or length > scratch.len) return null;
    return try allocator.dupe(u8, scratch[0..@intCast(length)]);
}
