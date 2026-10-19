// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: femgang. Pure femgang class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .femgang, .traits = .{ .attack = .ground } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "femgang";
pub const attacks = [_][]const u8{ "ataka", "atakb" };
pub const State = struct { idle_chosen: bool = false, idle_b: bool = false };
pub const attack_distance: f32 = 200;
/// Her evasive action lasts at most half a second.
pub const evasion_ms = 500;
pub fn select(distance: f32, reach: f32) u3 {
    return @intFromBool(distance >= reach);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_femgang", .kind = .femgang },
};
