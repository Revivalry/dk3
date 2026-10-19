// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: satyr. Alternating-side melee has authored transition poses; running swings stop at 40 units.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .satyr, .traits = .{ .attack = .ground } }};
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc", "transa", "transb" };
pub const chase_pose: u3 = 2;
/// The reference's generic pain: two 5% rolls, `hita` on the second for a hit of 35 or more.
pub const pain_chance = 5;
pub const pain_limit = 35;
pub fn select(random: f32) u3 {
    return if (random < 0.5) 0 else 1;
}
pub fn transition(previous: u3, next: u3) ?u3 {
    if (previous == 1 and next == 0) return 3;
    if (previous == 0 and next == 1) return 4;
    return null;
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_satyr", .kind = .satyr },
};
