// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: dwarf. Dwarf combat choices and throwing-axe lifecycle. Numeric weapon tuning is supplied.
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .dwarf, .traits = .{ .attack = .ground } }};
/// The reference's generic pain: two 20% rolls, `hita` on the second for a hit of 15 or more.
pub const pain_chance = 20;
pub const pain_limit = 15;
pub const ClassTuning = Tuning;
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    return Tuning.parse(row);
}
pub const attacks = [_][]const u8{ "ataka", "atakc", "atakd" };
pub const axe_model = "models/e3/me_axe.dkm";
pub const flight_sound = "e3/m_dwaraxfly.wav";
pub const wall_sound = "global/m_bodyhitc.wav";
pub const flesh_sound = "global/e_bulfleshc.wav";
pub const axe_tag = 10001;
pub fn select(distance: f32, random: f32) u3 {
    if (distance <= 80) return 0;
    return if (distance > 100 and distance < 250 and random < 0.7) 1 else 2;
}
pub const inRange = @import("../../../mechanics/policy/actors/thrown_range.zig").inRange;
pub const Tuning = struct {
    damage: f32 = 0,
    random_damage: f32 = 0,
    speed: f32 = 0,
    range: f32 = 0,
    offset: [3]f32 = @splat(0),
    pub fn parse(row: anytype) !Tuning {
        var value: Tuning = .{ .damage = try row.number("weapon2_base_damage", 0), .random_damage = try row.number("weapon2_random_damage", 0), .speed = try row.number("weapon2_speed", 0), .range = try row.number("weapon2_distance", 0) };
        inline for (.{ "x", "y", "z" }, 0..) |axis, i| value.offset[i] = try row.number("weapon2_offset_" ++ axis, 0);
        if (value.damage <= 0 or value.damage > 1000000 or value.random_damage < 0 or value.random_damage > 1000000 or value.speed <= 0 or value.speed > 65536 or value.range <= 0 or value.range > 65536) return error.InvalidDwarfTuning;
        for (value.offset) |axis| if (@abs(axis) > 1024) return error.InvalidDwarfOffset;
        return value;
    }
};
pub const Axe = struct {
    owner: u32,
    damage: f32,
    born_ms: i64,
    stepped_ms: i64,
    contact_ms: ?i64 = null,
    phase: enum { flying, falling, resting } = .flying,
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Axe, map: anytype) !void {
        try map.one(&self.owner);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Axe, clock: anytype) !void {
        try clock.shift(&self.born_ms);
        try clock.shift(&self.stepped_ms);
        try clock.deadline(&self.contact_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Axe, check: anytype) !void {
        try check.require(.{ "Transform", "Velocity", "Body", "Binding" });
        if (self.owner == 0 or self.damage <= 0 or self.damage > 1000000 or self.stepped_ms < self.born_ms or (self.phase == .flying) != (self.contact_ms == null)) return error.InvalidSavedDwarfAxe;
    }
};
test "dwarf distinguishes close chops, running chops and thrown axes" {
    const t = std.testing;
    try t.expectEqual(@as(u3, 0), select(80, 0.9));
    try t.expectEqual(@as(u3, 1), select(180, 0.69));
    try t.expectEqual(@as(u3, 2), select(180, 0.7));
    try t.expectEqual(@as(u3, 2), select(250, 0));
    try t.expect(inRange(79, 80, 500, 1, 1));
    try t.expect(!inRange(500, 80, 500, 0, 0));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_dwarf", .kind = .dwarf },
};
