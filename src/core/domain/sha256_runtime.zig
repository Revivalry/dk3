// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: exact SHA-256 with an OS/CPU-qualified stdlib hardware backend.
const std = @import("std");
const builtin = @import("builtin");
const supported = builtin.cpu.arch == .x86_64 and builtin.zig_backend == .stage2_llvm;
extern fn dk3_sha256_hardware([*]const u8, usize, *[32]u8) callconv(.c) void;
var capability: std.atomic.Value(u8) = .init(0);
fn cpuid(leaf: u32, subleaf: u32) [4]u32 {
    var a: u32 = undefined;
    var b: u32 = undefined;
    var c: u32 = undefined;
    var d: u32 = undefined;
    asm volatile ("cpuid"
        : [a] "={eax}" (a),
          [b] "={ebx}" (b),
          [c] "={ecx}" (c),
          [d] "={edx}" (d),
        : [leaf] "{eax}" (leaf),
          [sub] "{ecx}" (subleaf),
    );
    return .{ a, b, c, d };
}
pub fn available() bool {
    if (comptime !supported) return false;
    const cached = capability.load(.monotonic);
    if (cached != 0) return cached == 2;
    const present = detect();
    capability.store(if (present) 2 else 1, .monotonic);
    return present;
}
fn detect() bool {
    if (cpuid(0, 0)[0] < 7) return false;
    const xsave_avx = (@as(u32, 1) << 26) | (@as(u32, 1) << 27) | (@as(u32, 1) << 28);
    if (cpuid(1, 0)[2] & xsave_avx != xsave_avx) return false;
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("xgetbv"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
        : [index] "{ecx}" (@as(u32, 0)),
    );
    if (low & 6 != 6) return false; // OS saves both XMM and YMM state.
    const sha_avx2 = (@as(u32, 1) << 29) | (@as(u32, 1) << 5);
    return cpuid(7, 0)[1] & sha_avx2 == sha_avx2;
}
pub fn portable(bytes: []const u8, out: *[32]u8) void {
    std.crypto.hash.sha2.Sha256.hash(bytes, out, .{});
}
pub fn hash(bytes: []const u8, out: *[32]u8) void {
    if (comptime supported) if (available()) {
        dk3_sha256_hardware(bytes.ptr, bytes.len, out);
        return;
    };
    portable(bytes, out);
}

test "qualified SHA matches standard vectors, every tail/alignment and concurrent callers" {
    const t = std.testing;
    var output: [32]u8 = undefined;
    hash("abc", &output);
    try t.expectEqualStrings("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", &std.fmt.bytesToHex(output, .lower));
    hash("", &output);
    try t.expectEqualStrings("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", &std.fmt.bytesToHex(output, .lower));
    var bytes: [4096 + 31]u8 = undefined;
    for (&bytes, 0..) |*byte, i| byte.* = @truncate(i * 17 + i / 251);
    for (0..32) |alignment| for (0..257) |length| {
        var expected: [32]u8 = undefined;
        portable(bytes[alignment..][0..length], &expected);
        hash(bytes[alignment..][0..length], &output);
        try t.expectEqualSlices(u8, &expected, &output);
    };
    const Context = struct {
        bytes: []const u8,
        valid: bool = false,
        fn run(self: *@This()) void {
            var expected: [32]u8 = undefined;
            var actual: [32]u8 = undefined;
            portable(self.bytes, &expected);
            for (0..64) |_| {
                hash(self.bytes, &actual);
                if (!std.mem.eql(u8, &expected, &actual)) return;
            }
            self.valid = true;
        }
    };
    var contexts: [4]Context = undefined;
    var threads: [4]std.Thread = undefined;
    var count: usize = 0;
    defer for (threads[0..count]) |thread| thread.join();
    for (&contexts, 0..) |*context, i| {
        context.* = .{ .bytes = bytes[i..][0..4096] };
        threads[i] = try std.Thread.spawn(.{}, Context.run, .{context});
        count += 1;
    }
    for (threads) |thread| thread.join();
    count = 0;
    for (contexts) |context| try t.expect(context.valid);
}
