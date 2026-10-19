// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: fish. The blood cloud map entity the dopefish's bite leaves.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .blood_cloud;
pub fn publish(publishing: *context.Publish) !void {
    try @import("blood_clouds.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
pub fn step(control: *Control) !void {
    try @import("blood_clouds.zig").step(control.world, control.slots, control.projections, control.entity, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.blood_cloud;
    for (state.extent) |axis| if (!std.math.isFinite(axis) or @abs(axis) > 1048576) return error.InvalidSavedBloodCloud;
    if (state.mass <= 0 or state.mass > 100000 or !std.math.isFinite(state.mass)) return error.InvalidSavedBloodCloud;
    if (state.until_ms) |until| if (until - state.next_ms != 500) return error.InvalidSavedBloodCloud;
    try saved.require(.{ data.Random, data.Binding });
}
/// Spawned by the Dopefish bite, never authored.
pub const saved_classnames = [_][]const u8{"effect_blood_cloud"};
