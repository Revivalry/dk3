// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: capture_zone. Team objective capture zones.
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"trigger_capture"};
pub const traits: context.Traits = .{ .capture_zone = true };
