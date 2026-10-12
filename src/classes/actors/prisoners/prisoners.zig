// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: prisoners. Black and white prisoners share attacks but keep distinct pain contracts.
/// The persistent attack payloads this class launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{.{ .tag = "prisoner_rock", .Payload = Rock }};
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{ .{ .kind = .blackprisoner, .traits = .{ .attack = .ground } }, .{ .kind = .whiteprisoner, .traits = .{ .attack = .ground } } };
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "prisoner";
/// Aidata: the thrown rock is weapon 2.
pub const ClassTuning = struct { rock: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const rock = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_");
    if (rock.speed <= 0) return error.InvalidPrisonerRock;
    return .{ .rock = rock };
}
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc", "atakd" };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    ready_ms: i64 = 0,
    emit_ms: i64 = 0,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.ready_ms, delta);
        try saved.active(&self.emit_ms, delta);
    }
};
pub const Rock = struct {
    damage: f32,
    pub fn validSaved(self: Rock, born_ms: i64, stepped_ms: i64) bool {
        return self.damage > 0 and self.damage <= 1000000 and stepped_ms <= born_ms + 3000;
    }
};
pub const rock_model = "models/global/e_rock3.dkm";
pub const render_tag = 10011;
pub fn inRange(distance: f32, melee: f32, roll: f32) bool {
    return distance <= melee or (distance >= 350 and distance <= 500 and roll < 0.1);
}
pub fn select(distance: f32, melee: f32, roll: f32) u3 {
    if (distance >= (350 + melee) * 0.5) return 3;
    return if (roll < 0.33) 0 else if (roll < 0.666) 1 else 2;
}
test "prisoner throws use the reviewed closed distance band" {
    const t = @import("std").testing;
    try t.expect(inRange(64, 64, 1));
    try t.expect(!inRange(349, 64, 0));
    try t.expect(inRange(350, 64, 0));
    try t.expect(inRange(500, 64, 0));
    try t.expect(!inRange(501, 64, 0));
    try t.expect(!inRange(400, 64, 0.1));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_blackprisoner", .kind = .blackprisoner },
    .{ .classname = "monster_whiteprisoner", .kind = .whiteprisoner },
};
