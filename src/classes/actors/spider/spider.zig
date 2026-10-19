// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: spider. Large and small spider attack/retreat contracts share their authored animations.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{ .{ .kind = .spider, .traits = .{ .attack = .ground } }, .{ .kind = .smallspider, .traits = .{ .attack = .ground } } };
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "spider";
pub const attacks = [_][]const u8{ "ataka", "jumpa" };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    launched: bool = false,
    retreat_until: ?i64 = null,
    sidestep_until: ?i64 = null,
    sidestep: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.deadline(&self.retreat_until, delta);
        try saved.deadline(&self.sidestep_until, delta);
    }
};
pub fn inRange(distance: f32, melee: f32, jump: f32, roll: f32) bool {
    // Both classes retain the reference AI's zero initial jump chance. Do not
    // invent a higher jump frequency from the mere presence of jumpa frames.
    return distance < melee or (distance < jump and roll == 0);
}
/// Pain: the reference's single 75% roll (`hita`), never on the hit that makes a player the enemy.
pub const pain_chance = 75;
pub fn retreatMilliseconds(roll: f32) i64 {
    return 2000 + @as(i64, @intFromFloat(roll * 5000));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_spider", .kind = .spider },
    .{ .classname = "monster_smallspider", .kind = .smallspider },
};
