// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: ragemaster. Ragemaster uses its authored overhead strike, including both frame events.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .ragemaster, .traits = .{ .sidekicks = .refuse_melee, .attack = .ground, .remains = .{ .robotic = true, .no_blood = true } } }};
pub const attacks = [_][]const u8{"atake"};
/// The reference's generic pain: two 5% rolls, `hita` on the second for a hit of 65 or more.
pub const pain_chance = 5;
pub const pain_limit = 65;
pub fn select(_: f32) u3 {
    return 0;
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_ragemaster", .nitro_immune = true, .kind = .ragemaster },
};
