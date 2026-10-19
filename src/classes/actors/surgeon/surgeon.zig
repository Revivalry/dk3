// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: surgeon. A worker that ignores the player until hurt: pain makes it cower in place;
//! afterwards it hides from the player it sees (runs off, then cowers) like a skinny worker.
//! Reference behaviour: surgeon.cpp, skinnyworker.cpp (docs/class-porting/surgeon.md).
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .surgeon }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "surgeon";
pub const poses = [_][]const u8{ "gamba", "gambc" };
/// How long a pain stall holds each cower pose (its clip length) before another hit can stall.
pub const pose_ms = [_]i64{ 950, 350 };
/// A hit stalls the cower this often, restarting it with a fresh pose and reevaluation delay.
pub const pain_chance = 0.75;
/// A hit keeps the surgeon cowering at least this long.
pub const injury_ms = 15000;
/// A cowering surgeon reconsiders after this long.
pub const reconsider_ms = 10000;
/// An enemy this close and in sight after the reconsider delay ends the cower.
pub const restart_distance = 300;
/// A hide flight gives up after this long.
pub const hide_ms = 10000;
/// The surgeon has the thin worker voice when it starts to hide.
pub const thin_voice = true;
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    active: bool = false,
    returning: bool = false,
    until_ms: i64 = 0,
    reconsider_ms: i64 = 0,
    started_ms: i64 = 0,
    home: [3]f32 = @splat(0),
    pose: u1 = 0,
    /// Running from a seen enemy; the flight ends in a cower.
    hiding: bool = false,
    voice_pending: bool = false,
    stall_ms: i64 = 0,
    /// A hit: cower in place at once (a hide flight stops), at least `injury_ms`. While cowering,
    /// a hit past the pose's stall rolls `stall` against `pain_chance` to restart the cower.
    pub fn hurt(self: *State, position: [3]f32, now: i64, roll: f32, stall: f32) void {
        self.until_ms = now + injury_ms;
        if (self.active) {
            if (now >= self.stall_ms and stall < pain_chance) self.cower(now, roll);
            return;
        }
        if (!self.hiding and !self.returning) self.home = position;
        self.hiding = false;
        self.cower(now, roll);
    }
    /// A calm surgeon that sees its enemy runs from it, leaving `position` as its home.
    pub fn hide(self: *State, position: [3]f32) void {
        if (self.active or self.hiding) return;
        if (!self.returning) self.home = position;
        self.returning = false;
        self.hiding = true;
        self.voice_pending = true;
    }
    /// The hide flight ended: cower where it stopped.
    pub fn settle(self: *State, now: i64, roll: f32) void {
        if (!self.hiding) return;
        self.hiding = false;
        self.until_ms = now;
        self.cower(now, roll);
    }
    fn cower(self: *State, now: i64, roll: f32) void {
        self.active = true;
        self.returning = false;
        self.started_ms = now;
        self.reconsider_ms = now + reconsider_ms;
        self.pose = if (roll > 0.5) 0 else 1;
        self.stall_ms = now + pose_ms[self.pose];
    }
    pub fn advance(self: *State, distance: f32, visible: bool, active_distance: f32, now: i64) enum { cower, resume_goal, return_home } {
        if (distance < restart_distance and visible and now > self.reconsider_ms) {
            self.active = false;
            return .resume_goal;
        }
        if (distance > active_distance and now > self.until_ms) {
            self.active = false;
            self.returning = true;
            return .return_home;
        }
        return .cower;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.until_ms, delta);
        try saved.active(&self.reconsider_ms, delta);
        try saved.active(&self.stall_ms, delta);
        if (self.active) try saved.shift(&self.started_ms, delta);
    }
};
test "injury extends cowering; a stall past the pose restarts it" {
    const t = @import("std").testing;
    var state: State = .{};
    state.hurt(.{ 1, 2, 3 }, 1000, 0.75, 0.9);
    state.hurt(.{ 4, 5, 6 }, 5000, 0.2, 0.9);
    try t.expectEqual(@as(i64, 20000), state.until_ms);
    try t.expectEqual(@as(i64, 1000), state.started_ms);
    try t.expectEqual(@as(u1, 0), state.pose);
    try t.expectEqual(.cower, state.advance(900, false, 800, 19999));
    state.hurt(.{ 4, 5, 6 }, 6000, 0.2, 0.5);
    try t.expectEqual(@as(i64, 6000), state.started_ms);
    try t.expectEqual(@as(u1, 1), state.pose);
    try t.expectEqual(@as(i64, 16000), state.reconsider_ms);
    state.hurt(.{ 4, 5, 6 }, 6100, 0.9, 0.1);
    try t.expectEqual(@as(i64, 6000), state.started_ms);
    try t.expectEqual(.return_home, state.advance(900, false, 800, 21101));
    try t.expectEqual([3]f32{ 1, 2, 3 }, state.home);
}
test "a hide keeps its home and settles into a cower without the injury hold" {
    const t = @import("std").testing;
    var state: State = .{};
    state.hide(.{ 7, 8, 9 });
    try t.expect(state.hiding and state.voice_pending);
    state.hurt(.{ 1, 1, 1 }, 2000, 0.9, 0.9);
    try t.expect(!state.hiding and state.active);
    try t.expectEqual([3]f32{ 7, 8, 9 }, state.home);
    state = .{};
    state.hide(.{ 7, 8, 9 });
    state.settle(3000, 0.1);
    try t.expect(state.active and state.pose == 1);
    try t.expectEqual(@as(i64, 13000), state.reconsider_ms);
    try t.expectEqual(.return_home, state.advance(5000, false, 4000, 3001));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_surgeon", .kind = .surgeon },
};
