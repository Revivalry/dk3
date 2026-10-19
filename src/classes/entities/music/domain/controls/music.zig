// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: music. The authored music track and when it last changed.
pub const controls = .{.{ .tag = "music", .State = State }};
pub const State = struct {
    path: []const u8,
    volume: f32 = 1,
    changed_ms: ?i64 = null,
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.deadline(&self.changed_ms);
    }
};
