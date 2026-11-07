// SPDX-License-Identifier: GPL-2.0-or-later
//! item-class: antidote. Finite Episode 2 protection against slime and poison.
const std = @import("std");
pub const state_field = "antidote";
pub const pickup_kind = .antidote;
pub const State = struct {
    points: i32 = 0,
    pub fn validate(self: State) !void {
        if (self.points < 0) return error.InvalidSavedProtection;
    }
    pub fn collect(self: *State) void {
        self.points +|= 100;
    }
    pub fn protectsToxins(self: State, episode: u8) bool {
        return episode == 2 and self.points > 0;
    }
    /// The last protected hit consumes the remainder and is fully absorbed.
    pub fn absorb(self: *State, damage: i32, episode: u8, toxic: bool) bool {
        if (damage <= 0 or !toxic or !self.protectsToxins(episode)) return false;
        self.points = @max(0, self.points - damage);
        return true;
    }
};
pub fn acquire(receiver: anytype, _: i64) bool {
    receiver.character.item_protection.antidote.collect();
    return true;
}
test "bottles stack, protect only Episode 2 toxins, and absorb their last complete hit" {
    var state: State = .{};
    state.collect();
    state.collect();
    try std.testing.expectEqual(@as(i32, 200), state.points);
    try std.testing.expect(!state.absorb(30, 1, true));
    try std.testing.expect(!state.absorb(30, 2, false));
    try std.testing.expect(state.absorb(12, 2, true));
    try std.testing.expectEqual(@as(i32, 188), state.points);
    try std.testing.expect(state.absorb(200, 2, true));
    try std.testing.expectEqual(@as(i32, 0), state.points);
    try std.testing.expect(!state.absorb(1, 2, true));
    try std.testing.expectError(error.InvalidSavedProtection, (State{ .points = -1 }).validate());
}
