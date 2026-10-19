// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: vermin. VenomVermin's bite, short leap and accelerating missile.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .venomvermin, .traits = .{ .attack = .ground, .remains = .{ .robotic = true, .no_blood = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "vermin";
/// Pain: `pain_chance` percent per hit, and a second roll flinches a hit of `pain_limit` or more.
pub const pain_chance = 50;
pub const pain_limit = 35;
/// Its rocket leaves a muzzle 20 units up and flies along its facing.
pub const rocket_styles = [_]@import("../../../mechanics/policy/actors/missiles.zig").Style{.{ .kind = .vermin, .origin = .{ .muzzle = .{ 0, 0, 20 } }, .faces_launcher = true }};
/// Aidata: the bite is weapon 2 and the rocket weapon 3.
pub const ClassTuning = struct { rocket: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, definition: anytype) !ClassTuning {
    const rocket = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon3_");
    (try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_")).primary(definition);
    if (rocket.speed <= 0) return error.InvalidVerminRocket;
    return .{ .rocket = rocket };
}
pub const attacks = [_][]const u8{ "ataka", "runa", "atakc", "atakd" };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    ready_ms: i64 = 0,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.ready_ms, delta);
    }
};
pub fn select(distance: f32) ?u3 {
    return if (distance <= 40) 0 else if (distance <= 192) 1 else if (distance <= 400) 2 else null;
}
test "Vermin attack bands keep authored boundaries" {
    const t = @import("std").testing;
    try t.expectEqual(@as(?u3, 0), select(40));
    try t.expectEqual(@as(?u3, 1), select(192));
    try t.expectEqual(@as(?u3, 2), select(400));
    try t.expectEqual(@as(?u3, null), select(401));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_venomvermin", .nitro_immune = true, .kind = .venomvermin },
};
