// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: authored meteor staves bosses launch; the launching class tunes the launch and blast.
/// The persistent attack payloads this class launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{.{ .tag = "meteor", .Payload = State }};
pub const model = "models/e3/we_meteor.dkm";
pub const render_tag = 10022;
const saved = @import("saved_time.zig");
const std = @import("std");
pub const State = struct {
    phase: enum { stave, fragment, flare, impact } = .stave,
    next_ms: i64,
    scale: [3]f32 = @splat(0.2),
    spin: [3]f32,
    damage: f32,
    radius: f32,
    speed: f32,
    glow: f32 = 2.75,
    bounces: u8 = 0,
    bounce_max: f32 = 0,
    delta: f32 = 0.35,
    normal: [3]f32 = @splat(0),
    scorch: bool = false,
    /// Components the restored meteor entity carries besides the shared attack body.
    pub const saved_components = [_][]const u8{"Random"};
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.next_ms, delta);
    }
    /// Fragments do no damage; an impact lingers 500 ms, every other phase steps each 100 ms.
    pub fn validSaved(self: State, _: i64, stepped_ms: i64) bool {
        for ([_]f32{ self.damage, self.radius, self.speed, self.glow, self.bounce_max, self.delta }) |value| if (!std.math.isFinite(value)) return false;
        if (self.damage < 0 or self.damage > 1000000 or self.radius < 0 or self.radius > 1000000 or self.speed < 0 or self.speed > 65536 or self.next_ms <= stepped_ms or self.next_ms > stepped_ms + (if (self.phase == .impact) @as(i64, 500) else 100) or self.glow <= 0 or self.glow > 3 or self.bounces > 6 or self.bounce_max < 0 or self.bounce_max > 5) return false;
        for (self.scale) |axis| if (!std.math.isFinite(axis) or axis <= 0 or axis > 2) return false;
        return saved.bounded(&(self.spin ++ self.normal), 360) and !(self.phase == .fragment and self.damage != 0);
    }
};
