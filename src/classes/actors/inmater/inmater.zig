// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: inmater. Pure inmater class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .inmater, .traits = .{ .sidekicks = .refuse_melee, .attack = .ground, .remains = .{ .robotic = true, .no_blood = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "inmater";
/// A hit (not the acquiring one) flinches with `hita` this often, with no damage threshold.
pub const pain_chance = 0.05;
/// Aidata: the laser is weapon 2.
pub const ClassTuning = struct { laser: @import("../../../mechanics/policy/actors/laser.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    return .{ .laser = try @import("../../../mechanics/policy/actors/laser.zig").Tuning.parse(row, "weapon2_") };
}
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc" };
pub const sweep = [_]struct { frame: u16, offset: [3]f32 }{
    .{ .frame = 10, .offset = .{ 5, 16, 16 } },   .{ .frame = 14, .offset = .{ -3, 16, 16 } },
    .{ .frame = 18, .offset = .{ -11, 16, 16 } }, .{ .frame = 22, .offset = .{ -19, 16, 16 } },
    .{ .frame = 26, .offset = .{ -27, 16, 16 } }, .{ .frame = 36, .offset = .{ -18, 16, 16 } },
};
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    pulse: u3 = 0,
    sidestep_until: ?i64 = null,
    destination: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.deadline(&self.sidestep_until, delta);
    }
};
pub fn select(distance: f32, roll: f32) u3 {
    return if (distance <= 128) 1 else if (roll < 0.75) 0 else 2;
}
/// It engages within the reach of the weapon it used last (the punch after `atakb`, else the
/// laser, which it starts with).
pub fn reach(last_pose: u3, punch: f32, laser: f32) f32 {
    return if (last_pose == 1) punch else laser;
}
test "Inmater engages within its last weapon's reach" {
    const t = @import("std").testing;
    try t.expectEqual(@as(f32, 800), reach(0, 160, 800));
    try t.expectEqual(@as(f32, 800), reach(2, 160, 800));
    try t.expectEqual(@as(f32, 160), reach(1, 160, 800));
}
test "Inmater's three attacks retain the melee boundary and sweep probability" {
    const t = @import("std").testing;
    try t.expectEqual(@as(u3, 1), select(128, 0.9));
    try t.expectEqual(@as(u3, 0), select(129, 0.74));
    try t.expectEqual(@as(u3, 2), select(129, 0.75));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_inmater", .nitro_immune = true, .kind = .inmater },
};
