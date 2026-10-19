// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: wall_breakage. Exploding wall sections.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"func_wall_explode"};
pub const pass: context.Pass = .volumes;
pub fn prepare(preparing: *context.Prepare) !void {
    try @import("wall_breakage.zig").initialize(preparing.world, preparing.entity);
}
pub const traits: context.Traits = .{ .exploding_wall = true };
