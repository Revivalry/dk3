// SPDX-License-Identifier: GPL-2.0-or-later
//! Pure CPU profiler of the actual renderer mip/color implementation; no graphics initialization.
const std = @import("std");
const image = @import("image.zig");
const image_source_sha256 = blk: {
    @setEvalBranchQuota(10_000_000);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(@embedFile("image.zig"), &digest, .{});
    break :blk std.fmt.bytesToHex(digest, .lower);
};

extern fn R_DecodePNG(bytes: [*]const u8, length: c_int, pic: *?[*]u8, width: *c_int, height: *c_int, maximum: usize) void;

test "RGBA mip pixels retain truncation and alpha across vector and scalar levels" {
    var pixels: [64]u8 = undefined;
    for (&pixels, 0..) |*byte, index| byte.* = @intCast(index);
    image.setCpuColorMappings(1, 1);
    var levels = try image.prepareLevels(&pixels, 8, 2, .{ .mipmap = true }, 0, 16384);
    defer levels.deinit();
    try std.testing.expectEqual(@as(usize, 4), levels.count);
    try std.testing.expectEqualSlices(u8, &pixels, levels.levels[0]);
    try std.testing.expectEqualSlices(u8, &.{ 18, 19, 20, 21, 26, 27, 28, 29, 34, 35, 36, 37, 42, 43, 44, 45 }, levels.levels[1]);
    try std.testing.expectEqualSlices(u8, &.{ 22, 23, 24, 25, 38, 39, 40, 41 }, levels.levels[2]);
    try std.testing.expectEqualSlices(u8, &.{ 30, 31, 32, 33 }, levels.levels[3]);
    try std.testing.expect(levels.has_alpha);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0 / 255.0), levels.average[0], 1e-7);
}

test "odd rows and tail columns retain existing box-filter pixels" {
    var pixels: [84]u8 = undefined;
    for (&pixels, 0..) |*byte, index| byte.* = @intCast(index);
    image.setCpuColorMappings(1, 1);
    var levels = try image.prepareLevels(&pixels, 7, 3, .{ .mipmap = true }, 0, 16384);
    defer levels.deinit();
    try std.testing.expectEqual(@as(usize, 3), levels.count);
    try std.testing.expectEqualSlices(u8, &.{ 16, 17, 18, 19, 24, 25, 26, 27, 32, 33, 34, 35 }, levels.levels[1]);
    try std.testing.expectEqualSlices(u8, &.{ 20, 21, 22, 23 }, levels.levels[2]);
}

test "color mappings compose exact bytes while plain and unscaled paths keep their rules" {
    const pixels = [_]u8{ 32, 64, 128, 17 };
    image.setCpuColorMappings(2, 2);
    var mip = try image.prepareLevels(&pixels, 1, 1, .{ .mipmap = true }, 0, 16384);
    defer mip.deinit();
    try std.testing.expectEqualSlices(u8, &.{ 128, 181, 255, 17 }, mip.levels[0]);
    var plain = try image.prepareLevels(&pixels, 1, 1, .{}, 0, 16384);
    defer plain.deinit();
    try std.testing.expectEqualSlices(u8, &.{ 90, 128, 181, 17 }, plain.levels[0]);
    var unscaled = try image.prepareLevels(&pixels, 1, 1, .{ .mipmap = true, .no_light_scale = true }, 0, 16384);
    defer unscaled.deinit();
    try std.testing.expectEqualSlices(u8, &pixels, unscaled.levels[0]);
    image.setCpuColorMappings(1, 1);
    var identity = try image.prepareLevels(&pixels, 1, 1, .{ .mipmap = true }, 0, 16384);
    defer identity.deinit();
    try std.testing.expectEqualSlices(u8, &pixels, identity.levels[0]);
}

test "picmip and device limits select the exact already-prepared mip pixels" {
    var pixels: [64]u8 = undefined;
    for (&pixels, 0..) |*byte, index| byte.* = @intCast(index);
    image.setCpuColorMappings(1, 1);
    var levels = try image.prepareLevels(&pixels, 8, 2, .{ .mipmap = true, .picmip = true }, 1, 2);
    defer levels.deinit();
    try std.testing.expectEqual(@as(usize, 2), levels.skip);
    try std.testing.expectEqual(@as(u32, 2), levels.upload_width);
    try std.testing.expectEqual(@as(u32, 1), levels.upload_height);
    try std.testing.expectEqualSlices(u8, &.{ 22, 23, 24, 25, 38, 39, 40, 41 }, levels.used()[0]);
    try std.testing.expectEqualSlices(u8, &.{ 30, 31, 32, 33 }, levels.used()[1]);
}

test "alpha scan handles every lane, unaligned input and scalar tails" {
    image.setCpuColorMappings(1, 1);
    var storage: [67 * 4 + 3]u8 = undefined;
    for ([_]usize{ 1, 15, 16, 17, 31, 32, 33, 63, 64, 65, 67 }) |count| {
        for (0..4) |offset| {
            const pixels = storage[offset..][0 .. count * 4];
            for (0..count) |index| pixels[index * 4 ..][0..4].* = .{ 0, 17, 128, 255 };
            var solid = try image.prepareLevels(pixels, @intCast(count), 1, .{}, 0, 16384);
            try std.testing.expect(!solid.has_alpha);
            try std.testing.expectEqualSlices(u8, pixels, solid.levels[0]);
            solid.deinit();
            for (0..count) |index| {
                pixels[index * 4 + 3] = if (index % 2 == 0) 0 else 254;
                var alpha = try image.prepareLevels(pixels, @intCast(count), 1, .{}, 0, 16384);
                try std.testing.expect(alpha.has_alpha);
                try std.testing.expectEqualSlices(u8, pixels, alpha.levels[0]);
                alpha.deinit();
                pixels[index * 4 + 3] = 255;
            }
        }
    }
}

test "borrowed identity base remains immutable and only generated levels are freed" {
    const pixels = [_]u8{ 0, 4, 8, 255, 4, 8, 12, 255, 8, 12, 16, 128, 12, 16, 20, 255 };
    image.setCpuColorMappings(1, 1);
    var owned = try image.prepareLevels(&pixels, 2, 2, .{ .mipmap = true }, 0, 16384);
    defer owned.deinit();
    try std.testing.expect(!owned.borrowedBase() and owned.levels[0].ptr != pixels[0..].ptr);
    {
        var borrowed = try image.prepareLevelsBorrowed(&pixels, 2, 2, .{ .mipmap = true }, 0, 16384);
        defer borrowed.deinit();
        try std.testing.expect(borrowed.borrowedBase() and borrowed.levels[0].ptr == pixels[0..].ptr);
        try std.testing.expectEqualSlices(u8, &.{ 6, 10, 14, 223 }, borrowed.levels[1]);
        try std.testing.expectEqual(owned.average, borrowed.average);
        try std.testing.expectEqual(owned.has_alpha, borrowed.has_alpha);
        for (owned.used(), borrowed.used()) |a, b| try std.testing.expectEqualSlices(u8, a, b);
    }
    try std.testing.expectEqualSlices(u8, &pixels, owned.levels[0]);
}

test "borrow requests keep independent color mapping fallback and unscaled source" {
    var storage: [19]u8 = undefined;
    const original = [_]u8{ 32, 64, 128, 17, 255, 0, 16, 255, 48, 72, 96, 254, 13, 19, 31, 255 };
    const pixels = storage[1..17];
    @memcpy(pixels, &original);
    image.setCpuColorMappings(1.8, 1.4);
    for ([_]image.Flags{ .{ .mipmap = true }, .{}, .{ .mipmap = true, .no_light_scale = true } }) |flags| {
        var owned = try image.prepareLevels(pixels, 2, 2, flags, 0, 16384);
        defer owned.deinit();
        var borrowed = try image.prepareLevelsBorrowed(pixels, 2, 2, flags, 0, 16384);
        defer borrowed.deinit();
        try std.testing.expectEqual(flags.no_light_scale, borrowed.borrowedBase());
        if (flags.no_light_scale) try std.testing.expect(borrowed.levels[0].ptr == pixels.ptr) else try std.testing.expect(borrowed.levels[0].ptr != pixels.ptr);
        for (owned.used(), borrowed.used()) |a, b| try std.testing.expectEqualSlices(u8, a, b);
        try std.testing.expectEqualSlices(u8, &original, pixels);
    }
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 8 and args.len != 9) return error.ExpectedPngRepeatsGammaIntensityModePicmipLimit;
    const borrow = args.len == 9;
    if (borrow and !std.mem.eql(u8, args[8], "borrow")) return error.ExpectedBorrowOption;
    const repeats = try std.fmt.parseInt(u16, args[2], 10);
    const gamma = try std.fmt.parseFloat(f32, args[3]);
    const intensity = try std.fmt.parseFloat(f32, args[4]);
    const Mode = enum { mip, plain, unscaled };
    const mode = std.meta.stringToEnum(Mode, args[5]) orelse return error.InvalidMode;
    const picmip = try std.fmt.parseInt(u4, args[6], 10);
    const limit = try std.fmt.parseInt(u32, args[7], 10);
    if (repeats == 0 or repeats > 10000 or !std.math.isFinite(gamma) or gamma <= 0 or !std.math.isFinite(intensity) or intensity < 1 or limit == 0) return error.InvalidBounds;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(256 << 20));
    var decoded: ?[*]u8 = null;
    var width: c_int = 0;
    var height: c_int = 0;
    R_DecodePNG(bytes.ptr, @intCast(bytes.len), &decoded, &width, &height, 256 << 20);
    const pixels = (decoded orelse return error.InvalidPng)[0 .. @as(usize, @intCast(width)) * @as(usize, @intCast(height)) * 4];
    defer std.heap.c_allocator.free(pixels);
    image.setCpuColorMappings(gamma, intensity);
    const flags: image.Flags = .{ .mipmap = mode != .plain, .picmip = mode != .plain, .no_light_scale = mode == .unscaled };
    var output_buffer: [4096]u8 = undefined;
    var output = std.Io.File.Writer.initStreaming(.stdout(), init.io, &output_buffer);
    var expected: [32]u8 = undefined;
    for (0..@as(usize, repeats) + 1) |sample| {
        const start = std.Io.Clock.awake.now(init.io).nanoseconds;
        var levels = if (borrow)
            try image.prepareLevelsBorrowed(pixels, @intCast(width), @intCast(height), flags, picmip, limit)
        else
            try image.prepareLevels(pixels, @intCast(width), @intCast(height), flags, picmip, limit);
        const elapsed = std.Io.Clock.awake.now(init.io).nanoseconds - start;
        defer levels.deinit();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        var size: usize = 0;
        var owned_bytes: usize = 0;
        for (levels.owned[0..levels.count]) |allocation| if (allocation) |level| {
            owned_bytes += level.len;
        };
        for (levels.used()) |level| {
            hash.update(level);
            size += level.len;
        }
        var digest: [32]u8 = undefined;
        hash.final(&digest);
        if (sample == 0) {
            expected = digest;
            continue;
        }
        if (!std.mem.eql(u8, &digest, &expected)) return error.NondeterministicPixels;
        try output.interface.print("{{\"sample\":{d},\"prepare_ms\":{d:.6},\"sha256\":\"{s}\",\"image_source_sha256\":\"{s}\",\"width\":{d},\"height\":{d},\"levels\":{d},\"skip\":{d},\"bytes\":{d},\"owned_bytes\":{d},\"borrowed_level0\":{},\"alpha\":{},\"average\":[{d:.9},{d:.9},{d:.9}]}}\n", .{ sample - 1, @as(f64, @floatFromInt(elapsed)) / 1e6, std.fmt.bytesToHex(digest, .lower), image_source_sha256, levels.upload_width, levels.upload_height, levels.count, levels.skip, size, owned_bytes, levels.borrowedBase(), levels.has_alpha, levels.average[0], levels.average[1], levels.average[2] });
        try output.interface.flush();
    }
}
