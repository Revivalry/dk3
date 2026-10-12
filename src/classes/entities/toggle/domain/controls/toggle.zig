// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: toggle. A toggle's activator and the sphere it affects.
pub const controls = .{.{ .tag = "toggle", .State = State }};
pub const State = struct {
    activator: u32 = 0,
    center: [3]f32,
    radius: f32,
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.activator);
    }
};
