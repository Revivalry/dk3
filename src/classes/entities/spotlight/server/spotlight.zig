// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: spotlight. Spotlights and dynamic lights.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .spotlight;
pub const classnames = [_][]const u8{ "target_spotlight", "func_dynalight" };
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .spotlight = try @import("spotlights.zig").initialize(spawning.object, try spawning.world.get(spawning.entity, data.Transform), spawning.now) } };
}
pub fn bind(publishing: *context.Publish) !void {
    const state = (try publishing.world.get(publishing.entity, data.WorldControl)).action.spotlight;
    try @import("../../../../mechanics/server/weapon_entities.zig").bind(publishing.world, publishing.slots, publishing.projections, publishing.entity, state.model);
    try publish(publishing);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("spotlights.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
pub fn use(control: *Control, _: u32) !void {
    try @import("spotlights.zig").use(control.world, control.slots, control.projections, control.entity, control.now);
}
pub fn step(control: *Control) !void {
    try @import("spotlights.zig").step(control.world, control.slots, control.projections, control.entity, control.now);
}
pub fn savedModel(action: context.Action) ?[]const u8 {
    return if (action.spotlight.model.len > 0) action.spotlight.model else null;
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.spotlight;
    try saved.require(.{data.Binding});
    if (!std.math.isFinite(state.radius) or state.radius <= 0 or state.radius > 1000000 or !std.math.isFinite(state.length) or state.length < 0 or state.length > 1000000) return error.InvalidSavedSpotlight;
    if (!std.math.isFinite(state.brightness) or state.brightness < 0 or state.brightness > 1000000 or state.model.len >= 64 or (!state.dynamic and (!state.cone or state.flare))) return error.InvalidSavedSpotlight;
    for (state.direction ++ state.endpoint ++ state.spin) |value| if (!std.math.isFinite(value)) return error.InvalidSavedSpotlight;
    for (state.color) |value| if (!std.math.isFinite(value) or value < 0 or value > 1) return error.InvalidSavedSpotlight;
}
pub fn savedAs(action: context.Action, classname: []const u8) bool {
    return std.mem.eql(u8, classname, if (action.spotlight.dynamic) "func_dynalight" else "target_spotlight");
}
