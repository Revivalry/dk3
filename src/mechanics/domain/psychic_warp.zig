// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the psychic warp ailment. For eight seconds it scatters the victim's
//! horizontal momentum and distorts the view (field of view, roll and a blue wash) while an
//! ambient loop plays. Classes inflict it; this module owns what it does.
const std = @import("std");
pub const Warp = struct { source: u32, until_ms: i64, next_ms: i64, random: u32 };
pub const Visual = struct { fov: f32 = 0, roll: f32 = 0, blend: [4]f32 = @splat(0) };
pub const loop_sound = "global/e_atmospheref.wav";
pub fn warped(until: i64, now: i64) bool {
    return until > now;
}
pub fn visual(until: i64, now: i64) Visual {
    if (!warped(until, now)) return .{};
    const elapsed = std.math.clamp(8000 - (until - now), 0, 8000);
    const count: usize = @intCast(@divTrunc(elapsed, 100));
    var result: Visual = .{};
    for (0..count) |tick| {
        const remaining = 8000 - @as(i64, @intCast(tick + 1)) * 100;
        const fade = std.math.clamp(@as(f32, @floatFromInt(remaining)) / 3000, 0, 1);
        // One-degree phase offset, thirty-degree samples. Bound the complete
        // twelve-sample cycle instead of the reference out-of-bounds thirteenth.
        const angle = @as(f32, @floatFromInt(1 + tick % 12 * 30)) * std.math.pi / 180;
        const sine = @round(@sin(angle) * 1000) * 0.001;
        const cosine = @round(@cos(angle) * 1000) * 0.001;
        if (remaining >= 3000) result.fov += 5 * sine else result.fov -= std.math.clamp(result.fov, -0.5, 0.5);
        result.roll += 6 * fade * cosine;
        const phase = (tick + 1) % 10;
        const color = @as(f32, @floatFromInt(if (phase <= 5) phase * 5 else (10 - phase) * 5)) * 0.03;
        result.blend = .{ 0.25 * (1 - color), @max(0, -0.15 + color), 1 - color, 0.35 * fade };
    }
    return result;
}
test "the warp's view distortion expires" {
    const t = std.testing;
    try t.expectEqualDeep(Visual{}, visual(8100, 8100));
    try t.expect(visual(8100, 1200).blend[3] > 0);
}
