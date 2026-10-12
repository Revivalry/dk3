// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: explosive. Explosive and breakable brushes.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{ "func_explosive", "func_breakable" };
pub const pass: context.Pass = .volumes;
pub fn prepare(preparing: *context.Prepare) !void {
    const object = preparing.object;
    const world = preparing.world;
    const health = try prop.number(object, "health", 100);
    const state: data.Destructible = .{ .hidden = object.flags & 1 != 0, .shootable = object.targetname.len == 0, .nonsolid = object.flags & 512 != 0, .damage = @max(0, try prop.number(object, "dmg", 0)), .radius = @max(1, try prop.number(object, "radius", 160)) };
    try world.put(preparing.entity, state);
    try world.put(preparing.entity, data.Health{ .current = @intFromFloat(@max(1, health)), .maximum = @intFromFloat(@max(1, health)) });
    try world.put(preparing.entity, data.Hurt{});
    try @import("../../../../mechanics/server/world_actions.zig").publishVolume(world, preparing.entity, preparing.projections, !state.hidden, if (state.hidden or state.nonsolid) 0 else c.CONTENTS_SOLID);
}
/// An explosive fires its targets as it breaks.
pub fn traits(classname: []const u8) context.Traits {
    return if (std.mem.eql(u8, classname, "func_explosive")) .{ .breakable = true, .relays = true } else .{};
}
