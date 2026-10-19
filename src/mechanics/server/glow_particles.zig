// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: publication of glowing sprite particles (actors/glow_particle.zig).
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const c = abi.c;
pub fn publish(world: *data.World, entity: ecs.Entity, projections: []abi.EntityProjection) !void {
    const state = (try world.get(entity, data.Firefly)).*;
    const binding = (try world.get(entity, data.Binding)).*;
    const pose = (try world.get(entity, data.Transform)).*;
    const projection = &projections[binding.slot];
    projection.state.number = binding.slot;
    projection.state.eType = c.ET_GENERAL;
    projection.state.modelindex = binding.model;
    projection.state.generic1 = state.renderTag();
    projection.state.frame = state.shape;
    if (state.wisp) |wisp| {
        projection.state.time = @intCast(wisp.collected_ms);
        projection.state.angles = wisp.collected_at;
    }
    projection.state.time2 = @intFromFloat(std.math.clamp(state.alpha, 0, 1) * 255);
    projection.state.angles2 = .{ state.scale, 0, 0 };
    projection.state.origin2 = state.displayed_color;
    projection.state.pos = @import("../../engine/trajectory.zig").stationary(pose.position);
    projection.shared.currentOrigin = pose.position;
    projection.shared.mins = @splat(-1);
    projection.shared.maxs = @splat(1);
    projection.shared.contents = 0;
    projection.shared.ownerNum = c.ENTITYNUM_NONE;
    engine.link(projection);
}
/// Restored or transferred entities carrying these components are projected here (projection_classes.zig).
pub const projected = .{data.Firefly};
pub fn project(projecting: *const @import("system_context.zig").Project) !bool {
    try publish(projecting.world, projecting.entity, projecting.projections);
    return true;
}
