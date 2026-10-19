// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: gunners. Episode-four gunner policies. The commando's two poses are both stationary.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{ .{ .kind = .sealcaptain, .traits = .{ .attack = .ground } }, .{ .kind = .sealcommando, .traits = .{ .attack = .ground } }, .{ .kind = .sealgirl, .traits = .{ .attack = .ground } }, .{ .kind = .uzigang, .traits = .{ .attack = .ground } } };
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "gunner";
/// The captain's and the girl's shotguns need a range beyond their melee reach.
pub fn parseTuning(_: anytype, kind: class_traits.Kind, definition: anytype) !void {
    if ((kind == .sealcaptain or kind == .sealgirl) and definition.range <= 256) return error.InvalidGunnerShotgun;
}
pub const Kind = enum { captain, commando, girl, uzi };
pub const attacks = [_][]const u8{ "ataka", "atakb" };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
/// The seals fight from cover (spawnflag 512); the Uzi gang member has no cover behaviour.
pub fn takesCover(kind: Kind) bool {
    return kind != .uzi;
}
pub const State = struct {
    pursuing: bool = true,
    ready_ms: i64 = 0,
    emit_ms: i64 = 0,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.ready_ms, delta);
        try saved.active(&self.emit_ms, delta);
    }
};
/// The commando's chaingun (two-handed in its first pose), the uzi's stream and the shotgun's
/// flash (its pellets are the gunner's own volley).
pub const burst_styles = [_]@import("../../../mechanics/policy/actors/bursts.zig").Style{
    .{ .kind = .commando, .opening_shot = true, .shots = 5, .flash_model = flash_model, .muzzle = .{ .tags = .{ .name = "hr_muzzle2", .pair = .{ "hr_muzzle1", "hr_muzzle2" }, .scale = 1.05 } } },
    .{ .kind = .uzi, .stop_frame = 80, .flash_model = flash_model, .muzzle = .{ .offset = .{ 20, 6, 25 } } },
    .{ .kind = .shotgun, .flash_only = true, .flash_model = flash_model, .muzzle = .{ .tags = .{ .name = "hr_muzzle1", .scale = 2.05 } } },
};
pub const flash_model = "models/global/we_mflash.dkm";
pub fn chaseDistance(kind: Kind) f32 {
    return if (kind == .captain) 300 else 200;
}
pub fn painLimit(kind: Kind) i32 {
    return switch (kind) {
        .captain, .girl => 35,
        .commando => 45,
        .uzi => 50,
    };
}
pub fn shotgunDamage(base: f32, random_damage: f32, roll: f32, distance: f32, range: f32) f32 {
    const damage = base + random_damage * roll;
    return if (distance <= 256) damage else @max(0, damage * (1 - (distance - 256) / (range - 256)));
}
test "shotgun damage uses enemy distance beyond the full damage band" {
    const t = @import("std").testing;
    try t.expectEqual(@as(f32, 25), shotgunDamage(20, 10, 0.5, 256, 500));
    try t.expectEqual(@as(f32, 12.5), shotgunDamage(20, 10, 0.5, 378, 500));
    try t.expectEqual(@as(f32, 0), shotgunDamage(20, 10, 0.5, 500, 500));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_sealcaptain", .kind = .sealcaptain },
    .{ .classname = "monster_sealcommando", .kind = .sealcommando },
    .{ .classname = "monster_sealgirl", .kind = .sealgirl },
    .{ .classname = "monster_uzigang", .kind = .uzigang },
};
test "the seals take cover; the Uzi gang member has none" {
    try @import("std").testing.expect(takesCover(.girl) and !takesCover(.uzi));
}
