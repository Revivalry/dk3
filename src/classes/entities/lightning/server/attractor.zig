// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: lightning. Points lightning bolts are drawn to.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .attractor;
pub const classnames = [_][]const u8{"target_attractor"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .attractor = try @import("lightning.zig").attractor(spawning.object, spawning.now) } };
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(_: *const context.Saved, action: context.Action) !void {
    const state = action.attractor;
    if (state.linked and state.link_ms != null) return error.InvalidSavedAttractor;
}
