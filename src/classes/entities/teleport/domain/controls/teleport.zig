// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: teleport. A teleporter's named destination subject.
pub const controls = .{.{ .tag = "teleport", .State = State }};
pub const State = struct { named_subject: []const u8 = "" };
