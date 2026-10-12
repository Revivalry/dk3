// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: medusa. Pure medusa class policy: state, tuning and decisions.
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .medusa, .traits = .{ .sidekicks = .avoid, .attack = .sequence } }};
/// Her spit is a small sludge glob with a green trail.
pub const spit_styles = [_]@import("../../../mechanics/policy/actors/venom_spit.zig").Style{.{ .kind = .medusa, .model = "models/e1/me_sludge.dkm", .scale = 0.15, .attacker_class = "monster_medusa", .trail = true }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "medusa";
/// Aidata: the spit is weapon 2.
pub const ClassTuning = struct { spit: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const spit = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_");
    if (spit.speed <= 0) return error.InvalidMedusaSpit;
    return .{ .spit = spit };
}
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc", "atakd", "atake" };
pub const gaze_tag = 10024;
/// The gaze overlay names its victim in `otherEntityNum` (linked_tag_classes.zig).
pub const linked_overlay_tags = [_]i32{gaze_tag};
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { combat, rattle, gaze, recover, retreat, sidestep } = .combat,
    until_ms: i64 = 0,
    target: u32 = 0,
    eyes: bool = false,
    flash_until_ms: i64 = 0,
    retreat: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.until_ms, delta);
        try saved.active(&self.flash_until_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (!saved.point(self.retreat)) return error.InvalidSavedActor;
    }
    /// Maps saved persistent ids onto the restored world.
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.target);
    }
};
pub fn inRange(distance: f32, melee: f32, spit_roll: f32, gaze_roll: f32) bool {
    return distance <= melee or (distance <= 350 and spit_roll < 0.5) or (distance <= 1250 and gaze_roll < 0.05);
}
pub fn eyeContact(toward_enemy: [3]f32, medusa: [3]f32, enemy: [3]f32, enemy_fov: f32) bool {
    return angle(toward_enemy[0], medusa[0]) < 35 and angle(toward_enemy[1], medusa[1]) < 35 and angle(-toward_enemy[0], enemy[0]) < 35 and angle(toward_enemy[1] + 180, enemy[1]) < enemy_fov * 0.5;
}
fn angle(a: f32, b: f32) f32 {
    return @abs(@mod(a - b + 180, 360) - 180);
}
test "Medusa requires mutual yaw and pitch contact with wrapped strict boundaries" {
    const t = std.testing;
    try t.expect(eyeContact(.{ 0, 359, 0 }, .{ 0, 1, 0 }, .{ 0, 179, 0 }, 90));
    try t.expect(!eyeContact(.{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 135, 0 }, 90));
    try t.expect(!eyeContact(.{ 0, 0, 0 }, .{ 35, 0, 0 }, .{ 0, 180, 0 }, 90));
    try t.expect(!eyeContact(.{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 35, 180, 0 }, 90));
    try t.expect(inRange(350, 80, 0.7, 0.04));
    try t.expect(!inRange(1251, 80, 0, 0));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_medusa", .kind = .medusa },
};
