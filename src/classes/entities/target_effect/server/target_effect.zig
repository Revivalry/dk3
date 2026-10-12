// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: target_effect. Authored effect emitters; gore effects are removed when violence is off.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .target_effect;
pub const classnames = [_][]const u8{"target_effect"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    const state = try @import("target_effects.zig").initialize(spawning.world, spawning.entity, spawning.now);
    // Effects 3-7 are blood and gibs.
    if (engine.integer("sv_violence") != 0 and state.kind >= 3 and state.kind <= 7) return .remove;
    return .{ .control = .{ .target_effect = state } };
}
pub fn bind(publishing: *context.Publish) !void {
    try @import("../../../../mechanics/server/weapon_entities.zig").bind(publishing.world, publishing.slots, publishing.projections, publishing.entity, "");
    try publish(publishing);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("target_effects.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
pub fn use(control: *Control, _: u32) !void {
    try @import("target_effects.zig").use(control.world, control.slots, control.projections, control.entity, control.now);
}
pub fn step(control: *Control) !void {
    try @import("target_effects.zig").step(control.world, control.slots, control.projections, control.entity, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.target_effect;
    try saved.require(.{ data.Binding, data.Random });
    if (state.count < 1 or state.count > 64 or state.kind >= 33 or state.interval_ms <= 0 or state.duration_ms <= 0 or state.sound > saved.sounds() or (state.visible and (state.pulse_ms == null or state.serial == 0))) return error.InvalidSavedTargetEffect;
    if (state.gravity != -250 and state.gravity != 0 and state.gravity != 125) return error.InvalidSavedTargetEffect;
    for (state.direction ++ state.color) |value| if (!std.math.isFinite(value) or @abs(value) > 1000000) return error.InvalidSavedTargetEffect;
}
