// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: light. Light ramps; multiplayer maps drop them.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .light_ramp;
pub const classnames = [_][]const u8{"target_lightramp"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    if (@import("../../../../mechanics/server/multiplayer.zig").enabled()) return .remove;
    return .{ .control = .{ .light_ramp = try @import("lights.zig").ramp(spawning.object) } };
}
pub fn use(control: *Control, _: u32) !void {
    try @import("lights.zig").rampUse(control.world, control.entity, control.now);
}
pub fn step(control: *Control) !void {
    try @import("lights.zig").rampStep(control.world, control.entity, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.light_ramp;
    if (state.from > 25 or state.to > 25 or state.from == state.to or state.duration_ms <= 0 or (state.next_ms != null and state.target == 0)) return error.InvalidSavedLightRamp;
    if (state.target != 0) {
        const target = saved.find(state.target) orelse return error.InvalidSavedLightRamp;
        const light = target.get(data.WorldControl) catch return error.InvalidSavedLightRamp;
        if (light.action != .light or light.action.light.kind != .light) return error.InvalidSavedLightRamp;
    }
}
