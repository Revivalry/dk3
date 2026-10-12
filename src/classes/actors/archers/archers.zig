// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: archers. Centurion and Fletcher own distinct attack and projectile contracts.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{ .{ .kind = .centurion, .traits = .{ .attack = .ground } }, .{ .kind = .fletcher, .traits = .{ .attack = .ground } } };
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "archer";
/// Aidata: the shot is weapon 1; the centurion's melee is weapon 2.
pub const ClassTuning = struct { ranged: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, kind: class_traits.Kind, definition: anytype) !ClassTuning {
    const ranged = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon1_");
    if (ranged.speed <= 0) return error.InvalidArcherProjectile;
    if (kind == .centurion) (try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_")).primary(definition);
    return .{ .ranged = ranged };
}
pub const Kind = enum { centurion, fletcher };
/// The centurion's spear sticks where it lands; the fletcher's bolt is magic.
pub const shaft_styles = [_]@import("../../../mechanics/policy/actors/shafts.zig").Style{
    .{ .kind = .centurion, .model = "models/e2/me_spear.dkm", .attacker_class = "monster_centurion" },
    .{ .kind = .fletcher, .model = "models/e3/we_bolt.dkm", .attacker_class = "monster_fletcher", .touch = .magic },
};
pub const attacks = [_][]const u8{ "ataka", "atakb" };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    ready_ms: i64 = 0,
    clear_ms: i64 = 0,
    sidestep_until: ?i64 = null,
    destination: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.deadline(&self.sidestep_until, delta);
        try saved.active(&self.ready_ms, delta);
        try saved.active(&self.clear_ms, delta);
    }
};
pub fn select(kind: Kind, distance: f32, melee_range: f32) u3 {
    return @intFromBool(distance >= (if (kind == .centurion) melee_range else 400));
}
/// The centurion engages within the reach of its current weapon: the punch it starts with (and
/// picks up again for each choice) until it throws a spear; the fletcher always shoots.
pub fn reach(kind: Kind, last_pose: u3, melee_range: f32, ranged_range: f32) f32 {
    return if (kind == .centurion and last_pose == 0) melee_range else ranged_range;
}
/// The centurion's pain is a single 30% roll (the reference's `AI_StartPain`).
pub const centurion_pain_chance = 30;
test "Centurion closes to punch reach until it throws" {
    const t = @import("std").testing;
    try t.expectEqual(@as(f32, 90), reach(.centurion, 0, 90, 700));
    try t.expectEqual(@as(f32, 700), reach(.centurion, 1, 90, 700));
    try t.expectEqual(@as(f32, 700), reach(.fletcher, 0, 90, 700));
}
test "Centurion melee and Fletcher far shots have different boundaries" {
    const t = @import("std").testing;
    try t.expectEqual(@as(u3, 0), select(.centurion, 89, 90));
    try t.expectEqual(@as(u3, 1), select(.centurion, 90, 90));
    try t.expectEqual(@as(u3, 0), select(.fletcher, 399, 1000));
    try t.expectEqual(@as(u3, 1), select(.fletcher, 400, 1000));
    try t.expectEqual(@as(i64, 10000), @import("../../../mechanics/policy/actors/shafts.zig").flightTime(.fletcher));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_centurion", .kind = .centurion },
    .{ .classname = "monster_fletcher", .kind = .fletcher },
};
