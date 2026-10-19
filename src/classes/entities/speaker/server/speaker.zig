// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: speaker. Authored sound emitters.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .speaker;
pub fn owns(name: []const u8) bool {
    return @import("speakers.zig").owns(name);
}
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .speaker = try @import("speakers.zig").initialize(spawning.object, try spawning.world.persistentId(spawning.entity), spawning.now) } };
}
pub fn bind(publishing: *context.Publish) !void {
    try @import("../../../../mechanics/server/weapon_entities.zig").bind(publishing.world, publishing.slots, publishing.projections, publishing.entity, "");
    try publish(publishing);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("speakers.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
pub fn use(control: *Control, _: u32) !void {
    try @import("speakers.zig").use(control.world, control.slots, control.projections, control.entity, control.now);
}
pub fn step(control: *Control) !void {
    try @import("speakers.zig").step(control.world, control.slots, control.projections, control.entity, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const speaker = action.speaker;
    try saved.require(.{data.Binding});
    if (!speaker.parameters.valid() or speaker.count > speaker.sounds.len or speaker.delay_secs > 1000000 or speaker.minimum_secs > 1000000 or (speaker.active and !speaker.loopable) or (speaker.timed and speaker.delay_secs == 0) or (speaker.next_ms != null and !speaker.timed)) return error.InvalidSavedSpeaker;
    for (speaker.sounds[0..speaker.count]) |index| if (index > saved.sounds()) return error.InvalidSavedSound;
}
