// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: spotlight. Pure rules of the spotlight map entity class.
/// The world-control states this class owns, by saved tag (control_classes.zig).
pub const controls = .{.{ .tag = "spotlight", .State = State }};
pub const render_tag = 10035;
pub const State = struct {
    dynamic: bool = false,
    cone: bool = true,
    flare: bool = false,
    model: []const u8 = "",
    brightness: f32 = 200,
    spin: [3]f32 = @splat(0),
    stepped_ms: i64 = 0,
    enabled: bool = false,
    initialized: bool = false,
    next_ms: i64,
    target: u32 = 0,
    radius: f32 = 4,
    length: f32 = 2048,
    direction: [3]f32,
    endpoint: [3]f32,
    color: [3]f32 = @splat(1),
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.shift(&self.next_ms);
        try clock.shift(&self.stepped_ms);
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.target);
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
};
