// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: column. Column is a dormant stone guardian with a hammer-only vulnerability.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .column, .traits = .{ .sidekicks = .avoid, .attack = .ground, .remains = .{ .never = true, .no_blood = true, .robotic = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "column";
pub const attacks = [_][]const u8{ "ataka", "atakb" };
pub const awakening_distance: f32 = 256;
pub const attack_distance: f32 = 200;
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { asleep, awakening, awake } = .asleep,
    started_ms: i64 = 0,
    hurt: bool = false,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.started_ms, delta);
    }
};
pub fn acceptsWeapon(hammer: bool) bool {
    return hammer;
}
pub fn select(distance: f32, weapon_range: f32) u3 {
    return if (distance < weapon_range) 0 else 1;
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_column", .nitro_immune = true, .companion_choices = .{ 0, 0, 0 }, .kind = .column },
};
