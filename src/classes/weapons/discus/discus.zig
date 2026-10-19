// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: discus. Weapon description: data, hooks and class rules for discus.
const profiles = @import("../../../mechanics/policy/weapons/profiles.zig");
pub const id: u5 = 9;
pub const spec: profiles.Spec = .{
    .respects_weapons_stay = false,
    .companion = .{ .slot = 0, .ammunition = false, .empty_melee = true, .clearance = 8 },
    .player_grip = .glove, // discus
    .combat = .flown,
    .visual = .{ .projectile_model = "models/e2/we_discus.dkm", .glow = false },
    .world_model = "models/e2/a_discus.dkm",
    .animation = .{
        .view_model = "models/e2/w_discus.dkm",
        .ready = "readya",
        .away = "awaya",
        .fire = "shootb",
        .idle = .{ "amba", "ambb", null },
        .idle_needs_ammo = true,
        .alternate = "shootc",
        .raise_ms = 400,
        .drop_ms = 350,
    },
    .audio = .{
        .fire = "e2/we_discfire.wav",
        .ready = "e2/we_discreadya.wav",
        .away = "e2/we_discawaya.wav",
        .idle = .{ "e2/we_discawaya.wav", "e2/we_discambd.wav", null },
    },
    .projectile = .{ .loop_sound = "e2/we_discshoota.wav", .mins = .{ -8, -8, -4 }, .maxs = .{ 8, 8, 4 }, .action_delay_ms = 300, .inertial = true, .lifetime_ms = 60000 },
    .projectile_muzzle = true,
};
pub const identity = .{ .classname = "weapon_discus", .label = "Discus of Daedalus", .episode = 2, .interval = 650 };

const shot_rules = @import("../../../mechanics/policy/weapons/shot.zig");
const v = @import("../../../mechanics/policy/weapons/vector.zig");
const ballistic = @import("../../../mechanics/policy/weapons/ballistics.zig");
pub const flight_tag = "discus";
pub const catch_sound = "e2/we_disccatch.wav";
pub const BallisticState = struct {
    next_ms: i64 = 100,
    drop_ms: i64 = 5000,
    target: ?u32 = null,
    forward: v.Vec = .{ 1, 0, 0 },
    base_speed: f32 = 1000,
    speed: f32 = 1000,
    clear: u8 = 0,
    seek: bool = true,
    reflected: bool = false,
    dropped: bool = false,
    pickup_only: bool = false,
    pub fn tick(self: *BallisticState, age: i64, wet: bool) bool {
        if (age < self.next_ms) return false;
        self.next_ms = age + 100;
        self.clear -|= 1;
        self.speed = if (wet) self.speed * 0.75 else @min(self.base_speed, self.speed * 1.25);
        return true;
    }
    pub fn mustDrop(self: BallisticState, age: i64) bool {
        return age >= self.drop_ms or self.speed < self.base_speed / 8;
    }
    pub fn drop(self: *BallisticState, owner: u32, age: i64) void {
        self.dropped = true;
        self.pickup_only = true;
        self.target = owner;
        self.seek = true;
        self.drop_ms = age + 5000;
    }
    pub fn home(self: *BallisticState, delta: v.Vec, owner: bool) void {
        self.forward = v.normal(if (owner) delta else v.add(v.scale(self.forward, self.speed * 0.35), v.scale(delta, 0.65)));
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *BallisticState, map: anytype) !void {
        try map.optional(&self.target);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`); `owner` is its projectile's.
    pub fn validateSaved(self: *const BallisticState, check: anytype, owner: u32) !void {
        _ = owner;
        if (self.next_ms < 0 or self.drop_ms < 0 or self.clear > 3 or self.base_speed <= 0 or self.base_speed > 100000 or self.speed < 0 or self.speed > 100000 or (self.dropped and !self.pickup_only)) return error.InvalidSavedProjectile;
        try check.require(.{"Random"});
        if (self.target) |entity_id| if (check.find(entity_id)) |target| try target.require(.{"Health"});
    }
    /// Probe details for `dk3_runtime_weapons` (weapon_probe.zig).
    pub fn describe(self: *const BallisticState, buffer: []u8) ![]const u8 {
        return @import("std").fmt.bufPrint(buffer, "target={d} reflected={d} dropped={d} pickup={d}", .{ self.target orelse 0, @intFromBool(self.reflected), @intFromBool(self.dropped), @intFromBool(self.pickup_only) });
    }
    /// Its line for `dk3_runtime_projectiles`.
    pub fn probeLine(self: *const BallisticState, buffer: []u8, entity_id: u32, age_ms: i64, health: i32) ![:0]const u8 {
        _ = age_ms;
        _ = health;
        return @import("std").fmt.bufPrintZ(buffer, "dk3 zig discus state: id={d} target={d} reflected={d} dropped={d} pickup={d} next={d}\n", .{ entity_id, self.target orelse 0, @intFromBool(self.reflected), @intFromBool(self.dropped), @intFromBool(self.pickup_only), self.next_ms });
    }
};
pub fn meleeOrigin(position: v.Vec, muzzle: v.Vec, ducked: bool) v.Vec {
    return v.add(v.add(position, muzzle), .{ 0, 0, if (ducked) @as(f32, -25) else 0 });
}
pub fn combatFor(sequence: i32) profiles.Combat {
    return if (sequence >= 128) .melee else .flown;
}
pub fn meleePlan(_: i32, _: i32) !@import("../../../mechanics/policy/weapons/melee.zig").Plan {
    return .{ .delays_ms = .{ 250, 0 }, .range = 120, .world_muzzle = true, .crouching_height = -25, .inertial = true, .scale_timing = true };
}
pub fn flightMotion(_: *BallisticState, frame: ballistic.Frame) ballistic.Motion {
    return .{ .velocity = frame.velocity };
}
pub fn attackAnimation(sequence: i32, _: i32) profiles.AttackAnimation {
    return .{ .pose = if (sequence == 128) "shootc" else if (sequence == 129) "shootd" else "shootb", .rate = 20 };
}
pub fn fireSound(sequence: i32, _: u32) ?[:0]const u8 {
    return if (sequence >= 128) "e2/we_discambb.wav" else spec.audio.fire;
}
pub fn impact(context: @import("../../../mechanics/policy/weapons/impact.zig").Context) @import("../../../mechanics/policy/weapons/impact.zig").Cue {
    const flesh = context.kind == .flesh;
    return .{ .sound = if (flesh) "global/m_knifehitb.wav" else "e2/we_dischit1.wav", .particles = if (flesh) 4 else if (context.sequence >= 128) 10 else 1, .color = if (flesh) .{ 0.2, 0.4, 0.8 } else .{ 1, 1, 0.4 } };
}
pub fn predictionShot(controller: anytype) shot_rules.Shot {
    var result = shot_rules.standard(controller);
    // Close to something ahead, the disc is swung instead of thrown.
    const reach = meleeOrigin(controller.motion.position, controller.table.entries[id].muzzle, controller.player.ducked);
    if (controller.traceAhead(reach, 100)) {
        result.cost = 0;
        result.sequence = 128 + @mod(@divTrunc(controller.now(), 50), 2);
    }
    return result;
}

pub fn update(controller: anytype) void {
    controller.automatic(@This());
}

test "Discus steering clocks preserve return, drop and melee contracts" {
    const catalog = @import("../../../weapon_catalog.zig");
    const std = @import("std");
    var disc: BallisticState = .{};
    try std.testing.expect(!disc.tick(99, true));
    try std.testing.expect(disc.tick(100, true));
    try std.testing.expectEqual(@as(f32, 750), disc.speed);
    try std.testing.expect(!disc.tick(100, true));
    try std.testing.expect(disc.tick(200, false));
    try std.testing.expectEqual(@as(f32, 937.5), disc.speed);
    disc.home(.{ 0, 10, 0 }, true);
    try std.testing.expectEqual([3]f32{ 0, 1, 0 }, disc.forward);
    try std.testing.expect(disc.mustDrop(5000));
    disc.drop(7, 5000);
    try std.testing.expect(disc.pickup_only and disc.dropped and disc.target == 7);
    try std.testing.expectEqual(@as(i64, 10000), disc.drop_ms);
    try std.testing.expect(catalog.combatFor(9, 128) == .melee);
    try std.testing.expectEqualStrings("shootd", catalog.attackAnimation(9, 129, 0).pose);
    try std.testing.expectEqual(@as(u16, 250), (try catalog.meleePlan(9, 128, 0)).delays_ms[0]);
    try std.testing.expectEqual([3]f32{ 10, 30, 15 }, meleeOrigin(.{ 10, 20, 30 }, .{ 0, 10, 10 }, true));
}
