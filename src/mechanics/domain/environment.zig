// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Liquid exposure and air reserve. Independent implementation of reviewed rules.
const std = @import("std");
pub const Kind = enum { dry, water, lava, slime, nitro };
/// Who is exposed: the player, a party member, or an actor by its body.
pub const Subject = enum { player, party_member, land_actor, aquatic_actor, robot };
pub const Exposure = struct {
    kind: Kind = .dry,
    level: u2 = 0,
    subject: Subject = .player,
    active: bool = true,
    protected_air: bool = false,
    protected_liquid: bool = false,
    cold_water: bool = false,
    /// The subject swims when submerged (traits `amphibious`): water never drowns it.
    amphibious: bool = false,
};
pub const Tick = struct { damage: i32 = 0, bypass_armor: bool = false, freeze: f32 = 0, drowning: bool = false, surfaced: bool = false };
pub const State = struct {
    initialized: bool = false,
    next_ms: i64 = 0,
    air_until_ms: i64 = 0,
    damage_ms: i64 = 0,
    cold_start_ms: i64 = 0,
    cold_next_ms: i64 = 0,
    nitro_ms: ?i64 = null,
    fraction: f32 = 0,
    level: u2 = 0,
    kind: Kind = .dry,
    pub fn initialize(self: *State, now: i64, subject: Subject) void {
        self.* = .{ .initialized = true, .next_ms = now, .air_until_ms = now + (if (subject == .player or subject == .party_member) @as(i64, 12000) else 0), .cold_start_ms = now + 4000 };
    }
    /// Caller supplies measured contents for each simulation sample. Damage is
    /// sampled at the reference 100 ms gameplay cadence, independent of rendering.
    pub fn sample(self: *State, at: i64, exposure: Exposure) Tick {
        var result: Tick = .{};
        // A party member breathes as the player does: twelve seconds of air, refilled whenever
        // its head is out of the water (a sidekick treading water at the surface breathes).
        const breathes_like_player = exposure.subject == .player or exposure.subject == .party_member;
        const air: i64 = if (breathes_like_player) 12000 else 10000;
        const prior_level = self.level;
        self.level = exposure.level;
        self.kind = exposure.kind;
        if (!exposure.active) {
            self.air_until_ms = at + air;
            self.damage_ms = at;
            self.cold_start_ms = at + 4000;
            self.cold_next_ms = at;
            self.nitro_ms = null;
            self.fraction = 0;
            return result;
        }
        if (exposure.subject == .player and exposure.kind == .water and exposure.level > 0 and exposure.cold_water and !exposure.protected_air) {
            if (at >= self.cold_start_ms and at >= self.cold_next_ms) {
                result.freeze = 0.15;
                self.cold_next_ms = at + 2000;
            }
        } else self.cold_start_ms = at + 4000;
        if (exposure.kind == .nitro and exposure.level > 0) {
            switch (exposure.subject) {
                .player => result.damage = 32000,
                .party_member => {
                    if (self.nitro_ms == null) self.nitro_ms = at + 3000;
                },
                .land_actor => result.damage = @as(i32, exposure.level) * 50,
                .aquatic_actor, .robot => {},
            }
        }
        // The authored party-member freeze/death callback stays pending after contact.
        if (self.nitro_ms) |deadline| {
            if (at >= deadline) result.damage = 32000;
        }
        if (result.damage > 0) return result;
        const drowning = if (exposure.subject == .aquatic_actor) exposure.level == 0 else exposure.kind == .water and exposure.level == 3 and !exposure.protected_air and !exposure.amphibious;
        if (!drowning) {
            if (breathes_like_player or exposure.level == 0 or exposure.subject == .aquatic_actor or exposure.protected_air or exposure.amphibious) self.air_until_ms = at + air;
            if (prior_level == 3 and exposure.level < 3) result.surfaced = true;
        } else if (at >= self.air_until_ms and at >= self.damage_ms) {
            const rate: f32 = if (exposure.subject == .player or exposure.subject == .aquatic_actor) 0.75 else 0.05;
            self.fraction += @as(f32, @floatFromInt(at - self.air_until_ms)) * 0.001 * rate;
            self.damage_ms = at + if (exposure.subject == .player) @as(i64, 1000) else 100;
            result.bypass_armor = exposure.subject == .player;
            result.drowning = true;
        }
        if (exposure.level > 0 and !exposure.protected_liquid and exposure.subject != .aquatic_actor and at >= self.damage_ms) {
            const player = exposure.subject == .player;
            if (exposure.kind == .lava or exposure.kind == .slime) {
                const per_level: f32 = if (exposure.kind == .lava) (if (player) @as(f32, 10) else 5) else (if (player) @as(f32, 4) else 2);
                self.fraction += @as(f32, @floatFromInt(exposure.level)) * per_level;
                self.damage_ms = at + if (!player) @as(i64, 100) else if (exposure.kind == .lava) @as(i64, 200) else 1000;
            }
        }
        result.damage = @intFromFloat(@floor(self.fraction));
        self.fraction -= @floatFromInt(result.damage);
        return result;
    }
};
pub fn fall(speed: f32, acro: i32, boosted: bool) i32 {
    if (boosted or !std.math.isFinite(speed) or speed <= 450) return 0;
    return @intFromFloat(@floor((speed - 450) * 0.0625) * (1 - @as(f32, @floatFromInt(std.math.clamp(acro, 0, 5))) * 0.1));
}

test "air recovery liquid cadence and party-member nitro use distinct contracts" {
    const t = std.testing;
    var state: State = .{};
    state.initialize(0, .player);
    const water: Exposure = .{ .kind = .water, .level = 3 };
    try t.expectEqual(@as(i32, 0), state.sample(11900, water).damage);
    try t.expectEqual(@as(i32, 0), state.sample(12000, water).damage);
    _ = state.sample(13000, water);
    const hurt = state.sample(14000, water);
    try t.expect(hurt.damage > 0 and hurt.drowning and hurt.bypass_armor);
    try t.expect(state.sample(14100, .{ .kind = .water, .level = 1 }).surfaced);
    try t.expectEqual(@as(i64, 26100), state.air_until_ms);
    state.initialize(0, .player);
    try t.expectEqual(@as(i32, 20), state.sample(0, .{ .kind = .lava, .level = 2 }).damage);
    try t.expectEqual(@as(i32, 0), state.sample(100, .{ .kind = .lava, .level = 2 }).damage);
    try t.expectEqual(@as(i32, 20), state.sample(200, .{ .kind = .lava, .level = 2 }).damage);
    try t.expectEqual(@as(i32, 0), state.sample(400, .{ .kind = .lava, .level = 2, .protected_liquid = true }).damage);
    state.initialize(0, .party_member);
    try t.expectEqual(@as(i32, 0), state.sample(0, .{ .kind = .nitro, .level = 1, .subject = .party_member }).damage);
    try t.expectEqual(@as(i32, 32000), state.sample(3000, .{ .subject = .party_member }).damage);
    state.initialize(0, .robot);
    try t.expectEqual(@as(i32, 0), state.sample(0, .{ .kind = .nitro, .level = 3, .subject = .robot }).damage);
    try t.expectEqual(@as(i32, 9), fall(600, 0, false));
    try t.expectEqual(@as(i32, 0), fall(1000, 1, true));
}

test "amphibious creatures never drown but liquids still burn them" {
    const t = std.testing;
    var state: State = .{};
    state.initialize(0, .robot);
    var damage: i32 = 0;
    var at: i64 = 0;
    while (at <= 120_000) : (at += 50) damage += state.sample(at, .{ .kind = .water, .level = 3, .subject = .robot, .amphibious = true }).damage;
    try t.expectEqual(@as(i32, 0), damage);
    try t.expect(state.sample(at + 100, .{ .kind = .lava, .level = 1, .subject = .land_actor, .amphibious = true }).damage > 0);
    var drowning: State = .{};
    drowning.initialize(0, .robot);
    damage = 0;
    at = 0;
    while (at <= 30_000) : (at += 50) damage += drowning.sample(at, .{ .kind = .water, .level = 3, .subject = .robot }).damage;
    try t.expect(damage > 0);
}

test "a party member surfacing between dives gets its air back" {
    const t = std.testing;
    var state: State = .{};
    state.initialize(0, .party_member);
    var damage: i32 = 0;
    var at: i64 = 0;
    // Three 11 s dives with a second at the surface (head out, level 2) between them.
    for (0..3) |_| {
        const surface = at + 11_000;
        while (at < surface) : (at += 50) damage += state.sample(at, .{ .kind = .water, .level = 3, .subject = .party_member }).damage;
        const dive = at + 1_000;
        while (at < dive) : (at += 50) damage += state.sample(at, .{ .kind = .water, .level = 2, .subject = .party_member }).damage;
    }
    try t.expectEqual(@as(i32, 0), damage);
    // Held under past its air, it drowns.
    const held = at + 20_000;
    while (at < held) : (at += 50) damage += state.sample(at, .{ .kind = .water, .level = 3, .subject = .party_member }).damage;
    try t.expect(damage > 0);
}
