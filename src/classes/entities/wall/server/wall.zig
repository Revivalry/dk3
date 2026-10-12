// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: wall. Switchable walls; flag 64 shows them only in capture-the-flag.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"func_wall"};
pub const pass: context.Pass = .volumes;
pub fn prepare(preparing: *context.Prepare) !void {
    const object = preparing.object;
    const state: data.Wall = .{ .visible = (object.flags & 3 == 0 or object.flags & 4 != 0) and (object.flags & 64 == 0 or engine.integer("g_gametype") == c.GT_CTF), .toggleable = object.flags & 2 != 0, .nonsolid = object.flags & 32 != 0 };
    try preparing.world.put(preparing.entity, state);
    try @import("../../../../mechanics/server/world_actions.zig").publishVolume(preparing.world, preparing.entity, preparing.projections, state.visible, if (state.visible and !state.nonsolid) c.CONTENTS_SOLID else 0);
}
