// SPDX-License-Identifier: GPL-2.0-or-later AND MIT
//! Shared mechanism: Runtime-qualified x86-64 carryless IEEE CRC folding.
// Folding/reduction derived from libdeflate 1.26's crc32_pclmul_template.h.
// Copyright 2016 Eric Biggers
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
const std = @import("std");
const builtin = @import("builtin");
pub const supported_target = builtin.cpu.arch == .x86_64 and builtin.zig_backend == .stage2_llvm;
const Vec = @Vector(2, u64);
const fold_one: Vec = .{ 0xae689191, 0xccaa009e };
const fold_four: Vec = .{ 0x8f352d95, 0x1d9513d7 };
const barrett: Vec = .{ 0xb4e5b025f7011641, 0x00000001db710641 };
var capability: std.atomic.Value(u8) = .init(0);

pub fn available() bool {
    if (comptime !supported_target) return false;
    const cached = capability.load(.monotonic);
    if (cached != 0) return cached == 2;
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;
    asm volatile ("cpuid"
        : [_] "={eax}" (eax),
          [_] "={ebx}" (ebx),
          [_] "={ecx}" (ecx),
          [_] "={edx}" (edx),
        : [_] "{eax}" (@as(u32, 1)),
          [_] "{ecx}" (@as(u32, 0)),
    );
    const present = ecx & (1 << 1) != 0;
    capability.store(if (present) 2 else 1, .monotonic);
    return present;
}

inline fn multiply(a: Vec, b: Vec, comptime selector: u8) Vec {
    return asm ("pclmulqdq $" ++ std.fmt.comptimePrint("0x{x}", .{selector}) ++ ", %[b], %[out]"
        : [out] "=x" (-> Vec),
        : [a] "0" (a),
          [b] "x" (b),
    );
}

inline fn load(bytes: []const u8, offset: usize) Vec {
    return @bitCast(std.mem.readInt(u128, bytes[offset..][0..16], .little));
}

inline fn fold(source: Vec, destination: Vec, multipliers: Vec) Vec {
    return destination ^ multiply(source, multipliers, 0x00) ^ multiply(source, multipliers, 0x11);
}

/// Caller qualifies the CPU and provides at least 64 bytes. Every load stays
/// inside the input; the caller finishes the remaining zero to fifteen bytes.
pub fn prefix(bytes: []const u8) struct { raw: u32, consumed: usize } {
    std.debug.assert(bytes.len >= 64);
    var streams: [4]Vec = .{ load(bytes, 0), load(bytes, 16), load(bytes, 32), load(bytes, 48) };
    streams[0] ^= Vec{ 0xffffffff, 0 };
    var cursor: usize = 64;
    while (bytes.len - cursor >= 64) : (cursor += 64) {
        inline for (0..4) |i| streams[i] = fold(streams[i], load(bytes, cursor + i * 16), fold_four);
    }
    var combined = streams[0];
    inline for (1..4) |i| combined = fold(combined, streams[i], fold_one);
    while (bytes.len - cursor >= 16) : (cursor += 16) combined = fold(combined, load(bytes, cursor), fold_one);
    combined = multiply(combined, fold_one, 0x10) ^ Vec{ combined[1], 0 };
    var reduced = multiply(combined, barrett, 0x00);
    reduced = multiply(reduced, barrett, 0x10);
    const result: @Vector(4, u32) = @bitCast(combined ^ reduced);
    return .{ .raw = result[2], .consumed = cursor };
}
