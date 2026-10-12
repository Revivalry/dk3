// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: monitor. Security monitor views (monitors.zig).
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"func_monitor"};
pub const traits: context.Traits = .{ .monitor = true };
