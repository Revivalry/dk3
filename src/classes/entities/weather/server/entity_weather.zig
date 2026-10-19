// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: weather. Rain and snow volumes.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .weather;
/// An authored brush: its saved binding is checked with the other brushes.
pub const brush_model = true;
pub const classnames = [_][]const u8{ "effect_rain", "effect_snow" };
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .weather = try @import("weather.zig").initialize(spawning.world, spawning.entity) } };
}
pub fn bind(publishing: *context.Publish) !void {
    try publish(publishing);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("weather.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.weather;
    try saved.require(.{ data.Binding, data.Body });
    if ((try saved.world.get(saved.entity, data.Body)).contents != 0) return error.InvalidSavedWeather;
    for (state.mins ++ state.maxs) |value| if (!std.math.isFinite(value) or @abs(value) > 1000000) return error.InvalidSavedWeather;
    for (state.mins, state.maxs) |lower, upper| if (lower > upper) return error.InvalidSavedWeather;
}
/// Rain and snow keep their classnames.
pub fn savedAs(action: context.Action, classname: []const u8) bool {
    return std.mem.eql(u8, classname, if (action.weather.kind == .rain) "effect_rain" else "effect_snow");
}
