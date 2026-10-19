// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: room. Sound-environment volumes: a player inside hears the room preset.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .room;
pub const classnames = [_][]const u8{"trigger_change_sfx"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    const object = spawning.object;
    var preset: i32 = 0;
    for (object.properties) |property| if (std.ascii.eqlIgnoreCase(property.key, "reverb") or std.ascii.eqlIgnoreCase(property.key, "fxstyle")) {
        preset = @intFromFloat(try prop.number(object, property.key, 0));
    };
    if (preset < 0 or preset > 25) return error.InvalidRoomPreset;
    return .{ .control = .{ .room = @intCast(preset) } };
}
pub fn touches(contact: context.Contact) !bool {
    return contact.player();
}
pub fn touch(control: *Control, other: ecs.Entity) !void {
    (try control.world.get(other, data.Character)).sound_environment = control.control.action.room + 1;
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(_: *const context.Saved, action: context.Action) !void {
    const preset = action.room;
    if (preset > 25) return error.InvalidSavedRoom;
}
