// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: griffon. Pure griffon class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .griffon, .traits = .{ .attack = .sequence, .remains = .{ .always = true } } }};
/// Pain: its own 15% flinch (`hita` flying, `hitb` grounded), whose clip the next think cuts short,
/// then the shared 10% roll.
pub const flinch_chance = 0.15;
pub const flinch_ms = 100;
pub const pain_chance = 10;
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "griffon";
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakd", "drop", "jumpa" };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { chase, descend, land, retreat, leap, attack } = .chase,
    flying: bool = true,
    started_ms: i64 = 0,
    until_ms: ?i64 = null,
    destination: [3]f32 = @splat(0),
    previous: [3]f32 = @splat(0),
    blocked: u8 = 0,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.started_ms, delta);
        try saved.deadline(&self.until_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (!saved.point(self.destination) or !saved.point(self.previous)) return error.InvalidSavedActor;
    }
};
pub fn wantsLeap(distance: f32, roll: f32) bool {
    return distance > 150 and distance < 300 and roll < 0.25;
}
test "griffon ground leap uses the authored open interval" {
    const t = @import("std").testing;
    try t.expect(!wantsLeap(150, 0));
    try t.expect(wantsLeap(151, 0.24));
    try t.expect(!wantsLeap(299, 0.25));
    try t.expect(!wantsLeap(300, 0));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_griffon", .kind = .griffon, .run = "flya" },
};
