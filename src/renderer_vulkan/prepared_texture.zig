// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: checked, source-bound, uncolored RGBA8 mip packages.
const std = @import("std");
pub const maximum = 256 * 1024 * 1024;
pub const Texture = struct {
    width: u32,
    height: u32,
    count: usize,
    levels: [16][]const u8 = undefined,
};
fn word(bytes: []const u8, at: usize) u32 {
    return std.mem.readInt(u32, bytes[at..][0..4], .little);
}
pub fn path(name: []const u8, buffer: *[64]u8) ![:0]const u8 {
    if (name.len >= 64) return error.InvalidPath;
    var normalized: [64]u8 = undefined;
    for (name, 0..) |byte, i| normalized[i] = std.ascii.toLower(if (byte == '\\') '/' else byte);
    var digest: [32]u8 = undefined;
    @import("runtime_digest").hash(normalized[0..name.len], &digest);
    return std.fmt.bufPrintZ(buffer, "dk3/prepared/{s}.dkt", .{std.fmt.bytesToHex(digest[0..16].*, .lower)});
}
/// All slices borrow the checked package. The source hash prevents a sidecar
/// from overriding a changed texture or a higher-priority loose/pack override.
pub fn decode(bytes: []const u8, source: []const u8) !Texture {
    if (bytes.len < 64 or bytes.len > maximum or !std.mem.eql(u8, bytes[0..8], "DK3TEX1\x00")) return error.InvalidPreparedTexture;
    var digest: [32]u8 = undefined;
    @import("runtime_digest").hash(source, &digest);
    if (!std.mem.eql(u8, &digest, bytes[24..56])) return error.StalePreparedTexture;
    if (word(bytes, 20) != 0 or word(bytes, 60) != 0 or std.hash.Crc32.hash(bytes[64..]) != word(bytes, 56)) return error.InvalidPreparedTexture;
    var result: Texture = .{ .width = word(bytes, 8), .height = word(bytes, 12), .count = word(bytes, 16) };
    if (source.len < 33 or !std.mem.eql(u8, source[0..8], "\x89PNG\r\n\x1a\n") or
        std.mem.readInt(u32, source[16..20], .big) != result.width or std.mem.readInt(u32, source[20..24], .big) != result.height or source[24] != 8 or (source[25] != 2 and source[25] != 6)) return error.InvalidPreparedTexture;
    if (result.width == 0 or result.height == 0 or result.width > 16384 or result.height > 16384 or result.count == 0 or result.count > 16 or bytes.len < 64 + result.count * 16) return error.InvalidPreparedTexture;
    var cursor: usize = 64 + result.count * 16;
    var width = result.width;
    var height = result.height;
    for (0..result.count) |i| {
        const at = 64 + i * 16;
        const size = @as(usize, width) * height * 4;
        if (word(bytes, at) != cursor or word(bytes, at + 4) != size or word(bytes, at + 8) != width or word(bytes, at + 12) != height or size > bytes.len - cursor) return error.InvalidPreparedTexture;
        result.levels[i] = bytes[cursor..][0..size];
        cursor += size;
        if (width == 1 and height == 1 and i + 1 != result.count) return error.InvalidPreparedTexture;
        width = @max(width >> 1, 1);
        height = @max(height >> 1, 1);
    }
    if (cursor != bytes.len or result.levels[result.count - 1].len != 4) return error.InvalidPreparedTexture;
    return result;
}
