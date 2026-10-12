// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: harpy. Pure harpy class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .harpy, .traits = .{ .attack = .sequence, .remains = .{ .always = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "harpy";
/// Aidata: the arrow is weapon 1.
pub const ClassTuning = struct { arrow: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const arrow = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon1_");
    if (arrow.speed <= 0) return error.InvalidHarpyArrow;
    return .{ .arrow = arrow };
}
pub const attacks = [_][]const u8{ "ataka", "atakb", "drop" };
/// Its magic arrow glows and vanishes on contact.
pub const shaft_styles = [_]@import("../../../mechanics/policy/actors/shafts.zig").Style{.{ .kind = .harpy, .model = "models/e3/we_bolt.dkm", .attacker_class = "monster_harpy", .touch = .magic }};
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { chase, attack, dodge, approach_land, landing, settling, takeoff, rising } = .chase,
    flying: bool = true,
    started_ms: i64 = 0,
    ready_ms: i64 = 0,
    warmup_started_ms: i64 = 0,
    shot_ms: i64 = 0,
    until_ms: ?i64 = null,
    destination: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.started_ms, delta);
        try saved.active(&self.warmup_started_ms, delta);
        try saved.active(&self.ready_ms, delta);
        try saved.active(&self.shot_ms, delta);
        try saved.deadline(&self.until_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (!saved.point(self.destination)) return error.InvalidSavedActor;
    }
};
pub fn transition(flying: bool, target_room: f32, own_room: f32) enum { none, land, fly } {
    if (flying and target_room < 250) return .land;
    if (!flying and target_room > 350 and own_room > 350) return .fly;
    return .none;
}
test "harpy room decisions keep the authored landing and takeoff hysteresis" {
    const t = @import("std").testing;
    try t.expect(transition(true, 249, 500) == .land);
    try t.expect(transition(true, 250, 500) == .none);
    try t.expect(transition(false, 351, 351) == .fly);
    try t.expect(transition(false, 350, 500) == .none);
    try t.expect(transition(false, 500, 350) == .none);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_harpy", .kind = .harpy, .run = "flya" },
};
