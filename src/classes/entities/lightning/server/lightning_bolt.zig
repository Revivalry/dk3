// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: lightning. A bolt released by an emitter, stepped by the lightning system.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .lightning_bolt;
pub fn publish(publishing: *context.Publish) !void {
    try @import("lightning.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
pub fn step(control: *Control) !void {
    try @import("lightning.zig").step(control.world, control.slots, control.projections, control.router, control.entity, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.lightning_bolt;
    try saved.require(.{data.Binding});
    if (state.emitter == 0 or !std.math.isFinite(state.damage) or state.damage < 0 or state.damage > 1000000) return error.InvalidSavedLightningBolt;
    if (saved.find(state.emitter)) |emitter| if ((try emitter.get(data.WorldControl)).action != .lightning) return error.InvalidSavedLightningBolt;
    if (saved.find(state.target)) |target| try target.require(.{data.Transform});
    for (state.endpoint) |value| if (!std.math.isFinite(value)) return error.InvalidSavedLightningBolt;
}
/// Released by emitters, never authored.
pub const saved_classnames = [_][]const u8{"effect_lightning_bolt"};
