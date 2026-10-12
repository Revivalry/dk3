// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: team_flag. Team flag objectives.
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{ "item_flag_team1", "item_flag_team2" };
pub fn traits(classname: []const u8) context.Traits {
    return .{ .team_flag = if (@import("std").mem.eql(u8, classname, "item_flag_team1")) 1 else 2 };
}
