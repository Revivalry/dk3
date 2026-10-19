// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: metamaser. Weapon description: data, hooks and class rules for metamaser.
const profiles = @import("../../../mechanics/policy/weapons/profiles.zig");
pub const id: u5 = 26;
/// The cube launcher's muzzle when the row gives none.
pub const default_muzzle = [3]f32{ 6, 18, 19 };
/// The second projectile columns tune the thrown cube: charges, health and lifetime (s).
pub fn parseValues(values: *@import("../../../mechanics/policy/weapons/values.zig").Values, row: anytype) !void {
    const charges = try row.number("projectile_x2", 120);
    const health = try row.number("projectile_y2", 1000);
    const lifetime = try row.number("projectile_z2", 60);
    if (!@import("std").math.isFinite(charges) or charges < 1 or charges > 120 or !@import("std").math.isFinite(health) or health < 1 or health > 32767 or !@import("std").math.isFinite(lifetime) or lifetime <= 0 or lifetime > 3600) return error.InvalidCube;
    values.cube_charges = @intFromFloat(charges);
    values.cube_health = @intFromFloat(health);
    values.cube_lifetime_ms = @intFromFloat(lifetime * 1000);
}
pub const spec: profiles.Spec = .{
    .player_grip = .rifle,
    .combat = .flown,
    .respects_weapons_stay = false,
    .pickup_respawn_ms = 60000,
    .ammo_class = "ammo_metamaser", // metamaser
    .projectile = .{ .gravity = true, .action_delay_ms = 300, .mins = .{ -6, -6, 0 }, .maxs = .{ 6, 6, 12 } },
    .visual = .{ .projectile_model = "models/e4/we_mmprj.dkm", .projectile_scale = 8, .impact_sprite = "models/e4/we_mmaserexp.sp2", .color = .{ 0, 0, 1 }, .glow = false },
    .world_model = "models/e4/a_mmaser.dkm",
    .animation = .{
        .view_model = "models/e4/w_mmaser.dkm",
        .ready = "ready",
        .away = "away",
        .fire = "shoot",
        .idle = .{ "amba", null, null },
        .raise_ms = 400,
        .drop_ms = 250,
    },
    .audio = .{
        .fire = "e2/we_sflareshoota.wav",
        .ready = "e4/we_metaready.wav",
        .away = "e4/we_metaaway.wav",
    },
    .projectile_muzzle = true,
};
pub const identity = .{ .classname = "weapon_metamaser", .label = "Metamaser", .episode = 4, .interval = 1000 };

const shot_rules = @import("../../../mechanics/policy/weapons/shot.zig");
pub fn predictionShot(controller: anytype) shot_rules.Shot {
    return shot_rules.standard(controller);
}

pub const flight_tag = "metamaser";
pub const Track = struct { target: u32 = 0, until_ms: i64 = 0, damage_ms: i64 = 0, sound_ms: i64 = 0 };
pub const BallisticState = struct {
    phase: enum { flight, arming, tracking, dying } = .flight,
    settled: bool = false,
    next_ms: i64 = 100,
    arm_ms: i64 = 0,
    beep_ms: i64 = 0,
    pause_ms: i64 = 0,
    end_ms: i64 = 60000,
    burst_ms: i64 = 0,
    bursts: u8 = 0,
    charges: i32 = 120,
    pain_level: i32 = 0,
    receipt: u32 = 0,
    range: f32 = 512,
    targets: [12]Track = @splat(.{}),
    acquired: [4]Track = @splat(.{}),
    pub fn settle(self: *BallisticState, age: i64) void {
        self.settled = true;
        if (self.phase != .flight) return;
        self.phase = .arming;
        self.arm_ms = age + 3000;
        self.beep_ms = age + 500;
        // Reference threshold is based on its 1000-health default, even with supplied 300 health.
        self.pain_level = 700;
    }
    pub fn die(self: *BallisticState, age: i64) void {
        if (self.phase == .dying) return;
        self.phase = .dying;
        self.end_ms = age + 5000;
        self.burst_ms = age;
        self.acquired = @splat(.{});
        self.targets = @splat(.{});
    }
    pub fn include(self: *BallisticState, target: u32, age: i64) bool {
        if (target == 0) return false;
        for (self.targets) |existing| if (existing.target == target) return false;
        for (&self.targets) |*empty| if (empty.target == 0) {
            empty.* = .{ .target = target, .until_ms = age + 3000 };
            return true;
        };
        return false;
    }
    pub fn forget(self: *BallisticState, target: u32) void {
        for (&self.targets) |*track| if (track.target == target) {
            track.* = .{};
        };
        for (&self.acquired) |*track| if (track.target == target) {
            track.* = .{};
        };
    }
    pub fn lock(self: *BallisticState, target: u32, age: i64, random: f32) bool {
        if (target == 0) return false;
        for (self.acquired) |existing| if (existing.target == target) return false;
        for (&self.acquired) |*empty| if (empty.target == 0) {
            empty.* = .{ .target = target, .until_ms = age + 500 + @as(i64, @intFromFloat(500 * random)), .damage_ms = age, .sound_ms = age };
            return true;
        };
        return false;
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *BallisticState, map: anytype) !void {
        for (&self.targets) |*track| try map.one(&track.target);
        for (&self.acquired) |*track| try map.one(&track.target);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`); `owner` is its projectile's.
    pub fn validateSaved(self: *const BallisticState, check: anytype, owner: u32) !void {
        _ = owner;
        if (self.next_ms < 0 or self.arm_ms < 0 or self.beep_ms < 0 or self.pause_ms < 0 or self.burst_ms < 0 or self.end_ms < 0 or self.end_ms > 3605000 or self.charges < 0 or self.charges > 120 or self.bursts > 21 or self.range <= 0 or self.range > 8192) return error.InvalidSavedProjectile;
        try check.require(.{ "Random", "Body", "Health", "Hurt" });
        for (self.targets, 0..) |track, i| if (track.target != 0) {
            if (track.until_ms < 0) return error.InvalidSavedProjectile;
            for (self.targets[0..i]) |previous| if (previous.target == track.target) return error.InvalidSavedProjectile;
            if (check.find(track.target)) |target| try target.require(.{ "Health", "Binding" });
        };
        for (self.acquired, 0..) |track, i| if (track.target != 0) {
            if (track.until_ms < 0 or track.damage_ms < 0 or track.sound_ms < 0) return error.InvalidSavedProjectile;
            for (self.acquired[0..i]) |previous| if (previous.target == track.target) return error.InvalidSavedProjectile;
            var retained = false;
            for (self.targets) |target| if (target.target == track.target) {
                retained = true;
            };
            if (!retained) return error.InvalidSavedProjectile;
        };
    }
    /// Probe details for `dk3_runtime_weapons` (weapon_probe.zig).
    pub fn describe(self: *const BallisticState, buffer: []u8) ![]const u8 {
        return @import("std").fmt.bufPrint(buffer, "phase={s} charges={d} locks={d},{d},{d},{d} bursts={d}", .{ @tagName(self.phase), self.charges, self.acquired[0].target, self.acquired[1].target, self.acquired[2].target, self.acquired[3].target, self.bursts });
    }
    /// Its line for `dk3_runtime_projectiles`.
    pub fn probeLine(self: *const BallisticState, buffer: []u8, entity_id: u32, age_ms: i64, health: i32) ![:0]const u8 {
        return @import("std").fmt.bufPrintZ(buffer, "dk3 zig metamaser state: id={d} phase={s} health={d} charges={d} locks={d},{d},{d},{d} bursts={d} end={d}\n", .{ entity_id, @tagName(self.phase), health, self.charges, self.acquired[0].target, self.acquired[1].target, self.acquired[2].target, self.acquired[3].target, self.bursts, self.end_ms - age_ms });
    }
};
pub const Ring = struct {
    owner: u32,
    cube: u32,
    damage: f32,
    born_ms: i64,
    next_ms: i64,
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Ring, map: anytype) !void {
        try map.fields(self, .{ "owner", "cube" });
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Ring, clock: anytype) !void {
        try clock.shift(&self.born_ms);
        try clock.shift(&self.next_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Ring, check: anytype) !void {
        if (self.damage < 0 or self.damage > 1000000 or self.cube == 0) return error.InvalidSavedMetaEffect;
        try check.require(.{"Binding"});
        if ((try check.get("Binding")).model != 0) return error.InvalidSavedMetaEffect;
        if (self.next_ms < self.born_ms) return error.InvalidSavedMetaEffect;
        if (check.find(self.cube)) |cube| {
            const projectile = cube.get("Projectile") catch return error.InvalidSavedMetaEffect;
            if (projectile.flight != .metamaser or projectile.owner != self.owner) return error.InvalidSavedMetaEffect;
        }
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
};
pub const Laser = struct {
    owner: u32,
    cube: u32,
    damage: f32,
    next_ms: i64,
    expires_ms: i64,
    fired: bool = false,
    endpoint: [3]f32 = @splat(0),
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Laser, map: anytype) !void {
        try map.fields(self, .{ "owner", "cube" });
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Laser, clock: anytype) !void {
        try clock.shift(&self.next_ms);
        try clock.shift(&self.expires_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Laser, check: anytype) !void {
        if (self.damage < 0 or self.damage > 1000000 or self.cube == 0) return error.InvalidSavedMetaEffect;
        try check.require(.{"Binding"});
        if ((try check.get("Binding")).model != 0) return error.InvalidSavedMetaEffect;
        try check.require(.{"Random"});
        // Final burst lasers may expire before their staggered first shot.
        if (self.next_ms -| self.expires_ms > 400) return error.InvalidSavedMetaEffect;
        if (check.find(self.cube)) |cube| {
            const projectile = cube.get("Projectile") catch return error.InvalidSavedMetaEffect;
            if (projectile.flight != .metamaser or projectile.owner != self.owner) return error.InvalidSavedMetaEffect;
        }
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
};
pub fn ringDamage(damage: f32, age: i64, distance: f32, vertical: f32, self_hit: bool) f32 {
    if (age < 0 or age > 2000 or @abs(vertical) >= 64) return 0;
    const radius = @as(f32, @floatFromInt(age)) * (425.0 / 2000.0);
    if (distance <= radius - 25 or distance >= radius) return 0;
    return damage * @max(0, (425 - distance) / 425) * (if (self_hit) @as(f32, 0.5) else 1);
}
pub const visual = .{ .ring = "models/e1/we_shockring.sp2", .flare = "models/global/e_flblue.sp2" };
pub const sounds = .{ .beep = "e1/we_c4beepa.wav", .small = [_][:0]const u8{ "e4/we_metamaszapa.wav", "e4/we_metamaszapb.wav" }, .large = [_][:0]const u8{ "e4/we_metamalzapa.wav", "e4/we_metamalzapb.wav" } };
pub fn flightMotion(_: *BallisticState, frame: @import("../../../mechanics/policy/weapons/ballistics.zig").Frame) @import("../../../mechanics/policy/weapons/ballistics.zig").Motion {
    return .{ .velocity = frame.velocity, .gravity = 800 };
}

pub fn update(controller: anytype) void {
    controller.automatic(@This());
}

test "Metamaser locks, charges and destruction bands retain class limits" {
    const catalog = @import("../../../weapon_catalog.zig");
    const std = @import("std");
    var cube: BallisticState = .{ .charges = 6, .end_ms = 19000 };
    cube.settle(800);
    try std.testing.expectEqual(@as(i64, 3800), cube.arm_ms);
    for (1..13) |target| try std.testing.expect(cube.include(@intCast(target), 1000));
    try std.testing.expect(!cube.include(13, 1000));
    for (1..5) |target| try std.testing.expect(cube.lock(@intCast(target), 1100, 0.5));
    try std.testing.expect(!cube.lock(5, 1100, 0.5));
    try std.testing.expectEqual(@as(i64, 1850), cube.acquired[0].until_ms);
    cube.forget(1);
    try std.testing.expect(cube.lock(5, 1100, 0.5));
    cube.die(5000);
    try std.testing.expectEqual(@as(i64, 10000), cube.end_ms);
    cube.die(6000);
    try std.testing.expectEqual(@as(i64, 10000), cube.end_ms);
    try std.testing.expectEqual(@as(f32, 0), ringDamage(40, 1000, 180, 0, false));
    const full = ringDamage(40, 1000, 200, 0, false);
    try std.testing.expect(full > 0);
    try std.testing.expectEqual(full * 0.5, ringDamage(40, 1000, 200, 0, true));
    try std.testing.expectEqual(@as(f32, 0), ringDamage(40, 1000, 200, 64, false));
    for (catalog.entries) |entry| try std.testing.expect(entry.spec.combat != .pending);
}
