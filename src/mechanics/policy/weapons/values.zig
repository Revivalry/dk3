// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Supplied numeric weapon tuning is validated once for both runtime adapters.
const std = @import("std");
pub const Values = struct {
    ammoMax: i32 = 0,
    ammoCost: i32 = 0,
    initialAmmo: i32 = 0,
    damage: f32 = 0,
    range: f32 = 0,
    speed: f32 = 0,
    lifetime: f32 = 0,
    muzzle: [3]f32 = .{ 8, 12, 0 },
    alternate_muzzle: [3]f32 = .{ 8, 12, 0 },
    third_muzzle: [3]f32 = .{ 8, 12, 0 },
    cube_charges: i32 = 120,
    cube_health: i32 = 1000,
    cube_lifetime_ms: i32 = 60000,
};
/// The shared columns; `default_muzzle` replaces the supplied muzzle default for a class.
pub fn parse(row: anytype, default_muzzle: ?[3]f32) !Values {
    var result: Values = .{};
    inline for (.{ .{ "ammoMax", "ammo_max" }, .{ "ammoCost", "ammo_per_use" }, .{ "initialAmmo", "initial_ammo" } }) |field| {
        const value = try row.number(field[1], 0);
        if (!std.math.isFinite(value) or value < 0 or value > 32767) return error.InvalidWeaponAmmo;
        @field(result, field[0]) = @intFromFloat(value);
    }
    if (result.initialAmmo > result.ammoMax) return error.InvalidWeaponAmmo;
    inline for (.{ "damage", "range", "speed", "lifetime" }) |field| {
        const value = try row.number(field, 0);
        if (!std.math.isFinite(value) or value < 0) return error.InvalidWeaponValue;
        @field(result, field) = value;
    }
    inline for (.{ "x", "y", "z" }, 0..) |axis, i| {
        const fallback: f32 = if (default_muzzle) |muzzle| muzzle[i] else try row.number("projectile_" ++ axis, ([_]f32{ 8, 12, 0 })[i]);
        result.muzzle[i] = try row.number("projectile_" ++ axis ++ "1", fallback);
        result.alternate_muzzle[i] = try row.number("projectile_" ++ axis ++ "2", result.muzzle[i]);
        result.third_muzzle[i] = try row.number("projectile_" ++ axis ++ "3", result.muzzle[i]);
        if (!std.math.isFinite(result.muzzle[i])) return error.InvalidWeaponMuzzle;
        if (!std.math.isFinite(result.alternate_muzzle[i])) return error.InvalidWeaponMuzzle;
        if (!std.math.isFinite(result.third_muzzle[i])) return error.InvalidWeaponMuzzle;
    }
    return result;
}
