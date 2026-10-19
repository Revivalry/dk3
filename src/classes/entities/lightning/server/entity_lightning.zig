// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: lightning. Authored lightning emitters and the attractors they link to.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .lightning;
pub const classnames = [_][]const u8{"effect_lightning"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .lightning = try @import("lightning.zig").initialize(spawning.world, spawning.entity, spawning.now) } };
}
pub fn bind(publishing: *context.Publish) !void {
    try @import("../../../../mechanics/server/weapon_entities.zig").bind(publishing.world, publishing.slots, publishing.projections, publishing.entity, "");
    try publish(publishing);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("lightning.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
pub fn use(control: *Control, _: u32) !void {
    try @import("lightning.zig").use(control.world, control.slots, control.projections, control.router, control.entity, control.now);
}
pub fn step(control: *Control) !void {
    try @import("lightning.zig").step(control.world, control.slots, control.projections, control.router, control.entity, control.now);
}
/// Emitters find their attractors before stepping.
pub fn prepareStep(world: *data.World, now: i64) !void {
    try @import("lightning.zig").linkAttractors(world, now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.lightning;
    try saved.require(.{ data.Binding, data.Random });
    if (state.count > state.attractors.len or state.damage < 0 or state.damage > 1000000 or state.scale <= 0 or state.modulation < 0 or state.delay_ms <= 0 or state.duration_ms <= 0) return error.InvalidSavedLightning;
    for ([5]f32{ state.damage, state.scale, state.modulation, state.chance, state.ground_chance } ++ state.color) |value| if (!std.math.isFinite(value) or @abs(value) > 1000000) return error.InvalidSavedLightning;
    for (state.sounds ++ [1]u16{state.loop_sound}) |sound| if (sound > saved.sounds()) return error.InvalidSavedLightning;
    for (state.attractors[0..state.count], 0..) |id, index| {
        if (id == 0 or std.mem.indexOfScalar(u32, state.attractors[0..index], id) != null) return error.InvalidSavedLightning;
        if (saved.find(id)) |attractor| if ((try attractor.get(data.WorldControl)).action != .attractor) return error.InvalidSavedLightning;
    }
}
