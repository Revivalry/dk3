// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: light. Light kinds, styles and ramps.
//! Light classes' saved state and ramps; the lightstyle transport is lightstyle_table.zig.
/// The world-control states this class owns, by saved tag (control_classes.zig).
pub const controls = .{ .{ .tag = "light", .State = Light }, .{ .tag = "light_ramp", .State = Ramp } };
const std = @import("std");
pub const render_tag = 10036;
pub const Kind = enum { light, spot, strobe, flare, flame };
pub const Light = struct {
    kind: Kind,
    enabled: bool = true,
    switchable: bool = false,
    style: u8 = 0,
    pattern: []const u8 = "",
    level: ?u8 = null,
    revision: u64 = 0,
    phase_ms: i64 = 0,
    model: []const u8 = "",
    scale: [3]f32 = @splat(1),
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Light, clock: anytype) !void {
        try clock.shift(&self.phase_ms);
    }
    /// A light publishes its own projection, except a flame, which has a body.
    pub fn savedBodiless(self: Light) bool {
        return self.kind != .flame;
    }
};
pub const Ramp = struct {
    from: u8,
    to: u8,
    duration_ms: i64 = 1000,
    started_ms: i64 = 0,
    next_ms: ?i64 = null,
    target: u32 = 0,
    reverse: bool = false,
    pub fn sample(self: Ramp, now: i64) u8 {
        const fraction = @as(f32, @floatFromInt(now - self.started_ms)) / @as(f32, @floatFromInt(self.duration_ms));
        return @intFromFloat(std.math.clamp(@as(f32, @floatFromInt(self.from)) + fraction * (@as(f32, @floatFromInt(self.to)) - @as(f32, @floatFromInt(self.from))), 0, 48));
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Ramp, clock: anytype) !void {
        try clock.shift(&self.started_ms);
        try clock.deadline(&self.next_ms);
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Ramp, map: anytype) !void {
        try map.one(&self.target);
    }
};
/// Light patterns sample through the shared lightstyle table.
pub const sample = @import("../../../../mechanics/domain/lightstyle_table.zig").sample;
test "light ramps retain direction and do not force their endpoint early" {
    const t = std.testing;
    const ramp: Ramp = .{ .from = 0, .to = 25, .started_ms = 1000 };
    try t.expectEqual(@as(u8, 12), ramp.sample(1500));
    try t.expectEqual(@as(u8, 25), ramp.sample(2000));
    try t.expectEqual(@as(u8, 27), ramp.sample(2100));
}
