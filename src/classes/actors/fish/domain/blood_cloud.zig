// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: fish. Pure rules of the dopefish's blood cloud.
/// The world-control states this class owns, by saved tag (control_classes.zig).
pub const controls = .{.{ .tag = "blood_cloud", .State = State }};
pub const render_tag = 10042;
pub const State = struct {
    next_ms: i64,
    until_ms: ?i64 = null,
    extent: [3]f32,
    mass: f32,
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.shift(&self.next_ms);
        try clock.deadline(&self.until_ms);
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
};
