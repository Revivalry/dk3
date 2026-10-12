// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: knights. Knight attack selection and persistent, class-owned effects.
/// The persistent attack payloads this class launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{ .{ .tag = "knight_zap", .Payload = Zap, .modelless = true }, .{ .tag = "knight_punch", .Payload = void, .modelless = true } };
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{ .{ .kind = .knight1, .traits = .{ .sidekicks = .refuse_melee, .attack = .ground } }, .{ .kind = .knight2, .traits = .{ .sidekicks = .refuse_melee, .attack = .ground } } };
/// Pain: 5%. Knight1 has the single roll (`hita`); knight2 the generic handler, limit 35.
pub const pain_chance = 5;
pub const knight2_pain_limit = 35;
/// The knight's fireball lights its way.
pub const fireball_styles = [_]@import("../../../mechanics/policy/actors/fireballs.zig").Style{.{ .kind = .knight, .lit = true }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "knight";
/// Aidata: the flame knight's ranged attack is weapon 2; the lightning knight's is weapon 1
/// and its melee weapon 2.
pub const ClassTuning = struct { ranged: Weapon = .{} };
pub fn parseTuning(row: anytype, kind: class_traits.Kind, definition: anytype) !ClassTuning {
    if (kind == .knight1) return .{ .ranged = try Weapon.parse(row, "weapon2_") };
    (try Weapon.parse(row, "weapon2_")).primary(definition);
    return .{ .ranged = try Weapon.parse(row, "weapon1_") };
}
pub const flame_attacks = [_][]const u8{ "ataka", "atakb" };
// The lightning knight's model has no melee clips (the reference asks for an absent `ataka`),
// so it punches while running in place: each `runa` loop strikes on its second frame.
pub const lightning_attacks = [_][]const u8{ "runa", "atakc" };
pub const render_tag = 10044;
/// The projection frame naming which knight attack an attack entity draws.
pub const AttackFrame = enum(u8) { zap = 1, punch = 2 };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    sidestep_until: ?i64 = null,
    destination: [3]f32 = @splat(0),
    sword_lit: bool = false,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.deadline(&self.sidestep_until, delta);
    }
};
pub fn select(distance: f32) u3 {
    return if (distance <= 80) 0 else 1;
}
pub const inRange = @import("../../../mechanics/policy/actors/thrown_range.zig").inRange;
pub const Weapon = @import("../../../mechanics/policy/actors/weapon.zig").Tuning;
pub const Bolt = struct {
    born_ms: i64,
    next_ms: i64,
    origin: [3]f32,
    contact: [3]f32,
    active: bool = true,
};
pub const Zap = struct {
    target: u32,
    destination: [3]f32,
    emitted: u2 = 0,
    bolts: [2]?Bolt = @splat(null),
    pub fn rebase(self: *Zap, delta: i64) !void {
        for (&self.bolts) |*maybe| if (maybe.*) |*bolt| {
            try saved.shift(&bolt.born_ms, delta);
            try saved.shift(&bolt.next_ms, delta);
        };
    }
    pub fn remapIds(self: *Zap, map: anytype) !void {
        try map.one(&self.target);
    }
    /// Bolts leave 100 ms apart, each living at most 400 ms.
    pub fn validSaved(self: Zap, born_ms: i64, stepped_ms: i64) bool {
        if (self.target == 0 or self.emitted > 2 or stepped_ms > born_ms + 500) return false;
        for (self.bolts, 0..) |maybe, i| if (maybe) |bolt| {
            if (i >= self.emitted or bolt.born_ms != born_ms + @as(i64, @intCast(i + 1)) * 100 or bolt.next_ms <= bolt.born_ms or bolt.next_ms > bolt.born_ms + 400) return false;
        };
        return true;
    }
};
test "knights select melee at eighty" {
    try std.testing.expectEqual(@as(u3, 0), select(80));
    try std.testing.expectEqual(@as(u3, 1), select(81));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_knight1", .kind = .knight1 },
    .{ .classname = "monster_knight2", .kind = .knight2 },
};
