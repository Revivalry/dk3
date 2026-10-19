// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: change_target. Retargets its targets to its `newtarget`.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"trigger_changetarget"};
pub fn useAuthored(using: *context.Use) !void {
    const next = prop.text(using.object, "newtarget") orelse return error.MissingNewTarget;
    const matches = try @import("../../../../mechanics/server/names.zig").named(using.world, using.object.target);
    for (matches.ids[0..matches.count]) |id| if (@import("../../../../mechanics/server/region_access.zig").find(using.world, id)) |target| {
        (try target.get(data.MapObject)).target = next;
    };
}
