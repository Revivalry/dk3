// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: push. A trigger_push field: its velocity, and whether it toggles or fires once.
pub const controls = .{.{ .tag = "push", .State = State }};
pub const State = struct { enabled: bool = true, velocity: [3]f32, toggleable: bool = false, once: bool = false };
