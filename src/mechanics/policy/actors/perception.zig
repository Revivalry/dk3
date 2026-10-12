// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: close enemies are heard outside the view cone; a class's senses may ignore
//! height or the cone entirely (traits.Senses).
const std = @import("std");
const Senses = @import("traits.zig").Senses;
pub fn distance(senses: Senses, offset: [3]f32) f32 {
    return @sqrt(offset[0] * offset[0] + offset[1] * offset[1] + if (senses.level) @as(f32, 0) else offset[2] * offset[2]);
}
pub fn inCone(senses: Senses, player: bool, horizontal: f32, dot: f32, fov: f32) bool {
    return senses.all_round or !player or horizontal < 256 or dot >= @cos(fov * std.math.pi / 360);
}
test "level senses ignore height, all-round senses ignore facing, and nearby players do not require facing" {
    const t = std.testing;
    const pod: Senses = .{ .level = true, .all_round = true };
    try t.expectEqual(@as(f32, 100), distance(pod, .{ 100, 0, 800 }));
    try t.expect(distance(.{}, .{ 100, 0, 800 }) > 800);
    try t.expect(inCone(pod, true, 500, -1, 90));
    try t.expect(inCone(.{}, true, 128, -1, 90));
    try t.expect(!inCone(.{}, true, 300, -1, 90));
    try t.expect(inCone(.{}, true, 300, 1, 90));
    try t.expect(inCone(.{}, false, 300, -1, 90));
}
