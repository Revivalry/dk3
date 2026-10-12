// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: light. Switchable lights and flames; flames burn what touches them.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .light;
pub fn owns(name: []const u8) bool {
    return @import("lights.zig").owns(name);
}
/// A plain light with no name and not starting off is never switched: it stays scenery.
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    const object = spawning.object;
    if (std.mem.eql(u8, object.classname, "light") and object.targetname.len == 0 and object.flags & 2 == 0) return .keep;
    return .{ .control = .{ .light = try @import("lights.zig").initialize(object, try spawning.world.persistentId(spawning.entity), spawning.now) } };
}
pub fn bind(publishing: *context.Publish) !void {
    try @import("lights.zig").bind(publishing.world, publishing.slots, publishing.projections, publishing.entity);
}
pub fn publish(publishing: *context.Publish) !void {
    try @import("lights.zig").publish(publishing.world, publishing.entity, publishing.projections);
}
pub fn use(control: *Control, _: u32) !void {
    try @import("lights.zig").use(control.world, control.entity, control.projections);
}
pub fn touches(contact: context.Contact) !bool {
    return contact.control.action.light.kind == .flame and (contact.world.get(contact.other, data.Health) catch null) != null;
}
pub fn touch(control: *Control, other: ecs.Entity) !void {
    _ = try @import("../../../../mechanics/server/damage.zig").apply(control.world, other, 2, control.now, .{ .source = try control.world.persistentId(control.entity) });
}
pub fn savedModel(action: context.Action) ?[]const u8 {
    return action.light.model;
}
/// Light styles advance once per step, after the controls.
pub fn finishStep(world: *data.World, now: i64) void {
    @import("lights.zig").styles(world, now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(saved: *const context.Saved, action: context.Action) !void {
    const state = action.light;
    if (state.model.len > 0) try saved.require(.{data.Binding});
    if (state.kind == .flame) try saved.require(.{data.Body});
    if (state.revision == 0 or state.revision > std.math.maxInt(u64) - 1000000 or state.pattern.len >= 1024 or (state.level != null and (state.level.? > 48 or state.pattern.len != 0)) or state.model.len >= 64) return error.InvalidSavedLight;
    for (state.scale) |value| if (!std.math.isFinite(value) or value <= 0 or value > 10000) return error.InvalidSavedLight;
}
/// Each light kind keeps its classname; flames are any of the episode flames.
pub fn savedAs(action: context.Action, classname: []const u8) bool {
    return switch (action.light.kind) {
        .light => std.mem.eql(u8, classname, "light"),
        .spot => std.mem.eql(u8, classname, "light_spot"),
        .strobe => std.mem.eql(u8, classname, "light_strobe"),
        .flare => std.mem.eql(u8, classname, "light_flare"),
        .flame => for ([_][]const u8{ "light_e1", "light_e2", "light_e3", "light_e4" }) |name| {
            if (std.mem.eql(u8, classname, name)) break true;
        } else false,
    };
}
