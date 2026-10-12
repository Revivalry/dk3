// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: stavros. Weapon description: data, hooks and class rules for stavros.
const profiles = @import("../../../mechanics/policy/weapons/profiles.zig");
pub const id: u5 = 17;
pub const spec: profiles.Spec = .{
    .player_grip = .rifle,
    .combat = .owned,
    .ammo_class = "ammo_stavros", // stavros
    .projectile = .{ .mins = @splat(-12), .maxs = @splat(12), .direct_scale = 0, .splash_scale = 1, .lifetime_ms = 12000, .loop_sound = "global/e_torchd.wav" },
    .visual = .{ .projectile_model = "models/e3/we_meteor.dkm", .blast_sound = "global/e_explode1.wav", .color = .{ 0.85, 0.35, 0.15 }, .glow = false },
    .world_model = "models/e3/a_stav.dkm",
    .animation = .{
        .view_model = "models/e3/w_stavros.dkm",
        .ready = "ready",
        .away = "away",
        .fire = "shoot",
        .idle = .{ "amba", null, null },
        .raise_ms = 300,
        .drop_ms = 300,
    },
    .audio = .{
        .fire = "e3/we_stavefire.wav",
        .ready = "e3/we_staveready.wav",
        .away = "e3/we_staveaway.wav",
    },
    .projectile_muzzle = true,
};
pub const identity = .{ .classname = "weapon_stavros", .label = "Stavros staff", .episode = 3, .interval = 900 };

const shot_rules = @import("../../../mechanics/policy/weapons/shot.zig");
const v = @import("../../../mechanics/policy/weapons/vector.zig");
const ballistic = @import("../../../mechanics/policy/weapons/ballistics.zig");
pub const flight_tag = "stavros";
pub const visual = .{ .glow = "models/e3/we_fglow.sp2", .portal = "models/e3/we_blackhole.sp2" };
pub const BallisticState = struct {
    fragment: bool = false,
    next_ms: i64 = 100,
    radius: f32 = 200,
    scale: v.Vec = @splat(0.2),
    angular_delta: v.Vec = @splat(0),
    maximum_speed: f32 = 425,
    pub fn tick(self: *BallisticState, age: i64, velocity: v.Vec, angles: *v.Vec) v.Vec {
        if (age < self.next_ms) return velocity;
        self.next_ms = age + 100;
        angles.* = v.add(angles.*, self.angular_delta);
        var result = velocity;
        if (!self.fragment and self.scale[0] < 1) {
            self.scale = v.add(self.scale, @splat(0.1));
            if (self.angular_delta[2] > 5) self.angular_delta = v.sub(self.angular_delta, @splat(15));
            const speed = v.length(velocity);
            if (speed < self.maximum_speed) result = v.scale(velocity, if (speed < self.maximum_speed * 0.2) @as(f32, 1.75) else 2.5);
        }
        return result;
    }
    pub fn mins(self: BallisticState) v.Vec {
        return if (self.fragment) .{ -8, -8, -16 } else @splat(-12);
    }
    pub fn maxs(self: BallisticState) v.Vec {
        return if (self.fragment) .{ 8, 8, 0 } else @splat(12);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`); `owner` is its projectile's.
    pub fn validateSaved(self: *const BallisticState, check: anytype, owner: u32) !void {
        _ = owner;
        if (self.next_ms < 0 or self.radius <= 0 or self.radius > 8192 or self.maximum_speed <= 0 or self.maximum_speed > 100000) return error.InvalidSavedProjectile;
        for (self.scale) |axis| if (axis <= 0 or axis > 2) return error.InvalidSavedProjectile;
        if (!self.fragment) try check.require(.{"Random"});
    }
    /// Its line for `dk3_runtime_projectiles`.
    pub fn probeLine(self: *const BallisticState, buffer: []u8, entity_id: u32, age_ms: i64, health: i32) ![:0]const u8 {
        _ = age_ms;
        _ = health;
        return @import("std").fmt.bufPrintZ(buffer, "dk3 zig stavros state: id={d} fragment={d} scale={d:.3} next={d}\n", .{ entity_id, @intFromBool(self.fragment), self.scale[0], self.next_ms });
    }
};
pub fn flightMotion(_: *BallisticState, frame: ballistic.Frame) ballistic.Motion {
    return .{ .velocity = frame.velocity };
}
pub fn fragments(single_player: bool, random: f32) u8 {
    return if (single_player) 4 + @as(u8, @intFromFloat(random * 3)) else 0;
}
pub fn impact(context: @import("../../../mechanics/policy/weapons/impact.zig").Context) @import("../../../mechanics/policy/weapons/impact.zig").Cue {
    var cue = @import("../../../mechanics/policy/weapons/impact.zig").explosion(spec.visual, context);
    cue.sprite_scale = if (context.charged) 2 else 1;
    cue.light_radius = if (context.charged) 450 else 250;
    return cue;
}
pub fn predictionShot(controller: anytype) shot_rules.Shot {
    return shot_rules.standard(controller);
}

pub fn update(controller: anytype) void {
    controller.automatic(@This());
}

test "Stavros growth preserves staged acceleration and multiplayer fragment suppression" {
    const std = @import("std");
    var meteor: BallisticState = .{ .maximum_speed = 525, .angular_delta = .{ 10, 20, 30 } };
    var angles: [3]f32 = @splat(0);
    var velocity: [3]f32 = .{ 26.25, 0, 0 };
    try std.testing.expectEqual(velocity, meteor.tick(99, velocity, &angles));
    velocity = meteor.tick(100, velocity, &angles);
    try std.testing.expectApproxEqAbs(@as(f32, 45.9375), velocity[0], 0.0001);
    try std.testing.expectEqual([3]f32{ 10, 20, 30 }, angles);
    try std.testing.expectEqual([3]f32{ -5, 5, 15 }, meteor.angular_delta);
    try std.testing.expectEqual(velocity, meteor.tick(100, velocity, &angles));
    for (2..9) |tick| velocity = meteor.tick(@intCast(tick * 100), velocity, &angles);
    try std.testing.expectApproxEqAbs(@as(f32, 1), meteor.scale[0], 0.0001);
    try std.testing.expect(velocity[0] > meteor.maximum_speed); // Gold accelerates without clamping the last multiplication.
    try std.testing.expectEqual(@as(u8, 6), fragments(true, 0.99));
    try std.testing.expectEqual(@as(u8, 0), fragments(false, 0.99));
    meteor.fragment = true;
    const scale = meteor.scale;
    try std.testing.expectEqual(velocity, meteor.tick(1000, velocity, &angles));
    try std.testing.expectEqual(scale, meteor.scale);
}
