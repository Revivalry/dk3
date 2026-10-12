// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: laser_beam. Authored laser beams.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .laser;
pub const classnames = [_][]const u8{"target_laser"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .laser = try @import("lasers.zig").initialize(spawning.object, (try spawning.world.get(spawning.entity, data.Transform)).*, spawning.now) } };
}
pub fn bind(publishing: *context.Publish) !void {
    try @import("../../../../mechanics/server/weapon_entities.zig").bind(publishing.world, publishing.slots, publishing.projections, publishing.entity, "");
    try publish(publishing);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("lasers.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
pub fn use(control: *Control, _: u32) !void {
    try @import("lasers.zig").use(control.world, control.slots, control.projections, control.entity, control.now);
}
pub fn step(control: *Control) !void {
    try @import("lasers.zig").step(control.world, control.slots, control.projections, control.entity, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const laser = action.laser;
    try saved.require(.{data.Binding});
    if (laser.damage < 1 or laser.damage > 1000000 or laser.sound > saved.sounds() or laser.spark_count > 8) return error.InvalidSavedLaser;
    for (laser.direction ++ laser.endpoint ++ laser.normal) |value| if (!std.math.isFinite(value)) return error.InvalidSavedLaser;
}
