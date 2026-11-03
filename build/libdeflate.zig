// SPDX-License-Identifier: GPL-2.0-or-later
//! Build only the reviewed full-buffer DEFLATE/zlib decoder and Adler checksum.
const std = @import("std");
const root = "engine/ioquake3/code/thirdparty/libdeflate-1.26/";

pub fn add(b: *std.Build, module: *std.Build.Module) void {
    for ([_][]const u8{
        "lib/utils.c",   "lib/deflate_decompress.c", "lib/zlib_decompress.c",
        "lib/adler32.c", "lib/x86/cpu_features.c",   "lib/arm/cpu_features.c",
    }) |path| module.addCSourceFile(.{
        .file = b.path(b.fmt("{s}{s}", .{ root, path })),
        // Zig 0.16's generic x86 target rejects the upstream 512-bit Adler
        // intrinsic target attributes (missing evex512). Use upstream's opt-out;
        // AVX2/SSE2 and runtime feature/OS checks remain available.
        .flags = &.{ "-std=c11", "-fvisibility=hidden", "-DLIBDEFLATE_ASSEMBLER_DOES_NOT_SUPPORT_AVX512VNNI" },
    });
}
