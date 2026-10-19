// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: battleboar. Pure battleboar class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .battleboar, .traits = .{ .sidekicks = .refuse_melee, .attack = .ground, .remains = .{ .robotic = true, .no_blood = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "battleboar";
/// Its rocket: a red-glowing swamp rocket raised 15 units, flown at full speed for 5 s.
pub const rocket_styles = [_]@import("../../../mechanics/policy/actors/missiles.zig").Style{.{ .kind = .battleboar, .model = "models/e1/we_swrocket.dkm", .model_scale = 0.65, .glow = "models/global/e_sflred.sp2", .glow_scale = 0.75, .light_radius = 115, .light_green = 0.15, .sound = "global/e_firetravelb.wav", .origin = .{ .raised = 15 }, .divisor = 1, .accelerates = false, .lifetime_ms = 5000 }};
/// Aidata: the gun is weapon 1 and the rocket weapon 2.
pub const ClassTuning = struct { weapons: [2]@import("../../../mechanics/policy/actors/weapon.zig").Tuning = @splat(.{}) };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const weapons = [2]@import("../../../mechanics/policy/actors/weapon.zig").Tuning{ try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon1_"), try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_") };
    if (weapons[1].speed <= 0) return error.InvalidBoarRocket;
    return .{ .weapons = weapons };
}
pub const attacks = [_][]const u8{ "ataka", "atakb" };
pub const State = struct {
    selected: u1 = 1,
    flashed: bool = false,
    /// While a hit clip plays over its running task (it keeps acting).
    flinch_until_ms: i64 = 0,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try @import("../../../mechanics/policy/actors/saved_time.zig").active(&self.flinch_until_ms, delta);
    }
};
/// Pain: the reference's single roll stops it with `hita` this often (not on the hit that makes
/// a player its enemy); otherwise any hit outside its pain window plays one of its three hit
/// clips (a third each) while it keeps chasing or attacking.
pub const pain_chance = 25;
pub fn hitClip(roll: f32) u2 {
    return if (roll < 1.0 / 3.0) 0 else if (roll < 2.0 / 3.0) 2 else 1;
}
pub const flash_tag = 10010;
pub fn select(distance: f32, roll: f32) u1 {
    return @intFromBool(distance > 120 and roll > 0.15);
}
test "boar hit clips split in thirds" {
    const t = @import("std").testing;
    try t.expectEqual(@as(u2, 0), hitClip(0.2));
    try t.expectEqual(@as(u2, 2), hitClip(0.5));
    try t.expectEqual(@as(u2, 1), hitClip(0.9));
}
test "boar guns remain mandatory at close distance" {
    const t = @import("std").testing;
    try t.expectEqual(@as(u1, 0), select(120, 0.9));
    try t.expectEqual(@as(u1, 0), select(121, 0.15));
    try t.expectEqual(@as(u1, 1), select(121, 0.16));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_battleboar", .nitro_immune = true, .kind = .battleboar },
};
