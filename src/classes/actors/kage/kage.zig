// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: kage. Kage owns his sword, finite smoke escapes and health recharge cycles.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .kage, .traits = .{ .attack = .sequence } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "kage";
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc", "atake" };
pub const fade_tag = @import("../../../mechanics/policy/actors/fade.zig").fade_tag;
pub const Phase = enum { combat, smoke, hidden, returning, protectors, charging };
const std = @import("std");
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: Phase = .combat,
    suspended: ?Phase = null,
    suspended_next_ms: i64 = 0,
    alpha: f32 = 1,
    base_health: f32 = 1200,
    health_fraction: f32 = 0,
    charges: u8 = 0,
    escapes: u8 = 0,
    protectors: u8 = 0,
    return_steps: u8 = 0,
    next_ms: i64 = 0,
    /// After a recharge: no new recharge, and its shield turns damage away, until this time.
    recharge_ready_ms: i64 = 0,
    dodge_ready_ms: i64 = 0,
    feedback_ready_ms: i64 = 0,
    feedback: bool = false,
    aura: bool = false,
    awakened: bool = false,
    humming: bool = false,
    aura_started_ms: i64 = 0,
    voice_pose: u2 = 0,
    pub fn recharging(self: State) bool {
        return self.phase == .protectors or self.phase == .charging;
    }
    pub fn shielded(self: State, now: i64) bool {
        return !self.recharging() and now < self.recharge_ready_ms;
    }
    pub fn invulnerable(self: State) bool {
        return self.suspended != null or self.phase == .smoke or self.phase == .hidden or self.phase == .returning;
    }
    pub fn eligible(self: State, health: i32, skill: i32, now: i64) bool {
        return !self.recharging() and self.charges > 0 and now > self.recharge_ready_ms and @as(f32, @floatFromInt(health)) + self.health_fraction < self.base_health * limit(skill);
    }
    pub fn refund(self: *State, health: *i32, amount: i32) void {
        const remaining = @as(f32, @floatFromInt(health.*)) + self.health_fraction;
        const restored = if (remaining < self.base_health * 0.2) self.base_health * 0.25 + @as(f32, @floatFromInt(amount)) else remaining + @as(f32, @floatFromInt(amount)) * 1.05;
        health.* = @intFromFloat(restored);
        self.health_fraction = restored - @as(f32, @floatFromInt(health.*));
        self.feedback = true;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        if (self.phase == .combat) try saved.active(&self.next_ms, delta) else try saved.shift(&self.next_ms, delta);
        try saved.active(&self.suspended_next_ms, delta);
        try saved.active(&self.recharge_ready_ms, delta);
        try saved.active(&self.dodge_ready_ms, delta);
        try saved.active(&self.feedback_ready_ms, delta);
        try saved.active(&self.aura_started_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, check: saved.Check) !void {
        if (!saved.bounded(&.{ self.alpha, self.base_health, self.health_fraction }, std.math.floatMax(f32))) return error.InvalidSavedActor;
        if (self.alpha < 0 or self.alpha > 1 or self.base_health <= 0 or self.base_health > 10000000 or self.health_fraction < 0 or self.health_fraction >= 1 or self.charges > 10 or self.escapes > 8 or self.protectors > 12 or self.return_steps > 5 or self.voice_pose > 2) return error.InvalidSavedActor;
        if (self.suspended) |phase| if (!self.recharging() or (phase != .smoke and phase != .hidden and phase != .returning)) return error.InvalidSavedActor;
        if (!check.owned) return;
        if (self.recharging() and self.charges == 0) return error.InvalidSavedActor;
        if (self.invulnerable() and self.escapes == 0) return error.InvalidSavedActor;
        if (self.phase == .charging and self.protectors != 12) return error.InvalidSavedActor;
    }
};
pub fn difficulty(skill: i32) usize {
    return @import("../../../mechanics/policy/actors/difficulty.zig").tier(skill);
}
pub fn limit(skill: i32) f32 {
    return ([_]f32{ 0.25, 0.5, 0.75 })[difficulty(skill)];
}
pub fn initialize(health: i32, skill: i32) State {
    const index = difficulty(skill);
    return .{ .base_health = @floatFromInt(health), .charges = ([_]u8{ 2, 5, 10 })[index], .escapes = ([_]u8{ 2, 4, 8 })[index] };
}
test "Kage refunds lethal recharge hits and retains fractional healing" {
    const t = @import("std").testing;
    var state = initialize(1200, 3);
    state.phase = .protectors;
    var health: i32 = -500;
    state.refund(&health, 600);
    try t.expectEqual(@as(i32, 900), health);
    health -= 1;
    state.refund(&health, 1);
    try t.expectEqual(@as(i32, 900), health);
    try t.expectApproxEqAbs(@as(f32, 0.05), state.health_fraction, 0.001);
    try t.expect(!state.eligible(1, 3, 100));
    state.phase = .combat;
    try t.expect(state.eligible(599, 3, 100));
    try t.expect(!state.eligible(600, 3, 100));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_kage", .kind = .kage },
};
