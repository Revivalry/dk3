// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: summoning flares bosses launch, a rotating flare contract.
/// The persistent attack payloads this class launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{.{ .tag = "summon_effect", .Payload = State }};
pub const render_tag = 10028;
const saved = @import("saved_time.zig");
const std = @import("std");
pub const State = struct {
    kind: enum { red, blue, smoke } = .red,
    scale: [3]f32 = @splat(1),
    spin: [3]f32 = @splat(0),
    alpha: f32 = 0.75,
    alpha_multiplier: f32 = 0.95,
    oriented: bool = false,
    expires_ms: i64,
    next_ms: i64,
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.next_ms, delta);
        try saved.shift(&self.expires_ms, delta);
    }
    /// A flare lives at most 2 s and steps each 100 ms.
    pub fn validSaved(self: State, born_ms: i64, stepped_ms: i64) bool {
        if (!saved.bounded(&(self.scale ++ self.spin ++ [_]f32{ self.alpha, self.alpha_multiplier }), std.math.floatMax(f32))) return false;
        if (self.alpha < 0 or self.alpha > 1 or self.alpha_multiplier <= 0 or self.alpha_multiplier > 1 or self.expires_ms < born_ms or self.expires_ms > born_ms + 2000 or self.next_ms <= stepped_ms or self.next_ms > stepped_ms + 100) return false;
        for (self.scale) |axis| if (axis <= 0 or axis > 10) return false;
        return saved.bounded(&self.spin, 360);
    }
};
