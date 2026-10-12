// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: crox. Amphibious melee policy. Numeric weapon tuning belongs to supplied aidata.
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .crox, .traits = .{ .pain_clips = true, .remains = .{ .robotic = true, .no_blood = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "crox";
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc", "atakd" };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    pose: u2 = 0,
    attacking: bool = false,
    struck: bool = false,
    sounded: u2 = 0,
    swimming: bool = false,
    water: u2 = 0,
    wandering: bool = false,
    death_b: bool = false,
    start: [3]f32 = @splat(0),
    destination: ?[3]f32 = null,
    started_ms: i64 = 0,
    wander_until_ms: i64 = 0,
    cycle_ms: i64 = 0,
    pub fn begin(self: *State, now: i64, random: f32) void {
        self.pose = attackPose(self.water, random);
        self.attacking = true;
        self.struck = false;
        self.sounded = 0;
        self.started_ms = now;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.started_ms, delta);
        try saved.shift(&self.cycle_ms, delta);
        try saved.shift(&self.wander_until_ms, delta);
    }
};
/// A hit from its enemy (not the acquiring one) flinches with `hita` this often.
pub const pain_chance = 20;
pub fn attackPose(water: u2, random: f32) u2 {
    return if (water < 3) if (random < 0.666) 2 else 3 else if (random < 0.666) 1 else 0;
}
pub fn beyondHeight(vertical: f32) bool {
    return @abs(vertical) > 100;
}
pub fn facing(yaw_delta: f32) bool {
    return @abs(@mod(yaw_delta + 180, 360) - 180) < 5;
}
pub const wanderCandidate = @import("../../../mechanics/policy/actors/wander.zig").candidate;
test "Crox chooses four authored poses at actual water boundary and resumes within height band" {
    const t = std.testing;
    try t.expectEqual(@as(u2, 2), attackPose(2, 0.665));
    try t.expectEqual(@as(u2, 3), attackPose(2, 0.666));
    try t.expectEqual(@as(u2, 1), attackPose(3, 0.665));
    try t.expectEqual(@as(u2, 0), attackPose(3, 0.666));
    try t.expect(!beyondHeight(100));
    try t.expect(beyondHeight(-101));
    try t.expect(facing(359));
    try t.expect(!facing(5));
    try t.expect(wanderCandidate(100, 1300, 100, 0, 350, 50));
    try t.expect(!wanderCandidate(100, 1300, 5, 0, 0, 50));
    try t.expect(!wanderCandidate(1300, 1300, 100, 0, 0, 50));
    try t.expect(!wanderCandidate(100, 1300, 100, 0, 91, 50));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_crox", .nitro_immune = true, .kind = .crox },
};
