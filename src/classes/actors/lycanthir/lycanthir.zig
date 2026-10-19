// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: lycanthir. Lycanthir attack selection and Silverclaw-dependent resurrection.
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .lycanthir, .traits = .{ .attack = .ground, .remains = .{ .always = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "lycanthir";
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc", "atakd", "jumpb" };
pub const death_howl = "e3/m_lycanthirhowla.wav";
/// The reference's generic pain: two 15% rolls, `hita` on the second for a hit of 35 or more.
pub const pain_chance = 15;
pub const pain_limit = 35;
/// Chance of evasive action when a claw clip (`ataka`-`atakc`) or the chase attack (`atakd`) ends.
pub const claw_evasion: f32 = 0.2;
pub const chase_evasion: f32 = 0.1;
/// Evasive action lasts at most this long.
pub const evasion_ms = 500;
/// The furthest leap: run speed × 2 × upward speed / gravity (800).
pub fn jumpRange(run_speed: f32, upward_speed: f32) f32 {
    return run_speed * 2 * upward_speed / 800;
}
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { living, collapsed, rising } = .living,
    started_ms: i64 = 0,
    wake_ms: i64 = 0,
    prepared: bool = false,
    launched: bool = false,
    pub fn collapse(self: *State, now: i64, skill: i32) void {
        self.* = .{ .phase = .collapsed, .started_ms = now, .wake_ms = now + @import("../../../mechanics/policy/actors/difficulty.zig").pick(i64, skill, .{ 15000, 10000, 5000 }) };
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.started_ms, delta);
        try saved.shift(&self.wake_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, check: saved.Check) !void {
        if (self.phase != .living and (!check.owned or self.wake_ms < self.started_ms and self.phase == .collapsed)) return error.InvalidSavedResurrection;
    }
};
pub fn select(distance: f32, attack_range: f32, jump_range: f32, forward_dot_velocity: f32, speed_xy_squared: f32, mode_roll: f32, pose_roll: f32) u3 {
    if (distance < attack_range) {
        if (forward_dot_velocity > -1 and speed_xy_squared > 100 and mode_roll < 0.6) return 3;
        return if (pose_roll < 0.33) 0 else if (pose_roll < 0.666) 1 else 2;
    }
    return if (distance < jump_range and mode_roll < 0.2) 4 else 3;
}
test "lycanthir chase selection uses enemy movement and resurrection uses campaign difficulty" {
    const t = std.testing;
    const jump = jumpRange(300, 270);
    try t.expectApproxEqAbs(@as(f32, 202.5), jump, 0.01);
    try t.expectEqual(@as(u3, 3), select(60, 80, jump, 20, 400, 0.5, 0));
    try t.expectEqual(@as(u3, 1), select(60, 80, jump, -20, 400, 0.5, 0.5));
    try t.expectEqual(@as(u3, 4), select(150, 80, jump, 0, 0, 0.1, 0));
    try t.expectEqual(@as(u3, 3), select(210, 80, jump, 0, 0, 0.1, 0));
    var state: State = .{};
    state.collapse(1000, 3);
    try t.expectEqual(@as(i64, 11000), state.wake_ms);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_lycanthir", .companion_choices = .{ 0, 0, 0 }, .kind = .lycanthir },
};
