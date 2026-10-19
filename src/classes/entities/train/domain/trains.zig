// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: train. Path-leg timing and dwell have one owner, independent of engine trajectories.
const std = @import("std");
const v = @import("../../../../core/domain/vector.zig");
const Motion = @import("../../../../core/domain/movers.zig").Motion;
const Deadline = @import("../../../../core/domain/time.zig").Deadline;
pub const Phase = enum { initializing, paused, moving, dwelling, teleporting };
pub const Train = struct {
    phase: Phase = .initializing,
    destination: u32 = 0,
    arrival_pending: bool = false,
    next_target: []const u8 = "",
    owner: u32 = 0,
    speed: f32 = 100,
    departure_wait_ms: i32 = 0,
    position: Motion = .{},
    angles: Motion = .{},
    action: Deadline = .{},
    force: bool = false,
    damage: i32 = 2,
    pub fn reached(self: *Train, now: i64, triggered_corner: bool, corner_health: f32) !void {
        const paused = self.departure_wait_ms <= 0 and (triggered_corner or self.departure_wait_ms < 0 or corner_health > 0);
        self.phase = if (paused or self.next_target.len == 0) .paused else .dwelling;
        self.action = if (self.phase == .dwelling) try Deadline.after(now, @as(i64, self.departure_wait_ms) + 1) else .{};
    }
    pub fn canUse(self: Train, triggered_corner: bool) bool {
        if (self.phase == .moving or self.phase == .teleporting) return false;
        return !(triggered_corner and self.action.at_ms != null);
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Train, map: anytype) !void {
        try map.fields(self, .{ "destination", "owner" });
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Train, clock: anytype) !void {
        try clock.shift(&self.position.start_ms);
        try clock.shift(&self.angles.start_ms);
        try clock.deadline(&self.action.at_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Train, check: anytype) !void {
        _ = check;
        if (self.position.duration_ms <= 0 or self.angles.duration_ms <= 0 or self.speed <= 0) return error.InvalidSavedTrain;
    }
};
/// Whether a train leaves its first corner as soon as it is placed there (reference train_find):
/// START_ON, an unnamed train whose first corner does not wait for a trigger, or a named train
/// whose first corner gives it health. A START_ON train leaves even a wait-for-trigger corner;
/// later arrivals there do wait (e1m5a's `4am` carries its body parts down the belt at load).
pub fn startsAtOnce(start_on: bool, named: bool, corner_waits: bool, corner_health: f32) bool {
    return start_on or (!named and !corner_waits) or (named and corner_health > 0);
}

test "a START_ON train leaves even a wait-for-trigger first corner; a named one waits" {
    try std.testing.expect(startsAtOnce(true, true, true, 0));
    try std.testing.expect(startsAtOnce(false, false, false, 0));
    try std.testing.expect(!startsAtOnce(false, false, true, 0));
    try std.testing.expect(!startsAtOnce(false, true, false, 0));
    try std.testing.expect(startsAtOnce(false, true, false, 50));
}

pub const Leg = struct { duration_ms: i32, angular_end: v.Vec3 };
pub fn leg(from: v.Vec3, to: v.Vec3, angles: v.Vec3, speed: f32, rotation: v.Vec3, rates: v.Vec3, flags: u32) !Leg {
    if (!std.math.isFinite(speed) or speed <= 0) return error.InvalidTrainSpeed;
    var duration = v.length(v.add(to, v.scale(from, -1))) * 1000 / speed;
    for (rotation, rates) |amount, rate| {
        if (!std.math.isFinite(amount) or !std.math.isFinite(rate)) return error.InvalidTrainRotation;
        if (rate != 0) duration = @max(duration, @abs(amount) * 1000 / @abs(rate));
    }
    if (!std.math.isFinite(duration) or duration >= 2147483648) return error.InvalidTrainDuration;
    const milliseconds = @max(1, @as(i32, @intFromFloat(duration)));
    var angular_end = angles;
    for (&angular_end, rotation, rates, 0..) |*angle, amount, rate, i| {
        const flag: u32 = if (i == 2) 1 else if (i == 0) 2 else 4;
        angle.* += if (flags & flag != 0) rate * @as(f32, @floatFromInt(milliseconds)) * 0.001 else amount;
    }
    return .{ .duration_ms = milliseconds, .angular_end = angular_end };
}
test "departure dwell wins over destination trigger and ignores a repeated call" {
    var train: Train = .{ .phase = .moving, .next_target = "bottom", .departure_wait_ms = 10000 };
    try train.reached(2000, true, 0);
    try std.testing.expectEqual(Phase.dwelling, train.phase);
    try std.testing.expectEqual(@as(?i64, 12001), train.action.at_ms);
    try std.testing.expect(!train.canUse(true));
    try std.testing.expect(!train.action.due(12000));
    try std.testing.expect(train.action.due(12001));
    train.departure_wait_ms = 0;
    try train.reached(13000, true, 0);
    try std.testing.expectEqual(Phase.paused, train.phase);
    try std.testing.expect(train.canUse(true));
}
test "rotation can extend travel and continuous axes use authored rates" {
    const value = try leg(.{ 0, 0, 0 }, .{ 100, 0, 0 }, .{ 0, 0, 0 }, 100, .{ 90, 0, 0 }, .{ 30, 60, 0 }, 4);
    try std.testing.expectEqual(@as(i32, 3000), value.duration_ms);
    for (value.angular_end, [_]f32{ 90, 180, 0 }) |actual, expected| try std.testing.expectApproxEqAbs(expected, actual, 0.0001);
}
