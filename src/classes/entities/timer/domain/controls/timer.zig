// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: timer. An authored timer's cadence: a fixed wait with a seeded random variance.
pub const controls = .{.{ .tag = "timer", .State = State }};
pub const State = struct {
    wait_ms: i64 = 1000,
    variance_ms: i64 = 0,
    delay_ms: i64 = 0,
    next_ms: ?i64 = null,
    activator: u32 = 0,
    random: u32 = 1,
    once: bool = false,
    pub fn interval(self: *State) i64 {
        self.random = self.random *% 1664525 +% 1013904223;
        const fraction = @as(f32, @floatFromInt(self.random >> 8)) / 16777216;
        return self.wait_ms + @as(i64, @intFromFloat((fraction * 2 - 1) * @as(f32, @floatFromInt(self.variance_ms))));
    }
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.activator);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.deadline(&self.next_ms);
    }
};

test "timer random cadence is bounded and resumes the same sequence from saved state" {
    const t = @import("std").testing;
    var timer: State = .{ .wait_ms = 18000, .variance_ms = 3000, .random = 42 };
    for (0..8) |_| {
        const interval = timer.interval();
        try t.expect(interval >= 15000 and interval < 21000);
    }
    var restored = timer;
    for (0..8) |_| try t.expectEqual(timer.interval(), restored.interval());
}
