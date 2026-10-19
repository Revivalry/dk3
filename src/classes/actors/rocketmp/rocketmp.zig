// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: rocketmp. Rocket MP keeps knife, stationary rockets and pursuing attacks distinct.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .rocketmp, .traits = .{ .attack = .ground } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "rocketmp";
/// Its rockets leave the left launcher (the reference never authors a right-hand shot).
pub const rocket_styles = [_]@import("../../../mechanics/policy/actors/missiles.zig").Style{
    .{ .kind = .mp_left, .model_scale = 0.75, .glow_scale = 1, .origin = .{ .beside = .{ .right = -8, .up = 30 } }, .faces_launcher = true, .divisor = 4 },
    .{ .kind = .mp_right, .model_scale = 0.75, .glow_scale = 1, .origin = .{ .beside = .{ .right = 12, .up = 30 } }, .faces_launcher = true, .divisor = 4 },
};
/// Aidata: the left and right rockets are weapons 2 and 3.
pub const ClassTuning = struct { rockets: [2]@import("../../../mechanics/policy/actors/weapon.zig").Tuning = @splat(.{}) };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const rockets = [2]@import("../../../mechanics/policy/actors/weapon.zig").Tuning{ try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_"), try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon3_") };
    for (rockets) |rocket| if (rocket.speed <= 0) return error.InvalidMpRocket;
    return .{ .rockets = rockets };
}
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc" };
/// Its chase-evade runs for one second.
pub const evade_ms = 1000;
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    ready_ms: i64 = 0,
    /// A mobile MP opens in its chasing attack (running rocket, else knife).
    pursuing: bool = true,
    evade_until: ?i64 = null,
    destination: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.ready_ms, delta);
        try saved.deadline(&self.evade_until, delta);
    }
};
pub fn select(distance: f32, roll: f32, stationary: bool) ?u3 {
    if (stationary or distance > 120) return 0;
    if (distance < 120 and roll < 0.5) return 1;
    return null;
}
pub fn chase(ready: bool) u3 {
    return if (ready) 2 else 1;
}
test "rocket MP close attack alternates knife and chase evade" {
    const t = @import("std").testing;
    try t.expectEqual(@as(?u3, 1), select(119, 0.49, false));
    try t.expectEqual(@as(?u3, null), select(119, 0.5, false));
    try t.expectEqual(@as(?u3, 0), select(119, 0.5, true));
    try t.expectEqual(@as(?u3, null), select(120, 0, false));
    try t.expectEqual(@as(u3, 1), chase(false));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_rocketmp", .kind = .rocketmp },
};
