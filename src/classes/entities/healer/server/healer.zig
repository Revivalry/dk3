// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: healer. Health stations and fountains.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .healer;
/// A named station still serves the player who uses it.
pub const traits: context.Traits = .{ .player_usable = true, .station = true };
pub fn owns(name: []const u8) bool {
    return @import("healers.zig").owns(name);
}
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .healer = try @import("healers.zig").initialize(spawning.object) } };
}
pub fn bind(publishing: *context.Publish) !void {
    try @import("healers.zig").bind(publishing.world, publishing.slots, publishing.projections, publishing.entity);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("healers.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
pub fn use(control: *Control, activator: u32) !void {
    try @import("healers.zig").use(control.world, control.slots, control.projections, control.entity, activator, control.now);
}
pub fn step(control: *Control) !void {
    try @import("healers.zig").step(control.world, control.slots, control.projections, control.entity, control.now);
}
pub fn savedModel(action: context.Action) ?[]const u8 {
    return @import("item_catalog").hosportal.definition(action.healer.kind).model;
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const healer = action.healer;
    try saved.require(.{ data.Binding, data.Body, data.Health });
    if (healer.capacity > 1000000 or healer.charge > @max(100, healer.capacity) or (healer.phase == .giving and healer.recipient == 0) or (healer.phase != .giving and healer.recipient != 0) or (healer.phase == .ready) != (healer.next_ms == null)) return error.InvalidSavedHealer;
}
pub fn savedAs(action: context.Action, classname: []const u8) bool {
    return std.mem.eql(u8, classname, if (action.healer.kind == .fountain) "misc_fountain" else "misc_hosportal");
}
