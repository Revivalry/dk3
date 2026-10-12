// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: boss wisps (homing, sine-weaving orbs that arc lightning at their target and
//! the scenery) and lightning discharges. The saved tags predate the mechanism: saves keep them.
/// The persistent attack payloads this mechanism launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{ .{ .tag = "npc_wisp", .Payload = Wisp }, .{ .tag = "wyndrax_zap", .Payload = Zap, .modelless = true }, .{ .tag = "wyndrax_bolt", .Payload = Bolt, .modelless = true } };
pub const render_tag = 10021;
pub const model = "models/e3/we_wisp.dkm";
const std = @import("std");
const saved = @import("saved_time.zig");
pub const Wisp = struct {
    target: u32,
    next_ms: i64,
    sine_ms: i64 = 0,
    phase: u4 = 0,
    personality: f32,
    forward: [3]f32,
    fading: bool = false,
    alpha: f32 = 1,
    scale: [3]f32 = @splat(2),
    sprite_scale: f32,
    /// Components the restored wisp entity carries besides the shared attack body.
    pub const saved_components = [_][]const u8{ "Random", "Health", "Hurt" };
    pub fn rebase(self: *Wisp, delta: i64) !void {
        try saved.shift(&self.next_ms, delta);
        try saved.active(&self.sine_ms, delta);
    }
    pub fn remapIds(self: *Wisp, map: anytype) !void {
        try map.one(&self.target);
    }
    pub fn validSaved(self: Wisp, _: i64, stepped_ms: i64) bool {
        if (self.target == 0 or self.phase >= 12 or !std.math.isFinite(self.personality) or @abs(self.personality) > 1 or !std.math.isFinite(self.alpha) or self.alpha <= 0 or self.alpha > 1 or !std.math.isFinite(self.sprite_scale) or self.sprite_scale < 1 or self.sprite_scale > 1.5 or self.next_ms <= stepped_ms or self.next_ms > stepped_ms + 100) return false;
        for (self.scale) |axis| if (!std.math.isFinite(axis) or axis <= 0 or axis > 4) return false;
        return saved.bounded(&self.forward, 1.01);
    }
};
pub const Zap = struct {
    target: u32,
    destination: [3]f32,
    emitted: u3 = 0,
    pub fn remapIds(self: *Zap, map: anytype) !void {
        try map.one(&self.target);
    }
    /// Two bolts per pair, at most two pairs, within 500 ms.
    pub fn validSaved(self: Zap, born_ms: i64, stepped_ms: i64) bool {
        return self.target != 0 and self.emitted <= 4 and self.emitted % 2 == 0 and stepped_ms <= born_ms + 500 and saved.bounded(&self.destination, std.math.floatMax(f32));
    }
};
pub const Bolt = struct {
    parent: u32,
    target: u32 = 0,
    destination: [3]f32,
    contact: [3]f32,
    next_ms: i64,
    until_ms: i64,
    kind: enum { wisp, scenery, zap, charge },
    color: [3]f32 = .{ 0.1, 0.2, 0.75 },
    flare: ?[3]f32 = null,
    flare_until_ms: i64 = 0,
    flare_scale: f32 = 2.15,
    pub fn rebase(self: *Bolt, delta: i64) !void {
        try saved.shift(&self.next_ms, delta);
        try saved.shift(&self.until_ms, delta);
        try saved.active(&self.flare_until_ms, delta);
    }
    pub fn remapIds(self: *Bolt, map: anytype) !void {
        try map.fields(self, .{ "parent", "target" });
    }
    /// The bolt's own bounds; its parent relation is checked by the class adapter.
    pub fn validSaved(self: Bolt, born_ms: i64, stepped_ms: i64) bool {
        if (self.parent == 0 or self.until_ms < born_ms or self.until_ms > born_ms + 750 or self.next_ms <= stepped_ms or self.flare_scale <= 0 or self.flare_scale > 5) return false;
        if (self.kind != .scenery and self.target == 0) return false;
        if (self.flare) |point| if (!saved.bounded(&point, std.math.floatMax(f32))) return false;
        return saved.bounded(&(self.destination ++ self.contact ++ self.color), std.math.floatMax(f32));
    }
};
