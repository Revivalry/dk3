// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: monster_spawn. Spawns its authored monster when used.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"target_monster_spawn"};
pub fn useAuthored(using: *context.Use) !void {
    try @import("../../../../mechanics/server/actor_spawns.zig").use(using.router.actors orelse return error.MissingActorDefinitions, using.world, using.slots, using.projections, using.entity, using.source, using.now);
}
