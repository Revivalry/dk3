// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the 256 lightstyle levels the server publishes and the client decodes, and
//! the default animated styles. Light classes choose patterns; this module only transports them.
// Default light animation samples: Copyright (C) 1997-2001 Id Software, Inc.
// GPL-2.0-or-later, Quake-2 game/g_spawn.c at 372afde46e7defc9dd2d719a1732b8ace1fa096e.
// Source and review: docs/provenance.md, sequence 275.
const std = @import("std");
pub fn sample(pattern: []const u8, age_ms: i64) u8 {
    if (pattern.len == 0) return 12;
    const index: usize = @intCast(@mod(@divFloor(age_ms, 100), @as(i64, @intCast(pattern.len))));
    return @intCast(std.math.clamp(@as(i32, pattern[index]) - 'a', 0, 48));
}
pub fn defaults(now: i64) [256]u8 {
    var result: [256]u8 = @splat(12);
    result[0] = sample("m", now);
    result[1] = sample("mmnmmommommnonmmonqnmmo", now);
    result[2] = sample("abcdefghijklmnopqrstuvwxyzyxwvutsrqponmlkjihgfedcba", now);
    result[3] = sample("mmmmmaaaaammmmmaaaaaabcdefgabcdefg", now);
    result[4] = sample("mamamamamama", now);
    result[5] = sample("jklmnopqrstuvwxyzyxwvutsrqponmlkj", now);
    result[6] = sample("nmonqnmomnmomomno", now);
    result[7] = sample("mmmaaaabcdefgmmmmaaaammmaamm", now);
    result[8] = sample("mmmaaammmaaammmabcdefaaaammmmabcdefmmmaaaa", now);
    result[9] = sample("aaaaaaaazzzzzzzz", now);
    result[10] = sample("mmamammmmammamamaaamammma", now);
    result[11] = sample("abcdefghijklmnopqrrqponmlkjihgfedcba", now);
    result[63] = sample("a", now);
    return result;
}
pub fn encode(values: [256]u8) [514:0]u8 {
    var text: [514:0]u8 = undefined;
    text[0] = '1';
    text[1] = ':';
    const hex = "0123456789abcdef";
    for (values, 0..) |level, i| {
        text[2 + i * 2] = hex[level >> 4];
        text[3 + i * 2] = hex[level & 15];
    }
    text[514] = 0;
    return text;
}
pub fn decode(text: []const u8) ![256]f32 {
    if (text.len != 514 or !std.mem.startsWith(u8, text, "1:")) return error.InvalidLightstyles;
    var result: [256]f32 = undefined;
    for (&result, 0..) |*out, i| {
        const level = std.fmt.parseInt(u8, text[2 + i * 2 .. 4 + i * 2], 16) catch return error.InvalidLightstyles;
        if (level > 48) return error.InvalidLightstyles;
        out.* = @as(f32, @floatFromInt(level)) / 12;
    }
    return result;
}
test "lightstyles transport the full intensity range" {
    const t = std.testing;
    var levels = defaults(0);
    levels[32] = 0;
    levels[33] = 25;
    levels[34] = 48;
    const encoded = encode(levels);
    const decoded = try decode(&encoded);
    try t.expectEqual(@as(f32, 0), decoded[32]);
    try t.expectApproxEqAbs(@as(f32, 25.0 / 12.0), decoded[33], 0.0001);
    try t.expectEqual(@as(f32, 4), decoded[34]);
    try t.expectEqual(@as(u8, 0), sample("10", 0));
    try t.expectEqual(sample("amb", 500), sample("amb", 3500));
}
