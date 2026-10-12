// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the campaign difficulty as the reference's three skill tiers. `g_spSkill` is
//! Ronin 1, Samurai 3 or Shogun 5; the reference's skill 0, 1 or 2. Every class reads its skill
//! tables through `tier`, never by comparing `g_spSkill` itself.
const std = @import("std");
/// The reference's skill: 0 (Ronin and below), 1 (Samurai), 2 (Shogun and above).
pub fn tier(skill: i32) u2 {
    return if (skill <= 2) 0 else if (skill == 3) 1 else 2;
}
/// The aidata multiplier for health, distances, speeds and damage (0.75, 1 or 1.25).
pub fn factor(skill: i32) f32 {
    return ([_]f32{ 0.75, 1, 1.25 })[tier(skill)];
}
/// Picks a class's per-skill value.
pub fn pick(comptime T: type, skill: i32, values: [3]T) T {
    return values[tier(skill)];
}

test "the campaign skills map to the reference's three tiers" {
    try std.testing.expectEqual(@as(u2, 0), tier(1));
    try std.testing.expectEqual(@as(u2, 1), tier(3));
    try std.testing.expectEqual(@as(u2, 2), tier(5));
    try std.testing.expectEqual(@as(f32, 1.25), factor(5));
    try std.testing.expectEqual(@as(i64, 10000), pick(i64, 3, .{ 15000, 10000, 5000 }));
}
