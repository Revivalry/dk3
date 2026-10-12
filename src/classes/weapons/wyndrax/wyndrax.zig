// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: wyndrax. Weapon description: data, hooks and class rules for wyndrax.
const profiles = @import("../../../mechanics/policy/weapons/profiles.zig");
pub const id: u5 = 19;
pub const spec: profiles.Spec = .{
    .player_grip = .rifle,
    .combat = .flown,
    .projectile = .{ .action_delay_ms = 500, .mins = @splat(-16), .maxs = @splat(16) },
    .ammo_class = "ammo_wisp", // wyndrax
    .visual = .{ .projectile_model = "models/e3/we_wisp.dkm", .color = .{ 0.25, 0.45, 0.85 }, .glow = false },
    .world_model = "models/e3/a_wyndrx.dkm",
    .animation = .{
        .view_model = "models/e3/w_wisp.dkm",
        .ready = "ready",
        .away = "away",
        .fire = "shoot",
        .idle = .{ "amba", null, null },
        .raise_ms = 600,
        .drop_ms = 400,
    },
    .audio = .{
        .fire = "e3/we_wwispshoota.wav",
        .ready = "e3/we_wwispready.wav",
        .away = "e3/we_wwispaway.wav",
    },
};
pub const identity = .{ .classname = "weapon_wyndrax", .label = "Wyndrax's wisp", .episode = 3, .interval = 1400 };

const shot_rules = @import("../../../mechanics/policy/weapons/shot.zig");
pub fn predictionShot(controller: anytype) shot_rules.Shot {
    return shot_rules.standard(controller);
}

pub fn update(controller: anytype) void {
    controller.automatic(@This());
}

const std = @import("std");
const v = @import("../../../mechanics/policy/weapons/vector.zig");
pub const flight_tag = "wyndrax";
pub const sounds = [_][:0]const u8{ "e3/we_wwispcorditea.wav", "e3/we_wwispcorditeb.wav", "e3/we_wwispcorditec.wav" };
pub const flare = "models/global/e_flare4+o.sp2";
pub const BallisticState = struct {
    enemy: ?u32 = null,
    targets: [4]u32 = @splat(0),
    next_ms: i64 = 100,
    sound_ms: i64 = 100,
    sine_ms: i64 = 0,
    phase: enum { active, fading } = .active,
    sine: u8 = 0,
    personality: f32 = 0,
    alpha: f32 = 1,
    scale: v.Vec = @splat(2),

    pub fn include(self: *BallisticState, target: u32) bool {
        if (target == 0) return false;
        for (self.targets) |existing| if (existing == target) return false;
        for (&self.targets) |*empty| if (empty.* == 0) {
            empty.* = target;
            return true;
        };
        return false;
    }
    pub fn steer(self: *BallisticState, heading: v.Vec, distance: f32, random: anytype) v.Vec {
        var velocity = v.scale(v.normal(heading), 150);
        // Reference oscillator samples are rounded to three decimals, at 1 + 30*n degrees.
        const radians = (@as(f32, @floatFromInt(self.sine)) * 30 + 1) * (std.math.pi / 180.0);
        const wobble = 75 * self.personality;
        const axis: usize = if (@abs(@as(i32, @intFromFloat(velocity[0]))) > @abs(@as(i32, @intFromFloat(velocity[1])))) 1 else 0;
        velocity[axis] += @round(@cos(radians) * 1000) * 0.001 * wobble * (if (axis == 1) @as(f32, 1) else -1);
        velocity[2] += @round(@sin(radians) * 1000) * 0.001 * wobble;
        if (distance < 100) {
            const factor: f32 = if (distance < 64) -1 else 0;
            velocity[0] *= factor;
            velocity[1] *= factor;
        }
        self.sine = (self.sine + 1) % 12;
        if (self.sine == 0 and random.next() > 0.55) self.personality = random.next();
        return velocity;
    }
    pub fn fade(self: *BallisticState) bool {
        self.alpha -= 0.05;
        self.scale[0] -= 0.1;
        self.scale[1] -= 0.1;
        self.scale[2] += if (self.alpha < 0.5) @as(f32, -0.2) else 0.1;
        return self.alpha < 0.001 or self.scale[0] <= 0.1;
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *BallisticState, map: anytype) !void {
        try map.optional(&self.enemy);
        try map.many(&self.targets);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`); `owner` is its projectile's.
    pub fn validateSaved(self: *const BallisticState, check: anytype, owner: u32) !void {
        if (self.next_ms < 0 or self.sound_ms < 0 or self.sine_ms < 0 or self.sine >= 12 or self.personality < 0 or self.personality > 1 or self.alpha <= 0 or self.alpha > 1) return error.InvalidSavedProjectile;
        for (self.scale) |axis| if (axis <= 0 or axis > 4) return error.InvalidSavedProjectile;
        try check.require(.{"Random"});
        if (self.enemy) |entity_id| if (check.find(entity_id)) |target| try target.require(.{ "Health", "Body", "Binding" });
        for (self.targets, 0..) |entity_id, index| if (entity_id != 0) {
            if (entity_id == owner or @import("std").mem.indexOfScalar(u32, self.targets[0..index], entity_id) != null) return error.InvalidSavedProjectile;
            if (check.find(entity_id)) |target| try target.require(.{ "Health", "Binding" });
        };
    }
    /// Probe details for `dk3_runtime_weapons` (weapon_probe.zig).
    pub fn describe(self: *const BallisticState, buffer: []u8) ![]const u8 {
        return @import("std").fmt.bufPrint(buffer, "phase={s} enemy={d} targets={d},{d},{d},{d}", .{ @tagName(self.phase), self.enemy orelse 0, self.targets[0], self.targets[1], self.targets[2], self.targets[3] });
    }
    /// Its line for `dk3_runtime_projectiles`.
    pub fn probeLine(self: *const BallisticState, buffer: []u8, entity_id: u32, age_ms: i64, health: i32) ![:0]const u8 {
        _ = age_ms;
        _ = health;
        return @import("std").fmt.bufPrintZ(buffer, "dk3 zig wyndrax state: id={d} phase={s} enemy={d} targets={d},{d},{d},{d} alpha={d:.3}\n", .{ entity_id, @tagName(self.phase), self.enemy orelse 0, self.targets[0], self.targets[1], self.targets[2], self.targets[3], self.alpha });
    }
};
pub fn flightMotion(_: *BallisticState, frame: @import("../../../mechanics/policy/weapons/ballistics.zig").Frame) @import("../../../mechanics/policy/weapons/ballistics.zig").Motion {
    return .{ .velocity = frame.velocity };
}

test "Wisp retains four distinct targets, preserves the close orbit and ends its fade" {
    const Random = struct {
        pub fn next(_: *@This()) f32 {
            return 0.5;
        }
    };
    var random: Random = .{};
    var wisp: BallisticState = .{};
    for (1..5) |target| try std.testing.expect(wisp.include(@intCast(target)));
    wisp.targets[0] = 0;
    try std.testing.expect(!wisp.include(4)); // A hole must not duplicate a later target.
    try std.testing.expect(wisp.include(5));
    try std.testing.expect(!wisp.include(6));
    try std.testing.expectEqual(@as(f32, -150), wisp.steer(.{ 1, 0, 0 }, 63, &random)[0]);
    try std.testing.expectEqual(@as(f32, 0), wisp.steer(.{ 1, 0, 0 }, 64, &random)[0]);
    try std.testing.expectEqual(@as(f32, 150), wisp.steer(.{ 1, 0, 0 }, 100, &random)[0]);
    for (0..18) |_| try std.testing.expect(!wisp.fade());
    try std.testing.expect(wisp.fade());
}
