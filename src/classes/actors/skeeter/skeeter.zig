// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: skeeter. Slaughterskeet chase, dart, melee, retreat and hatch choreography.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .skeeter, .traits = .{ .sidekicks = .refuse_melee, .pain_clips = true, .remains = .{ .robotic = true, .no_blood = true, .always = true } } }};
/// A hit (other than the one that makes its attacker the enemy) flinches with `hita` this often.
pub const pain_chance = 75;
/// A dart strikes once within its reach plus this margin.
pub const dart_margin = 32;
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "skeeter";
pub const attack = "ataka";
pub const hatch = "speciala";
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { chase, dart, attack, retreat, hatching } = .chase,
    started_ms: i64 = 0,
    until_ms: i64 = 0,
    fired: bool = false,
    sounded: bool = false,
    retreat: [3]f32 = @splat(0),
    pub fn enter(self: *State, phase: @FieldType(State, "phase"), now: i64, duration: i64) void {
        self.phase = phase;
        self.started_ms = now;
        self.until_ms = now + duration;
        self.fired = false;
        self.sounded = false;
    }
    pub fn tick(self: *State, now: i64, enemy: bool, visible: bool, distance: f32, range: f32, attack_ms: i64, strike_ms: i64, retreat_distance: f32) bool {
        if (self.phase == .hatching) {
            if (now >= self.until_ms) self.enter(.chase, now, 0);
            return false;
        }
        if (!enemy) {
            self.enter(.chase, now, 0);
            return false;
        }
        switch (self.phase) {
            .chase => if (visible and distance <= 178) {
                self.enter(.dart, now, 3000);
            },
            .dart => if (visible and distance - dart_margin < range) {
                self.enter(.attack, now, attack_ms);
            } else if (now >= self.until_ms) {
                self.enter(.chase, now, 0);
            },
            .attack => {
                const fire = !self.fired and now >= self.started_ms + strike_ms;
                if (fire) self.fired = true;
                if (now >= self.until_ms) self.enter(.retreat, now, 3000);
                return fire;
            },
            .retreat => if (retreat_distance <= 64 or now >= self.until_ms) {
                self.enter(.chase, now, 0);
            },
            .hatching => unreachable,
        }
        return false;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.started_ms, delta);
        try saved.shift(&self.until_ms, delta);
    }
};
test "skeeter strikes once at supplied frame then retreats" {
    const t = @import("std").testing;
    var state: State = .{};
    _ = state.tick(0, true, true, 150, 48, 600, 200, 500);
    try t.expectEqual(.dart, state.phase);
    _ = state.tick(100, true, true, 79, 48, 600, 200, 500);
    try t.expectEqual(.attack, state.phase);
    try t.expect(!state.tick(299, true, true, 40, 48, 600, 200, 500));
    try t.expect(state.tick(300, true, true, 40, 48, 600, 200, 500));
    try t.expect(!state.tick(400, true, true, 40, 48, 600, 200, 500));
    _ = state.tick(700, true, true, 40, 48, 600, 200, 500);
    try t.expectEqual(.retreat, state.phase);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_slaughterskeet", .companion_choices = .{ 1, 1, 2 }, .kind = .skeeter, .run = "flya", .death = "diea" },
};
