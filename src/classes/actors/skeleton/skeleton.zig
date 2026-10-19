// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: skeleton. Six standing sword attacks and a distinct moving attack sequence.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .skeleton, .traits = .{ .attack = .ground, .remains = .{ .bone = true, .no_blood = true } } }};
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc", "atakd", "atake", "atakg", "atakf" };
pub fn select(random: f32) u3 {
    return @intFromFloat(@min(@as(f32, 5), random * 6));
}
pub const chase_pose: u3 = 6;
/// The reference's generic pain: two 20% rolls, `hita` on the second for a hit of 35 or more.
pub const pain_chance = 20;
pub const pain_limit = 35;
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_skeleton", .kind = .skeleton },
};
