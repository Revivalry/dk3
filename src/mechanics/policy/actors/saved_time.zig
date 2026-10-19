// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: what class state needs to survive a save. Rebasing primitives move saved
//! timestamps onto the restoring clock (durations never shift); validation helpers bound restored
//! values. Each class state uses these in its own `rebase`, `validate` and `remapIds`.
const std = @import("std");
const Kind = @import("kinds.zig").Kind;
/// A timestamp that is always set.
pub fn shift(value: *i64, delta: i64) !void {
    value.* = try std.math.add(i64, value.*, delta);
}
/// A timestamp where 0 means unset.
pub fn active(value: *i64, delta: i64) !void {
    if (value.* != 0) try shift(value, delta);
}
/// A timestamp where null means unset.
pub fn deadline(value: *?i64, delta: i64) !void {
    if (value.*) |*at| try shift(at, delta);
}
/// The rebasing primitives bound to one clock offset, for state types that cannot import this
/// module (`state.rebase(clock)`).
pub const Clock = struct {
    delta: i64,
    pub fn shift(self: Clock, value: *i64) !void {
        try shift_(value, self.delta);
    }
    pub fn active(self: Clock, value: *i64) !void {
        try active_(value, self.delta);
    }
    pub fn deadline(self: Clock, value: *?i64) !void {
        try deadline_(value, self.delta);
    }
};
const shift_ = shift;
const active_ = active;
const deadline_ = deadline;
/// Every value finite and within `bound` of zero.
pub fn bounded(values: []const f32, bound: f32) bool {
    for (values) |value| if (!std.math.isFinite(value) or @abs(value) > bound) return false;
    return true;
}
/// A world coordinate.
pub fn point(value: [3]f32) bool {
    return bounded(&value, 1048576);
}
/// What a class state's `validate` may ask about the restored world.
pub const Check = struct {
    /// The actor holding the state is of the state's class.
    owned: bool,
    context: *const anyopaque,
    kind_of: *const fn (*const anyopaque, u32) error{NotAnActor}!?Kind,
    /// The kind of the actor with this persistent id, null when absent.
    pub fn kindOf(self: Check, id: u32) error{NotAnActor}!?Kind {
        return self.kind_of(self.context, id);
    }
};
test "rebasing keeps unset sentinels" {
    var set: i64 = 100;
    var unset: i64 = 0;
    var none: ?i64 = null;
    try active(&set, 50);
    try active(&unset, 50);
    try deadline(&none, 50);
    try std.testing.expectEqual(@as(i64, 150), set);
    try std.testing.expectEqual(@as(i64, 0), unset);
    try std.testing.expect(none == null);
    try std.testing.expect(!point(.{ 0, std.math.inf(f32), 0 }));
}
