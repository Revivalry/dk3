// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: garroth. Pure garroth class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .garroth, .traits = .{ .sidekicks = .refuse_melee, .attack = .sequence, .remains = .{ .never = true } } }};
/// Pain: the reference's single 5% roll (`hita`).
pub const pain_chance = 5;
/// The chance it attacks when it could (instead of pausing), by skill.
pub const attack_chance = [3]f32{ 0.3, 0.7, 0.85 };
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "garroth";
/// Aidata: the stave is weapon 2 and the wisp weapon 3.
pub const ClassTuning = struct { stave: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{}, wisp: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    return .{ .stave = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_"), .wisp = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon3_") };
}
pub const attacks = [_][]const u8{ "ataka", "atakc", "amba" };
pub const Weapon = enum { none, punch, stave, wisp, summon };
pub const State = struct { weapon: Weapon = .none };
pub fn inRange(distance: f32, melee: f32) bool {
    return if (distance < 200) distance < melee else distance <= 600;
}
pub fn choose(distance: f32, melee: f32, stave: f32, wisp: f32, choice: u2) Weapon {
    if (distance < melee) return .punch;
    return switch (choice) {
        1 => if (distance <= stave) .stave else if (distance <= wisp) .wisp else .summon,
        2 => if (distance <= wisp) .wisp else if (distance <= stave) .stave else .summon,
        else => if (distance <= stave) .summon else .wisp,
    };
}

test "Garroth pursues through his melee/ranged gap and keeps weapon fallback order" {
    const t = @import("std").testing;
    try t.expect(inRange(119, 120));
    try t.expect(!inRange(120, 120));
    try t.expect(!inRange(199, 120));
    try t.expect(inRange(200, 120));
    try t.expect(inRange(600, 120));
    try t.expect(!inRange(601, 120));
    try t.expectEqual(Weapon.wisp, choose(500, 120, 400, 600, 1));
    try t.expectEqual(Weapon.stave, choose(500, 120, 600, 400, 2));
    try t.expectEqual(Weapon.summon, choose(700, 120, 400, 600, 1));
    try t.expectEqual(Weapon.summon, choose(500, 120, 600, 400, 0));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_garroth", .kind = .garroth },
};
