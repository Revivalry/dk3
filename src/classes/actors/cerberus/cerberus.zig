// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: cerberus. Pure cerberus class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .cerberus, .traits = .{ .sidekicks = .avoid, .attack = .ground } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "cerberus";
pub const attacks = [_][]const u8{ "ataka", "atakb", "jumpa" };
pub const State = struct { launched: bool = false };
/// Of the Episode 2 weapons only the trident harms it (the reference filters that weapon damage
/// path); every other damage (Zeus, other episodes' weapons, monsters) is admitted.
pub fn admits(weapon: u5, episode_two: []const u5, trident: u5) bool {
    if (weapon == trident) return true;
    for (episode_two) |id| if (weapon == id) return false;
    return true;
}
test "cerberus takes Episode 2 weapon damage only from the trident" {
    const t = @import("std").testing;
    try t.expect(admits(9, &.{ 7, 8 }, 9));
    try t.expect(!admits(7, &.{ 7, 8 }, 9));
    try t.expect(admits(3, &.{ 7, 8 }, 9));
    try t.expect(admits(0, &.{ 7, 8 }, 9));
}
pub fn inRange(distance: f32, melee: f32, jump: f32, roll: f32) bool {
    return distance < melee or (distance < jump and roll <= 0.4);
}
pub fn select(distance: f32, melee: f32, roll: f32) u3 {
    return if (distance > melee) 2 else if (roll < 0.5) 0 else 1;
}
test "Cerberus jump admission and selection are separate from bite selection" {
    const t = @import("std").testing;
    try t.expect(inRange(200, 108, 250, 0.4));
    try t.expect(!inRange(200, 108, 250, 0.41));
    try t.expectEqual(@as(u3, 2), select(200, 108, 0));
    try t.expectEqual(@as(u3, 1), select(108, 108, 0.5));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_cerberus", .kind = .cerberus },
};
