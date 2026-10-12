// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: rockgat. Stationary popup gun. Defaults are class contracts, overridden by map epairs.
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .rockgat, .traits = .{ .remains = .{ .robotic = true, .no_blood = true, .always = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "rockgat";
/// The turret reads only its model from aidata: map keys own its tuning, and its hull, mass
/// and default health are class values.
pub const shared_tuning = false;
pub fn parseTuning(_: anytype, _: class_traits.Kind, definition: anytype) !void {
    definition.health = 500;
    definition.mass = 1;
    definition.mins = @splat(-16);
    definition.maxs = @splat(16);
}
pub const muzzle_model = "models/global/me_mflash.dkm";
pub const flash_tag: i32 = 0x52474154;
pub const frame_period_ms = 100;
pub const Phase = enum { disabled, passive, raising, scanning, lowering };
pub const Burst = struct { remaining: u3 = 5, next_ms: i64 };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: Phase = .passive,
    toggle: bool = false,
    on: bool = false,
    height: u16 = 10,
    raised: bool = false,
    pose_ms: i64 = 0,
    next_attack_ms: i64 = 0,
    next_sound_ms: i64 = 0,
    fire_ms: i64 = 130,
    range: f32 = 512,
    damage: f32 = 1,
    random_damage: f32 = 1,
    sound: []const u8 = "e1/e_rockgatshootmultia.wav",
    up_sound: []const u8 = "doors/e1/lift3start.wav",
    down_sound: []const u8 = "doors/e1/lift3stop.wav",
    hit_sound: []const u8 = "",
    bursts: [16]?Burst = @splat(null),
    shots: u32 = 0,
    pub fn use(self: *State) void {
        if (!self.toggle) return;
        self.on = !self.on;
        self.phase = if (self.on) if (self.height == 0) .scanning else .raising else if (self.height == 0) .disabled else .lowering;
    }
    pub fn frame(self: State, now: i64) u16 {
        if (self.height == 0) return 0;
        const elapsed: u64 = @intCast(@max(0, now - self.pose_ms));
        const progress: u16 = @intCast(@min(self.height, elapsed / frame_period_ms));
        return if (self.raised) progress else self.height - 1 - @min(self.height - 1, progress);
    }
    pub fn startBurst(self: *State, now: i64) !void {
        for (&self.bursts) |*burst| if (burst.* == null) {
            burst.* = .{ .next_ms = now + 10 };
            return;
        };
        return error.RockgatBurstCapacity;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.pose_ms, delta);
        try saved.shift(&self.next_attack_ms, delta);
        try saved.shift(&self.next_sound_ms, delta);
        for (&self.bursts) |*burst| if (burst.*) |*shot| {
            try saved.shift(&shot.next_ms, delta);
        };
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (self.height > 1024 or self.fire_ms < 10 or self.fire_ms > 3600000 or self.range <= 0 or self.range > 65536 or self.damage < 0 or self.damage > 1000000 or self.random_damage < 0 or self.random_damage > 1000000) return error.InvalidSavedRockgat;
        for (self.bursts) |burst| if (burst) |shot| {
            if (shot.remaining == 0 or shot.remaining > 5) return error.InvalidSavedRockgatBurst;
        };
    }
};
pub fn pitchAllowed(vertical_direction: f32) bool {
    return vertical_direction < 0.35;
}
pub fn painDamage(amount: i32) i32 {
    // Reference common damage subtracts first; Rockgat's pain callback subtracts
    // the incoming amount again. This rule must not affect other actors.
    return amount;
}
test "Rockgat toggle, popup timing and asymmetric vertical firing bound" {
    const t = std.testing;
    var gun: State = .{ .toggle = true, .phase = .disabled };
    gun.use();
    try t.expectEqual(Phase.raising, gun.phase);
    gun.raised = true;
    gun.pose_ms = 200;
    try t.expectEqual(@as(u16, 0), gun.frame(200));
    try t.expectEqual(@as(u16, 5), gun.frame(700));
    try t.expectEqual(@as(u16, 10), gun.frame(1200));
    gun.use();
    try t.expectEqual(Phase.lowering, gun.phase);
    gun.raised = false;
    try t.expectEqual(@as(u16, 9), gun.frame(200));
    try t.expectEqual(@as(u16, 0), gun.frame(1100));
    try t.expect(pitchAllowed(-0.9));
    try t.expect(!pitchAllowed(0.35));
    try gun.startBurst(2000);
    try t.expectEqual(@as(u3, 5), gun.bursts[0].?.remaining);
    try t.expectEqual(@as(i64, 2010), gun.bursts[0].?.next_ms);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_rockgat", .nitro_immune = true, .kind = .rockgat, .idle = "up", .run = "up", .death = "up" },
};
