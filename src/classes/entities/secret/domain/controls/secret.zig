// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: secret. A secret area; it carries no state.
pub const controls = .{.{ .tag = "secret", .State = State }};
pub const State = void;
