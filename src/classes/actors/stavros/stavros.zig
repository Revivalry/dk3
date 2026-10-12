// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: stavros. Pure stavros class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .stavros, .traits = .{ .sidekicks = .refuse_melee, .attack = .sequence } }};
/// Aidata: the stave is weapon 1.
pub const ClassTuning = struct { stave: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    return .{ .stave = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon1_") };
}
pub const attacks = [_][]const u8{"ataka"};
pub const pain_chance = 1;
pub const pain_limit = 35;
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_stavros", .kind = .stavros, .run = "walka" },
};
