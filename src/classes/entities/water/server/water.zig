// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: water. Liquid volumes, some of which drain away.
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"func_water"};
pub const traits: context.Traits = .{ .liquid = true };
