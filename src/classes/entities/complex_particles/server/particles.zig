// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: complex_particles. Authored particle systems.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .particles;
pub const classnames = [_][]const u8{"sfx_complex_particle"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .particles = try @import("complex_particles.zig").initialize(spawning.world, spawning.entity, spawning.now) } };
}
pub fn bind(publishing: *context.Publish) !void {
    try @import("../../../../mechanics/server/weapon_entities.zig").bind(publishing.world, publishing.slots, publishing.projections, publishing.entity, "");
    try publish(publishing);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("complex_particles.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
pub fn use(control: *Control, _: u32) !void {
    try @import("complex_particles.zig").use(control.world, control.entity, control.projections, control.now);
}
pub fn step(control: *Control) !void {
    try @import("complex_particles.zig").step(control.world, control.slots, control.projections, control.entity, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.particles;
    try saved.require(.{ data.Binding, data.Random });
    if (state.count < 1 or state.count > 10 or state.velocity < 1 or state.velocity > 1000 or state.scale < 0.01 or state.scale > 200 or state.alpha < 0.01 or state.fade <= 0.01 or state.frequency < 0 or state.emission_time < 0.01 or (state.tracked and (!state.on or (state.phase != .check and state.phase != .spawn))) or (state.phase == .idle) != (state.next_ms == null)) return error.InvalidSavedParticles;
    for ([8]f32{ state.velocity, state.radius, state.scale, state.alpha, state.fade, state.frequency, state.emission_time, state.gravity } ++ state.color ++ state.direction ++ state.acceleration) |value| if (!std.math.isFinite(value) or @abs(value) > 1000000) return error.InvalidSavedParticles;
}
