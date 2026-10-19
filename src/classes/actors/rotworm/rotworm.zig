// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: rotworm. Pure rotworm class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .rotworm, .traits = .{ .attack = .ground } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "rotworm";
/// Aidata: the spit is weapon 2.
pub const ClassTuning = struct { spit: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const spit = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_");
    if (spit.speed <= 0) return error.InvalidRotwormSpit;
    return .{ .spit = spit };
}
/// `atakb` (the leap) stays loaded so saved poses keep their indices; the reference never leaps:
/// its jump attack starts no flight and only re-plans the attack.
pub const attacks = [_][]const u8{ "ataka", "atakc", "atakb" };
/// Pain: the reference's single 75% roll (`hita`), never on the hit that makes a player its enemy.
pub const pain_chance = 75;
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    /// `flight` and `jump_bite` are saved tags only (older saves); a restored one lands as `ground`.
    phase: enum { ground, ceiling, flight, jump_bite } = .ground,
    started_ms: i64 = 0,
    destination: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.started_ms, delta);
    }
};
/// Its fiery spit.
pub const spit_styles = [_]@import("../../../mechanics/policy/actors/venom_spit.zig").Style{.{ .kind = .rotworm, .model = "models/e3/me_rotspit.dkm", .scale = 0.1, .attacker_class = "monster_rotworm", .sound = "e3/e_firespitf.wav" }};
pub fn select(distance: f32, roll: f32) u3 {
    return if (distance < 60 or roll < 0.25) 0 else 1;
}
test "Rotworm bites close or on a quarter roll, otherwise spits" {
    const t = @import("std").testing;
    try t.expectEqual(@as(u3, 0), select(59, 1));
    try t.expectEqual(@as(u3, 0), select(200, 0.2));
    try t.expectEqual(@as(u3, 1), select(60, 0.25));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_rotworm", .companion_choices = .{ 0, 1, 1 }, .kind = .rotworm },
};
