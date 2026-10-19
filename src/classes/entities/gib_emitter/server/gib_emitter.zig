// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: gib_emitter. Authored gib fountains.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .gib_emitter;
pub const classnames = [_][]const u8{"func_gib"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .gib_emitter = try @import("gib_emitters.zig").initialize(spawning.world, spawning.entity, spawning.now) } };
}
pub fn use(control: *Control, _: u32) !void {
    control.control.action.gib_emitter.use(control.now);
}
pub fn step(control: *Control) !void {
    try @import("gib_emitters.zig").step(control.world, control.slots, control.projections, control.entity, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.gib_emitter;
    try saved.require(.{data.Random});
    if (!state.parameters.valid() or state.count < 1 or state.count > 10 or !std.math.isFinite(state.spread) or !std.math.isFinite(state.speed) or state.speed < 1 or state.speed > 600 or !std.math.isFinite(state.scale) or state.scale < 0.01 or state.scale > 200 or (state.on and !state.initialized)) return error.InvalidSavedGibEmitter;
    for (state.direction) |value| if (!std.math.isFinite(value)) return error.InvalidSavedGibEmitter;
}
