// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Authored fixed/tracking lasers, separate from weapon and actor projectiles.
/// The world-control states this class owns, by saved tag (control_classes.zig).
pub const controls = .{.{ .tag = "laser", .State = State }};
pub const render_tag = 10032;
pub const State = struct {
    enabled: bool = false,
    initialized: bool = false,
    next_ms: i64 = 0,
    target: u32 = 0,
    direction: [3]f32 = .{ 1, 0, 0 },
    endpoint: [3]f32 = @splat(0),
    normal: [3]f32 = @splat(0),
    damage: i32 = 1,
    sound: u16 = 0,
    changed: bool = true,
    spark_ms: ?i64 = null,
    spark_count: u8 = 0,
    pub fn toggle(self: *State, now: i64) void {
        self.enabled = !self.enabled;
        if (self.enabled) self.changed = true;
        self.next_ms = now;
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.shift(&self.next_ms);
        try clock.deadline(&self.spark_ms);
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.target);
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
};
