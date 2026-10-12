// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: deathsphere. Pure deathsphere class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .deathsphere, .traits = .{ .sidekicks = .refuse_melee, .attack = .sequence, .remains = .{ .robotic = true, .no_blood = true, .always = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "deathsphere";
/// Aidata: the bolt is weapon 1.
pub const ClassTuning = struct { bolt: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const bolt = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon1_");
    if (bolt.speed <= 0) return error.InvalidDeathBolt;
    return .{ .bolt = bolt };
}
pub const attacks = [_][]const u8{ "ataka", "ready", "flya" };
/// A hit (not the one that makes a player its enemy) stalls it this often; it has no pain clip.
pub const pain_chance = 10;
pub const bolt_model = "models/e1/we_dsbolt.dkm";
pub const bolt_flare = "models/e1/we_dsboltf.sp2";
pub const bolt_tag = 10017;
/// Its bolts are actor lasers of the `death` kind, drawn with this look (actor_lasers.zig).
pub const laser_look: @import("../../../mechanics/policy/actors/laser.zig").Look = .{ .kind = .death, .model = bolt_model, .tag = bolt_tag, .lifetime_ms = 3000, .splash_radius = 96, .contact_sounds = .{ "global/we_zapa.wav", "global/we_zapb.wav" } };
pub const muzzles = [_][3]f32{ .{ 1.21, 10.90, 27.18 }, .{ 23.99, 11.05, 9.38 }, .{ 0.77, 11.05, -7.40 }, .{ -24.23, 11.05, 9.21 } };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { chase, charge, attack, move, recover, sidestep } = .chase,
    resume_phase: enum { chase, charge, recover } = .chase,
    until_ms: i64 = 0,
    charge_ms: i64 = 0,
    destination: [3]f32 = @splat(0),
    boost_frame: i32 = -1,
    extra: u2 = 0,
    bob: u4 = 0,
    pub fn extraVolley(self: *State, frame: i32) bool {
        if (self.boost_frame < 0 or frame < self.boost_frame or frame > self.boost_frame + 1) return false;
        const bit = @as(u2, 1) << @as(u1, @intCast(frame - self.boost_frame));
        if (self.extra & bit != 0) return false;
        self.extra |= bit;
        return true;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.until_ms, delta);
        try saved.active(&self.charge_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (self.bob > 11 or self.boost_frame < -1 or self.boost_frame > 65535) return error.InvalidSavedActor;
        if (!saved.point(self.destination)) return error.InvalidSavedActor;
    }
};
pub fn bobImpulse(index: u4) f32 {
    const std = @import("std");
    return 15 * @round(@sin(@as(f32, @floatFromInt(1 + @as(u16, index) * 30)) * std.math.pi / 180) * 1000) * 0.001;
}
test "deathsphere extra volleys survive a checkpoint without repeating a fired frame" {
    const t = @import("std").testing;
    var state: State = .{ .boost_frame = 34 };
    try t.expect(!state.extraVolley(33));
    try t.expect(state.extraVolley(34));
    var restored = state;
    try t.expect(!restored.extraVolley(34));
    try t.expect(restored.extraVolley(35));
    try t.expect(!restored.extraVolley(36));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_deathsphere", .nitro_immune = true, .companion_choices = .{ 1, 1, 2 }, .kind = .deathsphere, .run = "flya" },
};
