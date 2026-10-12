// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: sludge. Sludgeminion ammo is refilled only when standing in fluid.
/// The persistent attack payloads this class launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{.{ .tag = "sludge_glob", .Payload = Glob }};
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .sludgeminion, .traits = .{ .sidekicks = .refuse_melee, .attack = .ground, .remains = .{ .robotic = true, .no_blood = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "sludge";
/// Pain: `pain_chance` percent per hit, and a second roll flinches a hit of `pain_limit` or more.
pub const pain_chance = 5;
pub const pain_limit = 45;
/// Aidata: the two globs are weapons 1 and 2.
pub const ClassTuning = struct { globs: [2]@import("../../../mechanics/policy/actors/weapon.zig").Tuning = @splat(.{}) };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const globs = [2]@import("../../../mechanics/policy/actors/weapon.zig").Tuning{ try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon1_"), try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_") };
    for (globs) |glob| if (glob.speed <= 0) return error.InvalidSludgeGlob;
    return .{ .globs = globs };
}
pub const attacks = [_][]const u8{ "ataka", "atakb", "ambb", "atakstart" };
const std = @import("std");
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    ammo: f32 = 5,
    water: u2 = 0,
    phase: enum { normal, scooping, raising } = .normal,
    idle_chosen: bool = false,
    idle_scoop: bool = false,
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (!std.math.isFinite(self.ammo) or @abs(self.ammo) > 1000000) return error.InvalidSavedActor;
    }
};
pub const Glob = struct {
    damage: f32,
    contacts: u2 = 0,
    spin: [3]f32 = .{ 0, 0, 35 },
    pub fn validSaved(self: Glob, born_ms: i64, stepped_ms: i64) bool {
        return self.damage > 0 and self.damage <= 1000000 and self.contacts <= 1 and stepped_ms <= born_ms + 3000 and saved.bounded(&self.spin, 360);
    }
};
pub const model = "models/e1/me_sludge.dkm";
pub const glow = "models/global/e_sflgreen.sp2";
pub const render_tag = 10012;
pub fn select(roll: f32) u3 {
    return if (roll < 0.2) 1 else 0;
}
pub fn scoop(ammo: f32, roll: f32) f32 {
    return if (ammo < 0) 2 + 7 * roll else ammo + 3;
}
test "sludge replenishes negative ammo separately from an empty reservoir" {
    const t = @import("std").testing;
    try t.expectEqual(@as(f32, 3), scoop(0, 0.9));
    try t.expectEqual(@as(f32, 5.5), scoop(-1, 0.5));
    try t.expectEqual(@as(u3, 1), select(0.19));
    try t.expectEqual(@as(u3, 0), select(0.2));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_sludgeminion", .nitro_immune = true, .kind = .sludgeminion },
};
