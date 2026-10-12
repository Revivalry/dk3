// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: rotating_door. Rotating doors; movers.zig swings them.
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"func_door_rotate"};
pub const traits: context.Traits = .{ .door = .rotating };
/// A party member pushing into it opens it on the mover's terms.
pub const openForParty = @import("../../mover/server/movers.zig").openForParty;
