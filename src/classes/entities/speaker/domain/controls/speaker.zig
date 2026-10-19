// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: speaker. An authored speaker's loop, trigger and random-delay state.
const std = @import("std");
const Parameters = @import("../../../../../core/domain/audio.zig").Parameters;
pub const controls = .{.{ .tag = "speaker", .State = State }};
pub const State = struct {
    sounds: [6]u16 = @splat(0),
    count: u4 = 0,
    parameters: Parameters = .{},
    loopable: bool = false,
    active: bool = false,
    reliable: bool = false,
    delay_secs: u32 = 0,
    timed: bool = false,
    minimum_secs: u32 = 0,
    next_ms: ?i64 = null,
    random: u32 = 1,
    pub fn start(self: *State, flags: u32, named: bool, now: i64) void {
        self.parameters.nondirectional = flags & 8 != 0;
        self.reliable = flags & 4 != 0;
        self.active = self.count <= 1 and flags & 1 != 0;
        self.loopable = self.active or flags & 2 != 0;
        if (!self.active) {
            if (self.count > 1 and self.delay_secs == 0 and !named) self.delay_secs = 3;
            self.timed = self.delay_secs > 0;
            if (self.timed and flags & (16 | 2) == 0) self.next_ms = now + 1000;
        }
    }
    pub fn draw(self: *State, limit: u32) u32 {
        self.random = self.random *% 1664525 +% 1013904223;
        return if (limit == 0) 0 else (self.random >> 8) % limit;
    }
    pub fn interval(self: *State) i64 {
        return @max(100, @as(i64, @max(self.minimum_secs, self.draw(self.delay_secs))) * 1000);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.deadline(&self.next_ms);
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
};

test "speaker loop eligibility, start-off and random delay survive a copy" {
    const t = std.testing;
    var loop: State = .{ .count = 1 };
    loop.start(1, false, 2000);
    try t.expect(loop.active and loop.loopable and loop.next_ms == null);
    var random: State = .{ .count = 3, .minimum_secs = 2 };
    random.start(1, false, 2000);
    try t.expect(!random.active and !random.loopable);
    try t.expectEqual(@as(u32, 3), random.delay_secs);
    try t.expectEqual(@as(?i64, 3000), random.next_ms);
    var restored = random;
    for (0..16) |_| {
        try t.expectEqual(random.draw(3), restored.draw(3));
        const interval = random.interval();
        try t.expectEqual(interval, restored.interval());
        try t.expectEqual(@as(i64, 2000), interval);
    }
    var triggered: State = .{ .count = 3 };
    triggered.start(4 | 8 | 16, true, 2000);
    try t.expect(triggered.reliable and triggered.parameters.nondirectional and triggered.next_ms == null and triggered.delay_secs == 0);
    var off: State = .{ .count = 1, .delay_secs = 10 };
    off.start(2, false, 2000);
    try t.expect(off.loopable and !off.active and off.next_ms == null);
}
