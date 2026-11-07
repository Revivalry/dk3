// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Progression and effective attributes shared by simulation and prediction.
const std = @import("std");
pub fn experienceThreshold(level: i32) i32 {
    if (level <= 0) return 0;
    const previous = level - 1;
    if (previous < 5) return @as(i32, 500) << @intCast(previous);
    if (previous < 8) return (previous - 2) * 4000;
    if (previous < 24) return (previous - 3) * 5000;
    return 110000;
}
pub fn attribute(base: i32, until: i64, now: i64) i32 {
    return if (until > now) 5 else std.math.clamp(base, 0, 5);
}
pub fn movementFactor(level: i32) f32 {
    return 1 + 0.08 * @as(f32, @floatFromInt(level));
}
pub fn acrobaticsFactor(level: i32, multiplayer: bool) f32 {
    return 1 + (if (multiplayer) @as(f32, 0.3) else 0.15) * @as(f32, @floatFromInt(std.math.clamp(level, 0, 5)));
}
pub const Action = enum { jump, attack };
pub const ActionSound = struct { path: []const u8, volume: f32 };
pub fn actionSound(action: Action, level: i32) ?ActionSound {
    const effective = std.math.clamp(level, 0, 5);
    if (effective == 0) return null;
    return switch (action) {
        .jump => .{ .path = "global/acroboost.wav", .volume = if (effective == 5) 1 else @as(f32, @floatFromInt(effective)) * 0.1 },
        .attack => .{ .path = "global/a_powerquad.wav", .volume = @as(f32, @floatFromInt(effective)) * 0.2 },
    };
}
pub fn powerFactor(level: i32) f32 {
    return 1 + 0.3 * @as(f32, @floatFromInt(level));
}
test "progression thresholds and boosts preserve authored steps" {
    try std.testing.expectEqual(@as(i32, 500), experienceThreshold(1));
    try std.testing.expectEqual(@as(i32, 16000), experienceThreshold(7));
    try std.testing.expectEqual(@as(i32, 100000), experienceThreshold(24));
    try std.testing.expectEqual(@as(i32, 110000), experienceThreshold(25));
    try std.testing.expectEqual(@as(i32, 5), attribute(5, 100, 0));
    try std.testing.expectEqual(@as(i32, 2), attribute(2, 100, 100));
}
test "acrobatics uses its own campaign and multiplayer jump increments" {
    try std.testing.expectEqual(@as(f32, 1), acrobaticsFactor(0, false));
    try std.testing.expectEqual(@as(f32, 1.75), acrobaticsFactor(5, false));
    try std.testing.expectEqual(@as(f32, 2.5), acrobaticsFactor(5, true));
    try std.testing.expect(actionSound(.jump, 0) == null);
    try std.testing.expectEqualStrings("global/acroboost.wav", actionSound(.jump, 5).?.path);
    try std.testing.expectEqual(@as(f32, 1), actionSound(.jump, 5).?.volume);
    try std.testing.expectEqualStrings("global/a_powerquad.wav", actionSound(.attack, 5).?.path);
}
