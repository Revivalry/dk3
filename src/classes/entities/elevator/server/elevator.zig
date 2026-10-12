// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: elevator. Calls the train it targets.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"trigger_elevator"};
pub fn useAuthored(using: *context.Use) !void {
    const matches = try @import("../../../../mechanics/server/names.zig").named(using.world, using.object.target);
    if (matches.count == 0) return;
    const train = using.world.find(matches.ids[0]) orelse return;
    if ((using.world.get(train, data.Train) catch null) != null) try @import("../../train/server/trains.zig").use(using.world, using.projections, train, using.source, using.activator, using.now);
}
