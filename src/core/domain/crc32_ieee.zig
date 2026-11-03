// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: IEEE CRC32 with qualified carryless folding and portable slicing.
const std = @import("std");
const accelerated = @import("crc32_pclmul.zig");

const tables = makeTables();
fn makeTables() [16][256]u32 {
    @setEvalBranchQuota(200000);
    var result: [16][256]u32 = undefined;
    for (0..256) |i| {
        var crc: u32 = @intCast(i);
        for (0..8) |_| crc = (crc >> 1) ^ (0xedb88320 & (0 -% (crc & 1)));
        result[0][i] = crc;
    }
    for (1..16) |slice| for (0..256) |i| {
        const crc = result[slice - 1][i];
        result[slice][i] = (crc >> 8) ^ result[0][@as(u8, @truncate(crc))];
    };
    return result;
}

/// Reflected polynomial 0xedb88320, initial/final complement: save format v1.
/// Runtime-qualified folding and the portable path both accept unaligned input.
pub fn hash(bytes: []const u8) u32 {
    if (comptime accelerated.supported_target) {
        if (bytes.len >= 256 and accelerated.available()) {
            const prefix = accelerated.prefix(bytes);
            var crc = prefix.raw;
            for (bytes[prefix.consumed..]) |byte| crc = tables[0][@as(u8, @truncate(crc)) ^ byte] ^ (crc >> 8);
            return ~crc;
        }
    }
    return portableHash(bytes);
}

/// Sixteen-byte slicing with explicit little-endian reads, without CPU extensions.
pub fn portableHash(bytes: []const u8) u32 {
    var crc: u32 = 0xffffffff;
    var cursor: usize = 0;
    while (bytes.len - cursor >= 16) : (cursor += 16) {
        const low = std.mem.readInt(u64, bytes[cursor..][0..8], .little) ^ @as(u64, crc);
        const high = std.mem.readInt(u64, bytes[cursor + 8 ..][0..8], .little);
        var next: u32 = 0;
        inline for (0..16) |i| {
            const word = if (i < 8) low else high;
            next ^= tables[15 - i][@as(u8, @truncate(word >> @as(u6, @intCast((i % 8) * 8))))];
        }
        crc = next;
    }
    for (bytes[cursor..]) |byte| crc = tables[0][@as(u8, @truncate(crc)) ^ byte] ^ (crc >> 8);
    return ~crc;
}

test "IEEE CRC retains known vectors, all short tails and unaligned large blocks" {
    try std.testing.expectEqual(@as(u32, 0), hash(""));
    try std.testing.expectEqual(@as(u32, 0xcbf43926), hash("123456789"));
    var bytes: [65536 + 32]u8 = undefined;
    for (&bytes, 0..) |*byte, i| byte.* = @truncate(i * 17 + i / 251);
    for (0..32) |offset| {
        for (0..1025) |length| {
            const data = bytes[offset..][0..length];
            try std.testing.expectEqual(std.hash.crc.Crc32IsoHdlc.hash(data), hash(data));
            try std.testing.expectEqual(hash(data), portableHash(data));
        }
        for ([_]usize{ 2047, 2048, 2049, 4095, 4096, 4097, 8191, 8192, 8193, 32767, 32768, 65535, 65536 }) |length| {
            const data = bytes[offset..][0..length];
            try std.testing.expectEqual(std.hash.crc.Crc32IsoHdlc.hash(data), hash(data));
            try std.testing.expectEqual(hash(data), portableHash(data));
        }
    }
}

test "IEEE CRC dispatch and immutable folding state support concurrent callers" {
    const Worker = struct {
        fn run(bytes: []const u8, expected: u32, failed: *std.atomic.Value(bool)) void {
            for (0..8) |_| if (hash(bytes) != expected) {
                failed.store(true, .monotonic);
            };
        }
    };
    var bytes: [65536]u8 = undefined;
    for (&bytes, 0..) |*byte, i| byte.* = @truncate(i * 37 + i / 17);
    const expected = portableHash(&bytes);
    var failed: std.atomic.Value(bool) = .init(false);
    var threads: [4]std.Thread = undefined;
    var started: usize = 0;
    defer for (threads[0..started]) |thread| thread.join();
    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, Worker.run, .{ &bytes, expected, &failed });
        started += 1;
    }
    for (threads[0..started]) |thread| thread.join();
    started = 0;
    try std.testing.expect(!failed.load(.monotonic));
}
