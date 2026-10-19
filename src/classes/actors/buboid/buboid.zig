// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: buboid. Pure buboid class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .buboid, .traits = .{ .attack = .sequence } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "buboid";
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc", "atakd", "speciala", "diea" };
pub const melt_tag = 10019;
const std = @import("std");
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { living, coffin, melting, melted, unmelting, collapsed, rising, terminal } = .living,
    started_ms: i64 = 0,
    until_ms: i64 = 0,
    alpha: f32 = 1,
    /// It melted on losing sight of its enemy: the reference ends that fight, so it resurfaces by
    /// the enemy and then has to find it again.
    forget: bool = false,
    pub fn invulnerable(self: State) bool {
        return self.phase == .melting or self.phase == .melted or self.phase == .unmelting;
    }
    pub fn resurrecting(self: State) bool {
        return self.phase == .collapsed or self.phase == .rising;
    }
    /// The first lethal hit begins resurrection. A subsequent lethal hit during
    /// that goal finishes the actor; nonlethal interruption retains one health.
    pub fn damage(self: *State, health: *i32, self_kill: bool, now: i64) bool {
        if (health.* > 0) {
            if (self.resurrecting()) health.* = 1;
            return false;
        }
        if (self.resurrecting() or self_kill) {
            self.phase = .terminal;
            return true;
        }
        self.phase = .collapsed;
        self.started_ms = now;
        self.until_ms = now + 10000;
        health.* = 1;
        return false;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.started_ms, delta);
        try saved.active(&self.until_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (!std.math.isFinite(self.alpha) or self.alpha < 0 or self.alpha > 1) return error.InvalidSavedActor;
    }
};
test "buboid first lethal hit resurrects, another during that goal is terminal" {
    const t = @import("std").testing;
    var state: State = .{};
    var health: i32 = -200;
    try t.expect(!state.damage(&health, false, 100));
    try t.expectEqual(@as(i32, 1), health);
    try t.expectEqual(@as(i64, 10100), state.until_ms);
    var restored = state;
    health = 0;
    try t.expect(restored.damage(&health, false, 500));
    try t.expect(restored.phase == .terminal);
    state.phase = .rising;
    health = 99;
    try t.expect(!state.damage(&health, false, 12000));
    try t.expectEqual(@as(i32, 1), health);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_buboid", .kind = .buboid },
};
