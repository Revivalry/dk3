// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: teleporter. Teleport volumes and scripted teleports of named subjects.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .teleport;
pub const classnames = [_][]const u8{"trigger_teleport"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .teleport = .{ .named_subject = prop.text(spawning.object, "teleport") orelse "" } } };
}
/// Touching the volume sends an actor to its destination.
pub fn passage(world: *data.World, entity: ecs.Entity) !?data.Transform {
    return try @import("teleports.zig").destination(world, entity);
}
/// Used, it moves its named subject (the player, or every actor of that name).
pub fn use(control: *Control, _: u32) !void {
    const subject = control.control.action.teleport.named_subject;
    if (subject.len == 0) return;
    const teleports = @import("teleports.zig");
    if (std.mem.eql(u8, subject, "player")) {
        if (control.slots.occupants[0]) |player| try teleports.move(control.world, control.slots, control.projections, control.router, control.entity, player, true, control.now);
        return;
    }
    const found = try @import("../../../../mechanics/server/names.zig").named(control.world, subject);
    for (found.ids[0..found.count]) |id| if (control.world.find(id)) |actor| try teleports.move(control.world, control.slots, control.projections, control.router, control.entity, actor, true, control.now);
}
/// An unnamed volume with no subject takes players, and companions unless flagged.
pub fn touches(contact: context.Contact) !bool {
    return contact.control.action.teleport.named_subject.len == 0 and contact.object.targetname.len == 0 and (contact.player() or (contact.companion() and contact.object.flags & 1 == 0));
}
pub fn touch(control: *Control, other: ecs.Entity) !void {
    try @import("teleports.zig").move(control.world, control.slots, control.projections, control.router, control.entity, other, false, control.now);
}
