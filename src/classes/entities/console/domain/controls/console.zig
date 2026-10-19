// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: console. What an authored console command does.
pub const controls = .{.{ .tag = "console", .State = State }};
pub const State = enum { disconnect, sword, first_weapon };
