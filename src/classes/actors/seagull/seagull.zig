// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: seagull. Pure seagull class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .seagull, .traits = .{ .ambient = true, .remains = .{ .always = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "seagull";
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    motion_ms: ?i64 = null,
    wave: u4 = 0,
    bobbing: bool = false,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.deadline(&self.motion_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (self.wave > 9) return error.InvalidSavedActor;
    }
};
pub fn bob(index: u4) f32 {
    const std = @import("std");
    const sample: u16 = @intFromFloat(@as(f32, @floatFromInt(index)) * 1.25);
    // Derive the sampled sine mathematically; no private lookup table is used.
    return 12.5 * @round(@sin(@as(f32, @floatFromInt(1 + sample * 30)) * std.math.pi / 180) * 1000) * 0.001;
}
test "seagull wave wraps before the next reference sample exceeds the cycle" {
    const t = @import("std").testing;
    var state: State = .{};
    for (0..10) |_| state.wave = if (state.wave == 9) 0 else state.wave + 1;
    try t.expectEqual(@as(u4, 0), state.wave);
    try t.expect(bob(2) > 10);
    try t.expect(bob(7) < -10);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "e_seagull", .kind = .seagull, .idle = "stand", .run = "flya" },
};
