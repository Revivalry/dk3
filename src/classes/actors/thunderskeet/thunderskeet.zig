// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: thunderskeet. Authored burst windows and chase/hover cycle for the bridge's heavy flier.
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .thunderskeet, .traits = .{ .sidekicks = .refuse_melee, .pain_clips = true, .remains = .{ .robotic = true, .no_blood = true, .always = true } } }};
/// A hit (other than the one that makes its attacker the enemy) flinches with `hita` this often.
pub const pain_chance = 10;
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "thunder";
pub const attack = "ataka";
pub const spray_model = "models/global/e_flyellow.sp2";
pub const spray_sound = "global/e_warploopb.wav";
pub const spray_tag: i32 = -1;
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { chase, attack, hover } = .chase,
    started_ms: i64 = 0,
    next_shot: u3 = 0,
    sounded: bool = false,
    pub fn enter(self: *State, phase: @FieldType(State, "phase"), now: i64) void {
        self.phase = phase;
        self.started_ms = now;
        self.next_shot = 0;
        self.sounded = false;
    }
    pub fn shots(self: *State, now: i64, first: u16, fps: u16) u3 {
        // The reference fires once in each window (frames 27-28 and 31-32): its thinks land on 28 and 32.
        const frames = [_]u16{ 28, 32 };
        var count: u3 = 0;
        while (self.next_shot < frames.len and now >= self.started_ms + @divTrunc(@as(i64, frames[self.next_shot] - first) * 1000, fps)) {
            self.next_shot += 1;
            count += 1;
        }
        return count;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.started_ms, delta);
    }
};
pub const Spray = struct {
    owner: u32,
    alternate: bool,
    born_ms: i64,
    stepped_ms: i64,
    next_ms: i64,
    phase: u4 = 0,
    scale: f32 = 1.4,
    delta: f32 = -0.25,
    pub fn tick(self: *Spray, velocity: *[3]f32) bool {
        var sound = false;
        if (self.scale < 0.3) self.delta = 0.25 else if (self.scale > 0.85) {
            self.delta = -0.25;
            sound = self.alternate;
        }
        self.scale += self.delta;
        // The reference indexes a twelve-entry trigonometric cycle at index 12.
        // Wrap at twelve so the correction cannot read unrelated memory.
        const angle = (1 + 30 * @as(f32, @floatFromInt(self.phase))) * std.math.pi / 180;
        const wave = if (self.alternate) @sin(angle) else @cos(angle);
        velocity[0] += 10 * wave;
        velocity[1] += 5 * wave;
        self.phase = (self.phase + 1) % 12;
        return sound;
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Spray, map: anytype) !void {
        try map.one(&self.owner);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Spray, clock: anytype) !void {
        try clock.shift(&self.born_ms);
        try clock.shift(&self.stepped_ms);
        try clock.shift(&self.next_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Spray, check: anytype) !void {
        try check.require(.{ "Transform", "Velocity", "Body", "Binding", "Lifetime" });
        if (self.owner == 0 or self.phase >= 12 or self.scale <= 0 or self.scale > 2 or self.next_ms < self.stepped_ms or self.stepped_ms < self.born_ms) return error.InvalidSavedThunderSpray;
    }
};
pub fn blast(distance: f32, owner: bool) f32 {
    return 40 * @max(0, 1 - distance * distance / (256 * 256)) * (if (owner) @as(f32, 0.5) else 1);
}
test "thunderskeet emits its two shots once and applies quadratic splash" {
    var state: State = .{};
    state.enter(.attack, 1000);
    try std.testing.expectEqual(@as(u3, 0), state.shots(1799, 20, 10));
    try std.testing.expectEqual(@as(u3, 1), state.shots(1800, 20, 10));
    try std.testing.expectEqual(@as(u3, 1), state.shots(2200, 20, 10));
    try std.testing.expectEqual(@as(u3, 0), state.shots(2500, 20, 10));
    try std.testing.expectEqual(@as(f32, 30), blast(128, false));
    try std.testing.expectEqual(@as(f32, 15), blast(128, true));
    var spray: Spray = .{ .owner = 1, .alternate = true, .born_ms = 0, .stepped_ms = 0, .next_ms = 200 };
    var velocity: [3]f32 = .{ 128, 0, 0 };
    for (0..100) |_| {
        _ = spray.tick(&velocity);
        try std.testing.expect(spray.phase < 12);
    }
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_thunderskeet", .companion_choices = .{ 1, 1, 2 }, .kind = .thunderskeet, .run = "flya" },
};
test "a volley fires two globs, one per window" {
    var state: State = .{};
    state.enter(.attack, 0);
    try std.testing.expectEqual(@as(u3, 0), state.shots(399, 20, 20));
    try std.testing.expectEqual(@as(u3, 1), state.shots(400, 20, 20));
    try std.testing.expectEqual(@as(u3, 1), state.shots(600, 20, 20));
    try std.testing.expectEqual(@as(u3, 0), state.shots(700, 20, 20));
}
