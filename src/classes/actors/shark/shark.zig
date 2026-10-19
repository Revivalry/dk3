// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: shark. Pure shark class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .shark, .traits = .{ .attack = .ground, .aquatic = true } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "shark";
/// Swimmers need a walk speed (they wander at twice it).
pub fn parseTuning(_: anytype, _: class_traits.Kind, definition: anytype) !void {
    if (definition.walk_speed <= 0) return error.InvalidSwimmerSpeed;
}
pub const attacks = [_][]const u8{ "ataka", "atakb" };
/// Pain: the generic handler at 100% with a 25 limit (the limit only matters on the acquiring hit).
pub const pain_chance = 100;
pub const pain_limit = 25;
/// It wanders at twice its walking speed.
pub const wander_pace: f32 = 2;
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    suspended_target: u32 = 0,
    wandering: bool = false,
    start: [3]f32 = @splat(0),
    destination: ?[3]f32 = null,
    wander_until_ms: i64 = 0,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.wander_until_ms, delta);
    }
    /// Maps saved persistent ids onto the restored world.
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.suspended_target);
    }
};
pub fn select(roll: f32) u3 {
    return if (roll < 1.0 / 3.0) 0 else 1;
}
pub fn abandons(water: u2) bool {
    return water == 0;
}
pub fn resumes(water: u2) bool {
    return water == 3;
}
test "Shark target suspension uses separate dry and submerged boundaries" {
    const t = @import("std").testing;
    try t.expect(abandons(0));
    try t.expect(!abandons(1));
    try t.expect(!resumes(2));
    try t.expect(resumes(3));
    try t.expectEqual(@as(u3, 0), select(0.32));
    try t.expectEqual(@as(u3, 1), select(0.34));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_shark", .kind = .shark, .run = "swima" },
};
