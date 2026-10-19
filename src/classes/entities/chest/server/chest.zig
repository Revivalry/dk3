// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: chest. Authored chests: opening, rewards and their model.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .chest;
pub fn owns(name: []const u8) bool {
    return @import("item_catalog").chest.kind(name) != null;
}
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .chest = try @import("chests.zig").initialize(spawning.world, spawning.entity, spawning.now) } };
}
pub fn bind(publishing: *context.Publish) !void {
    try @import("chests.zig").bind(publishing.world, publishing.slots, publishing.projections, publishing.entity, publishing.now);
}
pub fn use(control: *Control, activator: u32) !void {
    try @import("chests.zig").use(control.world, control.slots, control.projections, control.entity, activator, control.now);
}
pub fn step(control: *Control) !void {
    try @import("chests.zig").step(control.world, control.slots, control.projections, control.entity, control.now);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("chests.zig").publish(publishing.world, publishing.entity, publishing.projections, publishing.now);
}
pub fn savedModel(action: context.Action) ?[]const u8 {
    return @import("item_catalog").chest.model(action.chest.kind);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.chest;
    try saved.require(.{ data.Binding, data.Body, data.Random, data.ItemMotion });
    if (state.reward >= (if (state.kind == .wood) @as(u8, 5) else 4) or (state.kind == .wood and (state.explosive or state.phase == .revealing or state.phase == .exploding)) or (state.phase == .closed) != (state.started_ms == null) or ((state.phase == .opening or state.phase == .revealing or state.phase == .exploding) != (state.next_ms != null))) return error.InvalidSavedChest;
    if (state.phase != .closed and state.opener == 0) return error.InvalidSavedChest;
    if (state.phase == .exploding and !state.explosive) return error.InvalidSavedChest;
    if (state.phase == .revealing and state.explosive) return error.InvalidSavedChest;
}
pub fn savedAs(action: context.Action, classname: []const u8) bool {
    return std.mem.eql(u8, classname, @import("item_catalog").chest.classname(action.chest.kind));
}
