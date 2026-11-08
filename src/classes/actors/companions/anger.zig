// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Hidden provocation and nonlethal punishment policy.
pub const State = struct {
    value: u8 = 0,
    cooldown_ms: ?i64 = null,
    last_hit_ms: ?i64 = null,
    strike_ms: ?i64 = null,
    retaliating: bool = false,
    /// Delayed rounds remain nonlethal after forgiveness.
    mercy: bool = false,
    pub fn cool(self: *State, now: i64) void {
        if (self.retaliating) return;
        const due = self.cooldown_ms orelse return;
        if (now < due) return;
        const steps = 1 + @divTrunc(now - due, 5000);
        self.value -|= @intCast(@min(100, steps * 5));
        self.cooldown_ms = if (self.value == 0) null else due + steps * 5000;
    }
    /// Pellets arriving in one simulation instant are one provocation.
    pub fn hit(self: *State, now: i64) bool {
        self.cool(now);
        if (self.retaliating or self.last_hit_ms == now) return false;
        self.last_hit_ms = now;
        self.cooldown_ms = now + 5000;
        self.value = @min(100, self.value + 5);
        return self.value == 100;
    }
    pub fn begin(self: *State) void {
        self.value = 100;
        self.retaliating = true;
        self.mercy = true;
        self.cooldown_ms = null;
    }
    pub fn forgive(self: *State) void {
        const mercy = self.mercy;
        self.* = .{ .mercy = mercy };
    }
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.deadline(&self.cooldown_ms);
        try clock.deadline(&self.last_hit_ms);
        try clock.deadline(&self.strike_ms);
    }
    pub fn valid(self: State) bool {
        return self.value <= 100 and (!self.retaliating or (self.value == 100 and self.mercy));
    }
};

test "twenty distinct hits provoke the party; pellets do not multiply anger" {
    const t = @import("std").testing;
    var state: State = .{};
    for (0..20) |hit| {
        const now: i64 = @intCast(hit * 100);
        try t.expectEqual(hit == 19, state.hit(now));
        try t.expect(!state.hit(now));
        try t.expectEqual(@as(u8, @intCast((hit + 1) * 5)), state.value);
    }
    state.begin();
    state.cool(100000);
    try t.expect(state.retaliating and state.value == 100);
    state.forgive();
    try t.expect(state.value == 0 and !state.retaliating and state.mercy);
}
test "cooling starts five seconds after the latest hit and catches up by whole intervals" {
    const t = @import("std").testing;
    var state: State = .{};
    _ = state.hit(0);
    _ = state.hit(1000);
    state.cool(5999);
    try t.expectEqual(@as(u8, 10), state.value);
    state.cool(6000);
    try t.expectEqual(@as(u8, 5), state.value);
    state.cool(11000);
    try t.expectEqual(@as(u8, 0), state.value);
    try t.expect(state.valid());
}
