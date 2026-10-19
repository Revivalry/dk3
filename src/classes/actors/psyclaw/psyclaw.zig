// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: psyclaw. Pure psyclaw class policy: state, tuning and decisions.
/// The persistent attack payloads this class launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{.{ .tag = "psyclaw_sphere", .Payload = Sphere }};
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .psyclaw, .traits = .{ .sidekicks = .refuse_melee, .attack = .ground } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "psyclaw";
/// Aidata: the psychic blast is weapon 2.
pub const ClassTuning = struct { blast: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const blast = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon2_");
    if (blast.speed <= 0) return error.InvalidPsyclawBlast;
    return .{ .blast = blast };
}
pub const attacks = [_][]const u8{ "ataka", "atakb" };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    protected_until_ms: i64 = 0,
    jump_started_ms: ?i64 = null,
    reduced: bool = false,
    horizontal: [2]f32 = @splat(0),
    emit_ms: i64 = 0,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.protected_until_ms, delta);
        try saved.active(&self.emit_ms, delta);
        try saved.deadline(&self.jump_started_ms, delta);
    }
};
pub const Sphere = struct {
    damage: f32,
    small: bool,
    scale: f32,
    multiplier: f32 = 1.45,
    color: i8 = 0,
    color_direction: i8 = 0,
    next_ms: i64,
    pub fn pulse(self: *Sphere) void {
        if (self.scale > (if (self.small) @as(f32, 2) else 3)) self.multiplier = 0.9 else if (self.scale < (if (self.small) @as(f32, 0.8) else 1.15)) self.multiplier = 1.1;
        self.scale *= self.multiplier;
        self.color += self.color_direction;
        if (self.color >= 25) self.color_direction = -8 else if (self.color <= 0) self.color_direction = 8;
    }
    pub fn tint(self: Sphere) [3]f32 {
        const blend = @as(f32, @floatFromInt(self.color)) * 0.04;
        return .{ 0.45 * (1 - blend), -0.15 + 1.15 * blend, 1 - blend };
    }
    pub fn rebase(self: *Sphere, delta: i64) !void {
        try saved.shift(&self.next_ms, delta);
    }
    /// A sphere pulses each 100 ms for at most 8 s.
    pub fn validSaved(self: Sphere, born_ms: i64, stepped_ms: i64) bool {
        return !(self.damage <= 0 or self.damage > 1000000 or self.scale < 0.5 or self.scale > 4.5 or self.multiplier < 0.9 or self.multiplier > 1.45 or self.color < -8 or self.color > 33 or self.color_direction < -8 or self.color_direction > 8 or self.next_ms <= stepped_ms or self.next_ms > stepped_ms + 100 or stepped_ms > born_ms + 8000);
    }
};
pub const model = "models/e1/me_psyclaw.dkm";
pub const render_tag = 10014;
test "psyclaw sphere pulse reverses at its own bounds" {
    const t = std.testing;
    var sphere: Sphere = .{ .damage = 10, .small = false, .scale = 3.1, .next_ms = 100 };
    sphere.pulse();
    try t.expect(sphere.scale < 3.1);
    try t.expectEqual(@as(f32, 0.9), sphere.multiplier);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_psyclaw", .kind = .psyclaw },
};
