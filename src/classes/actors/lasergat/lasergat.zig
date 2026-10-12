// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: lasergat. Pure lasergat class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .lasergat, .traits = .{ .sidekicks = .refuse_melee, .attack = .ground, .remains = .{ .robotic = true, .no_blood = true, .always = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "lasergat";
/// Aidata: the laser is weapon 1.
pub const ClassTuning = struct { laser: @import("../../../mechanics/policy/actors/laser.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    return .{ .laser = try @import("../../../mechanics/policy/actors/laser.zig").Tuning.parse(row, "weapon1_") };
}
pub const attacks = [_][]const u8{"shoota"};
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    servo_ms: i64 = 0,
    turning: bool = false,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.servo_ms, delta);
    }
};
pub const turn_degrees: f32 = 10;
/// A hit from its enemy stalls the turret this often (the reference's default pain chance; the
/// turret has no pain clip, so the stall only restarts its shot cycle).
pub const pain_chance = 0.75;
/// The stall's pause.
pub const stall_ms = 100;
/// After a stall, hits cannot stall it again for this long (its shot clip's span).
pub const pain_lock_ms = 500;
pub const servo_sound = "e1/m_lazergatservo.wav";
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_lasergat", .companion_choices = .{ 1, 1, 2 }, .kind = .lasergat, .idle = "shoota", .run = "shoota", .death = "shoota" },
};
