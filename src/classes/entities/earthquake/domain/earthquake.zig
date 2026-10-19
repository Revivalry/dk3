// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: earthquake. Pure rules of the earthquake map entity class.
/// The world-control states this class owns, by saved tag (control_classes.zig).
pub const controls = .{.{ .tag = "earthquake", .State = State }};
pub const State = struct {
    severity: f32 = 200,
    radius: f32 = 200,
    damage: f32 = 0,
    duration_ms: i64 = 5000,
    until_ms: i64 = 0,
    next_ms: ?i64 = null,
    sound: u16 = 0,
    parameters: @import("../../../../core/domain/audio.zig").Parameters = .{ .volume = 216.0 / 255.0, .minimum = 2000, .maximum = 2024 },
    pub fn strength(self: State, distance: f32) f32 {
        return @max(0, self.radius - distance) * 0.01 * self.severity * 0.05 * 0.08;
    }
    pub fn damagePerPulse(self: State) i32 {
        return @intFromFloat(self.damage * 0.1 * self.severity * 0.05);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.deadline(&self.next_ms);
        try clock.shift(&self.until_ms);
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
};
/// Reference kicks reach their peak in 50 ms and return over the following 100 ms.
pub fn kickScale(age_ms: i64) f32 {
    if (age_ms < 0 or age_ms >= 150) return 0;
    return if (age_ms < 50) @as(f32, @floatFromInt(age_ms)) / 50 else 1 - @as(f32, @floatFromInt(age_ms - 50)) / 100;
}
test "quake distance affects view kick but not authored damage; kick envelope returns to zero" {
    const t = @import("std").testing;
    const state: State = .{ .severity = 250, .radius = 512, .damage = 10 };
    try t.expectApproxEqAbs(@as(f32, 5.12), state.strength(0), 0.0001);
    try t.expectEqual(@as(f32, 0), state.strength(512));
    try t.expectEqual(@as(i32, 12), state.damagePerPulse());
    try t.expectEqual(@as(f32, 0), kickScale(0));
    try t.expectEqual(@as(f32, 1), kickScale(50));
    try t.expectEqual(@as(f32, 0.5), kickScale(100));
    try t.expectEqual(@as(f32, 0), kickScale(150));
}
