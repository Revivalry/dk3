// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: doombat. Pure doombat class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .doombat, .traits = .{ .sidekicks = .refuse_melee, .attack = .sequence } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "doombat";
/// Aidata: the fireball is weapon 2, flown at the reference's fixed speed; the doombat senses
/// across the whole level.
pub const ClassTuning = struct { fireball: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, definition: anytype) !ClassTuning {
    var fireball = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_");
    fireball.speed = 400;
    definition.sight_range = 10000;
    return .{ .fireball = fireball };
}
pub const attacks = [_][]const u8{ "ataka", "atakb" };
/// Its fireball is small and bursts once.
pub const fireball_styles = [_]@import("../../../mechanics/policy/actors/fireballs.zig").Style{.{ .kind = .doombat, .scale = 0.15, .secondary_blasts = false }};
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { choose, chase, retreat, hover, attack } = .choose,
    ranged: bool = false,
    started_ms: i64 = 0,
    destination: [3]f32 = @splat(0),
    bob: u3 = 0,
    /// Flight speed: walk × 2 until it first chases without sight, then its run speed.
    speed: f32 = 0,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.started_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (self.bob > 5 or !@import("std").math.isFinite(self.speed) or self.speed < 0) return error.InvalidSavedActor;
    }
};
pub fn ranged(health: f32, base: f32, roll: f32) bool {
    // The active callback compares a percentage against half of base health.
    return 100 * health / base <= base * 0.5 and roll < 0.25;
}
pub fn speedAfterHealthCheck(speed: f32, health: f32, base: f32) f32 {
    return if (100 * health / base <= health * 0.5) speed * 1.35 else speed;
}
/// The bob cycles through five impulses, one per think.
pub const bob_steps = 5;
/// While closing in to claw, it reconsiders spitting a fireball every third think.
pub const reroll_ms = 300;
/// A corpse falls at twice normal gravity.
pub const corpse_gravity = 1600;
pub fn bobImpulse(index: u3) f32 {
    const std = @import("std");
    const phase = @as(u8, @intFromFloat(@as(f32, @floatFromInt(index)) * 2.5)) % 12;
    return 50 * @round(@sin(@as(f32, @floatFromInt(1 + @as(u16, phase) * 30)) * std.math.pi / 180) * 1000) * 0.001;
}
test "doombat keeps the authored health comparison rather than a generic half-health rule" {
    const t = @import("std").testing;
    try t.expect(!ranged(20, 50, 0));
    try t.expect(ranged(12, 50, 0.24));
    try t.expect(!ranged(12, 50, 0.25));
    try t.expectEqual(@as(f32, 250), speedAfterHealthCheck(250, 12, 50));
}
test "doombat bob repeats every five thinks" {
    const t = @import("std").testing;
    const expected = [_]f32{ 0.85, 43.75, 24.25, -25.75, -42.85 };
    for (expected, 0..) |impulse, i| try t.expectApproxEqAbs(impulse, bobImpulse(@intCast(i)), 0.01);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_doombat", .companion_choices = .{ 0, 1, 1 }, .kind = .doombat, .run = "flya" },
};
