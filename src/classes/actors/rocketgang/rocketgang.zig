// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: rocketgang. Pure rocketgang class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .rocketdude, .traits = .{ .attack = .ground } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "rocketgang";
/// Its rocket leaves the launcher on its shoulder, turned up and aside from the target.
pub const rocket_styles = [_]@import("../../../mechanics/policy/actors/missiles.zig").Style{.{ .kind = .rocketdude, .model_scale = 2, .origin = .{ .turned = .{ .pitch = -65, .yaw = -55, .distance = 25 } } }};
/// Aidata: the two rockets are weapons 1 and 2.
pub const ClassTuning = struct { rockets: [2]@import("../../../mechanics/policy/actors/weapon.zig").Tuning = @splat(.{}) };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const rockets = [2]@import("../../../mechanics/policy/actors/weapon.zig").Tuning{ try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon1_"), try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_") };
    for (rockets) |rocket| if (rocket.speed <= 0) return error.InvalidGangRocket;
    return .{ .rockets = rockets };
}
pub const attacks = [_][]const u8{ "ataka", "atakb" };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    selected: u1 = 1,
    ready_ms: i64 = 0,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.ready_ms, delta);
    }
};
pub fn select(distance: f32) u1 {
    return @intFromBool(distance >= 500);
}
test "gang kneels at five hundred units" {
    const t = @import("std").testing;
    try t.expectEqual(@as(u1, 0), select(499));
    try t.expectEqual(@as(u1, 1), select(500));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_rocketdude", .kind = .rocketdude },
};
