// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: push. Push volumes throwing players along their direction.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .push;
pub const classnames = [_][]const u8{"trigger_push"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    const object = spawning.object;
    const angles = (try spawning.world.get(spawning.entity, data.Transform)).angles;
    const direction: v.Vec3 = if (angles[1] == -1) .{ 0, 0, 1 } else if (angles[1] == -2) .{ 0, 0, -1 } else v.basis(angles).forward;
    const supplied = try prop.number(object, "speed", 1000);
    return .{ .control = .{ .push = .{ .velocity = v.scale(direction, (if (supplied == 0) @as(f32, 1000) else supplied) * 10), .once = object.flags & 1 != 0, .toggleable = object.flags & 2 != 0, .enabled = object.flags & 4 == 0 } } };
}
/// A toggleable push switches on use.
pub fn use(control: *Control, _: u32) !void {
    const push = &control.control.action.push;
    if (push.toggleable) push.enabled = !push.enabled;
}
pub fn touches(contact: context.Contact) !bool {
    return contact.player();
}
pub fn touch(control: *Control, other: ecs.Entity) !void {
    const push = control.control.action.push;
    if (!push.enabled or (push.once and control.control.uses > 0)) return;
    const was = (try control.world.get(other, data.Velocity)).linear;
    (try control.world.get(other, data.Velocity)).linear = push.velocity;
    if (engine.integer("developer") >= 3) {
        var text: [256]u8 = undefined;
        const body = try control.world.get(other, data.Transform);
        const box = if (control.world.get(control.entity, data.Binding) catch null) |binding|
            if (binding.slot < control.projections.len) control.projections[binding.slot].shared else null
        else
            null;
        engine.print(std.fmt.bufPrintZ(&text, "dk3 push: id={d} box={d:.0},{d:.0},{d:.0}..{d:.0},{d:.0},{d:.0} body={d:.0},{d:.0},{d:.0} was={d:.0},{d:.0},{d:.0} set={d:.0},{d:.0},{d:.0}\n", .{
            control.world.persistentId(control.entity) catch 0,
            if (box) |b| b.absmin[0] else 0,
            if (box) |b| b.absmin[1] else 0,
            if (box) |b| b.absmin[2] else 0,
            if (box) |b| b.absmax[0] else 0,
            if (box) |b| b.absmax[1] else 0,
            if (box) |b| b.absmax[2] else 0,
            body.position[0],
            body.position[1],
            body.position[2],
            was[0],
            was[1],
            was[2],
            push.velocity[0],
            push.velocity[1],
            push.velocity[2],
        }) catch "");
    }
    if (push.velocity[2] > 0) {
        const player = try control.world.get(other, data.Player);
        player.ground_entity = c.ENTITYNUM_NONE;
        (try control.world.get(other, data.Body)).grounded = false;
    }
    control.control.uses += 1;
    // Authoring defines an optional push sound, not a forced wind sound.
    try @import("../../../../mechanics/server/events.zig").soundAt(control.world, control.slots, control.projections, other, prop.text(try control.object(), "sound") orelse "", control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(_: *const context.Saved, action: context.Action) !void {
    for (action.push.velocity) |value| {
        if (!std.math.isFinite(value) or @abs(value) > 100000) return error.InvalidSavedPush;
    }
}
/// The current this volume pushes with, for route planning around it.
pub fn current(action: context.Action) ?context.Current {
    return switch (action) {
        .push => |push| .{ .enabled = push.enabled, .velocity = push.velocity },
        else => null,
    };
}
