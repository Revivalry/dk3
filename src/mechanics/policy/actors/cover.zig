// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: fighting from cover (reference GOALTYPE_TAKECOVER). A class that supports
//! cover shoots only while its enemy is completely visible, otherwise runs to the closest hide
//! node that its enemy cannot see, waits there, and now and then runs back out to look. The
//! class supplies its own shot and cooldown; these are the shared rules and their saved state.
const std = @import("std");
const saved = @import("saved_time.zig");
/// Hide nodes farther than this are never chosen.
pub const hide_radius: f32 = 768;
/// Sight lines leave from, and hide-node checks pass, both shoulders: this fraction of the body
/// width to each side.
pub const shoulder_width: f32 = 0.6;
/// Sight lines run between points this fraction up each body.
pub const sight_height: f32 = 0.4;
/// Authored node flag of a hide node.
pub const hide_node: u32 = 0x1000;
/// While no hide node qualifies, the search repeats at this period (native bound on the
/// reference's per-think search).
pub const search_period_ms: i64 = 500;
/// Horizontal distance at which a cover run has arrived.
pub const arrival: f32 = 20;
/// Every period the actor may run back out toward its enemy, with this chance.
pub const look_period_ms: i64 = 4000;
pub const look_chance: f32 = 0.5;
/// A look ends after one period even if the enemy never came into full view (native bound; the
/// reference relied on its stuck detector).
pub const look_limit_ms: i64 = 4000;
/// After a shot from cover the reference rests 2–8 s before the next (its attack-finished time).
pub fn rest(roll: f32) i64 {
    return 2000 + @as(i64, @intFromFloat(roll * 6000));
}
pub const State = struct {
    /// The hide node being run to.
    destination: ?[3]f32 = null,
    /// Running back out toward the enemy until this time.
    looking_until_ms: ?i64 = null,
    /// When the next look may start.
    look_ms: i64 = 0,
    /// When the next hide-node search may run.
    search_ms: i64 = 0,
    pub fn moving(self: State) bool {
        return self.destination != null or self.looking_until_ms != null;
    }
    pub fn reset(self: *State) void {
        self.destination = null;
        self.looking_until_ms = null;
    }
    /// Whether a look starts now; rolls once per period.
    pub fn look(self: *State, now: i64, roll: f32) bool {
        if (now < self.look_ms) return false;
        self.look_ms = now + look_period_ms;
        if (roll <= look_chance) return false;
        self.destination = null;
        self.looking_until_ms = now + look_limit_ms;
        return true;
    }
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.deadline(&self.looking_until_ms, delta);
        try saved.active(&self.look_ms, delta);
        try saved.active(&self.search_ms, delta);
    }
    pub fn validate(self: State, _: saved.Check) !void {
        if (self.destination) |point| if (!saved.point(point)) return error.InvalidSavedActor;
    }
};
/// The two shoulder points of a body of `width` at `center`, across the direction `toward`.
pub fn shoulders(center: [3]f32, toward: [3]f32, width: f32) [2][3]f32 {
    const length = @sqrt(toward[0] * toward[0] + toward[1] * toward[1]);
    if (length == 0) return .{ center, center };
    const offset = width * shoulder_width;
    const side = [3]f32{ -toward[1] / length * offset, toward[0] / length * offset, 0 };
    return .{ .{ center[0] + side[0], center[1] + side[1], center[2] }, .{ center[0] - side[0], center[1] - side[1], center[2] } };
}
/// The sight point of a body standing at `origin` with vertical extent `mins_z`..`maxs_z`.
pub fn sightPoint(origin: [3]f32, mins_z: f32, maxs_z: f32) [3]f32 {
    return .{ origin[0], origin[1], origin[2] + mins_z + (maxs_z - mins_z) * sight_height };
}
pub fn arrived(position: [3]f32, destination: [3]f32) bool {
    const dx = destination[0] - position[0];
    const dy = destination[1] - position[1];
    return dx * dx + dy * dy <= arrival * arrival and @abs(destination[2] - position[2]) < 32;
}
test "a shot from cover is followed by a 2 to 8 s rest" {
    try std.testing.expectEqual(@as(i64, 2000), rest(0));
    try std.testing.expectEqual(@as(i64, 7999), rest(0.99999));
}
test "shoulders sit across the line of sight, a look rolls once per period" {
    const t = std.testing;
    const pair = shoulders(.{ 0, 0, 0 }, .{ 10, 0, 0 }, 32);
    try t.expectApproxEqAbs(@as(f32, 19.2), pair[0][1], 0.001);
    try t.expectApproxEqAbs(@as(f32, -19.2), pair[1][1], 0.001);
    try t.expectEqual(@as(f32, 0), pair[0][0]);
    var state: State = .{};
    try t.expect(!state.look(0, 0.4));
    try t.expect(!state.look(3999, 0.9));
    try t.expect(state.look(4000, 0.9));
    try t.expectEqual(@as(?i64, 8000), state.looking_until_ms);
    try t.expect(arrived(.{ 0, 0, 0 }, .{ 12, 16, 8 }) and !arrived(.{ 0, 0, 0 }, .{ 15, 15, 0 }));
}
