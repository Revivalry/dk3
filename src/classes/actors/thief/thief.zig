// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: thief. Pure thief class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .thief, .traits = .{ .attack = .ground } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "thief";
/// Aidata: the thrown knife is weapon 2.
pub const ClassTuning = struct { knife: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const knife = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_");
    if (knife.speed <= 0) return error.InvalidThiefKnife;
    return .{ .knife = knife };
}
pub const attacks = [_][]const u8{ "ataka", "atakb" };
/// Its knife spins end over end and lands with the reference's axe touch.
pub const shaft_styles = [_]@import("../../../mechanics/policy/actors/shafts.zig").Style{.{ .kind = .thief, .model = "models/e2/me_thief.dkm", .attacker_class = "monster_thief", .touch = .axe, .spin = 300 }};
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    next_attack_ms: i64 = 0,
    sidestep_until: ?i64 = null,
    destination: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.next_attack_ms, delta);
        try saved.deadline(&self.sidestep_until, delta);
    }
};
pub fn select(distance: f32) u3 {
    return if (distance > 80) 0 else 1;
}
pub const inRange = @import("../../../mechanics/policy/actors/thrown_range.zig").inRange;
test "thief throws only beyond eighty units" {
    const t = @import("std").testing;
    try t.expectEqual(@as(u3, 1), select(80));
    try t.expectEqual(@as(u3, 0), select(81));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_thief", .kind = .thief },
};
