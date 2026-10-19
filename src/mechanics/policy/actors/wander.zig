// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: wander destination choice for classes that roam their start area, and the
//! saved state of a roam (reference GOALTYPE_WANDER).
const std = @import("std");
const saved = @import("saved_time.zig");
pub fn candidate(distance_from_start: f32, active_range: f32, horizontal: f32, vertical: f32, yaw_delta: f32, walk_speed: f32) bool {
    return !(horizontal < walk_speed * 0.2 and @abs(vertical) < 32) and distance_from_start < active_range and @abs(@mod(yaw_delta + 180, 360) - 180) <= 90;
}
/// A walk from node to node with no pause between legs; each leg may take its distance at walk
/// speed plus one second.
pub const Roam = struct {
    /// Where the roam began; legs stay within the class's active range of it.
    home: ?[3]f32 = null,
    destination: ?[3]f32 = null,
    until_ms: i64 = 0,
    pub fn due(self: Roam, position: [3]f32, now: i64, walk_speed: f32) bool {
        const point = self.destination orelse return true;
        const delta = [3]f32{ point[0] - position[0], point[1] - position[1], point[2] - position[2] };
        return now >= self.until_ms or @sqrt(delta[0] * delta[0] + delta[1] * delta[1] + delta[2] * delta[2]) < walk_speed * 0.2;
    }
    pub fn leg(self: *Roam, position: [3]f32, destination: ?[3]f32, now: i64, walk_speed: f32) void {
        self.destination = destination;
        const point = destination orelse return;
        const delta = [3]f32{ point[0] - position[0], point[1] - position[1], point[2] - position[2] };
        self.until_ms = now + @as(i64, @intFromFloat(@sqrt(delta[0] * delta[0] + delta[1] * delta[1] + delta[2] * delta[2]) / @max(walk_speed, 1) * 1000)) + 1000;
    }
    pub fn rebase(self: *Roam, delta: i64) !void {
        try saved.active(&self.until_ms, delta);
    }
    pub fn validate(self: Roam, _: saved.Check) !void {
        if (self.home) |point| if (!saved.point(point)) return error.InvalidSavedActor;
        if (self.destination) |point| if (!saved.point(point)) return error.InvalidSavedActor;
    }
};
test "a roam leg lasts its walk plus a second and ends on arrival" {
    const t = std.testing;
    var roam: Roam = .{};
    try t.expect(roam.due(.{ 0, 0, 0 }, 0, 50));
    roam.leg(.{ 0, 0, 0 }, .{ 100, 0, 0 }, 1000, 50);
    try t.expectEqual(@as(i64, 4000), roam.until_ms);
    try t.expect(!roam.due(.{ 50, 0, 0 }, 2000, 50));
    try t.expect(roam.due(.{ 95, 0, 0 }, 2000, 50));
    try t.expect(roam.due(.{ 50, 0, 0 }, 4000, 50));
}
