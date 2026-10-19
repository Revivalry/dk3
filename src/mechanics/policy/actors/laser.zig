// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Inmater and Lasergat share the authored laser projectile, with distinct aiming.
pub const sprite = "models/e1/me_mater.sp2";
pub const muzzle_model = "models/e1/me_mater.dkm";
pub const render_tag = 10006;
pub const Tuning = struct {
    damage: f32 = 0,
    random_damage: f32 = 0,
    speed: f32 = 0,
    range: f32 = 0,
    offset: [3]f32 = @splat(0),
    spread: [2]f32 = @splat(0),
    pub fn parse(row: anytype, comptime prefix: []const u8) !Tuning {
        var result: Tuning = .{ .damage = try row.number(prefix ++ "base_damage", 0), .random_damage = try row.number(prefix ++ "random_damage", 0), .speed = try row.number(prefix ++ "speed", 0), .range = try row.number(prefix ++ "distance", 0), .spread = .{ try row.number(prefix ++ "spread_x", 0), try row.number(prefix ++ "spread_z", 0) } };
        inline for (.{ "x", "y", "z" }, 0..) |axis, i| result.offset[i] = try row.number(prefix ++ "offset_" ++ axis, 0);
        if (result.damage < 0 or result.damage > 1000000 or result.random_damage < 0 or result.random_damage > 1000000 or result.speed <= 0 or result.speed > 65536 or result.range <= 0 or result.range > 65536) return error.InvalidActorLaser;
        for (result.offset) |value| if (@abs(value) > 1024) return error.InvalidActorLaser;
        for (result.spread) |value| if (value < 0 or value > 8192) return error.InvalidActorLaser;
        return result;
    }
};
/// A laser's look: ordinary, or a class's own (that class declares `laser_look` for its kind).
pub const Kind = enum { ordinary, death };
/// How a class's laser kind looks and behaves: a bolt living `lifetime_ms`, splashing on contact
/// when `splash_radius` is set (playing one of `contact_sounds`).
pub const Look = struct {
    kind: Kind,
    model: []const u8,
    tag: i32,
    lifetime_ms: i64 = ordinary_lifetime_ms,
    splash_radius: ?f32 = null,
    contact_sounds: [2][]const u8 = .{ "", "" },
};
pub const ordinary_lifetime_ms: i64 = 10000;
/// The look a class declares for `kind`, or null for the ordinary laser.
pub fn lookOf(kind: Kind) ?Look {
    const catalog = @import("../../../actor_catalog.zig");
    inline for (@typeInfo(catalog).@"struct".decls) |declaration| {
        const owner = @field(catalog, declaration.name);
        if (@TypeOf(owner) == type and @typeInfo(owner) == .@"struct" and @hasDecl(owner, "laser_look")) {
            if (owner.laser_look.kind == kind) return owner.laser_look;
        }
    }
    return null;
}
pub fn lifetimeMs(kind: Kind) i64 {
    return if (lookOf(kind)) |styled| styled.lifetime_ms else ordinary_lifetime_ms;
}
pub const State = struct {
    owner: u32,
    damage: f32,
    born_ms: i64,
    stepped_ms: i64,
    contact_ms: ?i64 = null,
    normal: [3]f32 = @splat(0),
    kind: Kind = .ordinary,
    seed: u32 = 0,
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.owner);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.shift(&self.born_ms);
        try clock.shift(&self.stepped_ms);
        try clock.deadline(&self.contact_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const State, check: anytype) !void {
        try check.require(.{ "Transform", "Velocity", "Body", "Binding" });
        if (self.owner == 0 or self.damage < 0 or self.damage > 1000000 or self.stepped_ms < self.born_ms or self.stepped_ms > self.born_ms + lifetimeMs(self.kind)) return error.InvalidSavedActorLaser;
        if (self.contact_ms) |at| if (at < self.born_ms) return error.InvalidSavedActorLaser;
    }
};
