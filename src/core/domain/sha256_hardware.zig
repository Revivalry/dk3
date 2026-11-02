// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: separately compiled Zig stdlib SHA-256, called only after qualification.
const std = @import("std");
comptime {
    if (!@import("builtin").cpu.hasAll(.x86, &.{ .sha, .avx2 })) @compileError("SHA backend target is missing SHA/AVX2");
}
export fn dk3_sha256_hardware(bytes: [*]const u8, length: usize, out: *[32]u8) callconv(.c) void {
    std.crypto.hash.sha2.Sha256.hash(bytes[0..length], out, .{});
}
