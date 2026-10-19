// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Supplied attack tuning; class policies choose which authored weapon to use.
pub const Tuning = struct {
    damage: f32 = 0,
    random_damage: f32 = 0,
    range: f32 = 0,
    speed: f32 = 0,
    offset: [3]f32 = @splat(0),
    spread: [2]f32 = @splat(0),
    pub fn parse(row: anytype, comptime prefix: []const u8) !Tuning {
        var result: Tuning = .{ .damage = try row.number(prefix ++ "base_damage", 0), .random_damage = try row.number(prefix ++ "random_damage", 0), .range = try row.number(prefix ++ "distance", 0), .speed = try row.number(prefix ++ "speed", 0), .spread = .{ try row.number(prefix ++ "spread_x", 0), try row.number(prefix ++ "spread_z", 0) } };
        inline for (.{ "x", "y", "z" }, 0..) |axis, i| result.offset[i] = try row.number(prefix ++ "offset_" ++ axis, 0);
        if (result.damage <= 0 or result.damage > 1000000 or result.random_damage < 0 or result.random_damage > 1000000 or result.range <= 0 or result.range > 65536 or result.speed < 0 or result.speed > 65536) return error.InvalidActorWeaponTuning;
        for (result.offset) |axis| if (@abs(axis) > 1024) return error.InvalidActorWeaponOffset;
        for (result.spread) |axis| if (axis < 0 or axis > 8192) return error.InvalidActorWeaponSpread;
        return result;
    }
    /// Makes this weapon the class's primary attack: the definition's shared damage, range,
    /// offset and spread read it.
    pub fn primary(self: Tuning, definition: anytype) void {
        definition.damage = self.damage;
        definition.random_damage = self.random_damage;
        definition.range = self.range;
        definition.offset = self.offset;
        definition.spread = self.spread;
    }
};
/// Reference ai_fire_bullet: a monster round that meets a body hurts it only past the skill's
/// chance (half the time on the easiest skills).
pub fn damageAdmitted(skill: u8, random: f32) bool {
    const level: f32 = if (skill <= 2) 1 else if (skill == 3) 2 else 3;
    return random > 0.5 / level;
}
test "monster bullets are admitted past the skill's chance" {
    const t = @import("std").testing;
    try t.expect(!damageAdmitted(3, 0.25));
    try t.expect(damageAdmitted(3, 0.251));
    try t.expect(!damageAdmitted(1, 0.5) and damageAdmitted(5, 0.17));
}
