// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: debris. Authored brush fragments.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .debris;
/// An authored brush: its saved binding is checked with the other brushes.
pub const brush_model = true;
pub fn owns(name: []const u8) bool {
    return @import("debris.zig").owns(name);
}
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .debris = try @import("debris.zig").initialize(spawning.world, spawning.entity, spawning.projections, spawning.now) } };
}
pub fn bind(publishing: *context.Publish) !void {
    try publish(publishing);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("debris.zig").publish(publishing.world, publishing.entity, publishing.slots, publishing.projections);
}
pub fn use(control: *Control, activator: u32) !void {
    try @import("debris.zig").use(control.world, control.slots, control.projections, control.entity, activator, control.now);
}
/// Active fragments hit players, companions and actors.
pub fn touches(contact: context.Contact) !bool {
    return contact.control.action.debris.active and (contact.player() or contact.companion() or (contact.world.get(contact.other, data.Actor) catch null) != null);
}
pub fn touch(control: *Control, other: ecs.Entity) !void {
    try @import("debris.zig").contact(control.world, control.slots, control.projections, control.entity, other, control.now);
}
pub fn step(control: *Control) !void {
    try @import("debris.zig").step(control.world, control.slots, control.projections, control.entity, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.debris;
    try saved.require(.{ data.Binding, data.Body, data.Velocity, data.Random });
    if (!state.parameters.valid() or (state.active and (!state.visible or state.stopped)) or (state.stopped and !state.visible)) return error.InvalidSavedDebris;
    for (state.destination ++ state.spin) |value| if (!std.math.isFinite(value)) return error.InvalidSavedDebris;
}
/// Flying debris touches with its own body, not a trigger volume.
pub fn touchesWithBody(action: context.Action) bool {
    return switch (action) {
        .debris => |debris| debris.active,
        else => false,
    };
}
