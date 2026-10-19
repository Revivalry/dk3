// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: rats. Pure rats class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{ .{ .kind = .piperat, .traits = .{ .attack = .ground, .amphibious = true } }, .{ .kind = .plague_rat, .traits = .{ .attack = .ground, .amphibious = true } } };
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "rat";
/// Aidata: the plague rat's poison is weapon 2.
pub const ClassTuning = struct { poison: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, kind: class_traits.Kind, _: anytype) !ClassTuning {
    return .{ .poison = if (kind == .plague_rat) try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_") else .{} };
}
pub const pipe_attacks = [_][]const u8{ "ataka", "jumpa" };
pub const plague_attacks = [_][]const u8{ "ataka", "atakb" };
/// Pain: the plague rat's generic handler (two 25% rolls, limit 35); the pipe rat's single 10% roll.
/// Rats keep their run and walk clips in water (the reference never plays `swima`).
pub const plague_pain_chance = 25;
pub const plague_pain_limit = 35;
pub const pipe_pain_chance = 10;
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    launched: bool = false,
    poison: bool = false,
    swimming: bool = false,
    water: u2 = 0,
    evasion_until: ?i64 = null,
    strafe: bool = false,
    strafe_yaw: f32 = 0,
    destination: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.deadline(&self.evasion_until, delta);
    }
};
pub fn inRange(distance: f32, bite: f32, jump: f32, roll: f32) bool {
    return distance < bite or (distance < jump and roll <= 0.3);
}
pub fn poisonous(plague: bool, pose: u3, roll: f32) bool {
    return plague and pose == 0 and roll < 0.2;
}
test "only Plague Rat close attacks choose poison" {
    const t = @import("std").testing;
    try t.expect(poisonous(true, 0, 0.19));
    try t.expect(!poisonous(true, 0, 0.2));
    try t.expect(!poisonous(true, 1, 0));
    try t.expect(!poisonous(false, 0, 0));
    try t.expect(inRange(110, 40, 120, 0.3));
    try t.expect(!inRange(120, 40, 120, 0));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_piperat", .kind = .piperat },
    .{ .classname = "monster_plague_rat", .companion_choices = .{ 0, 1, 1 }, .kind = .plague_rat },
};
