// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: console. Authored console commands: disconnect, or selecting the sword or the starting weapon.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .console;
pub const classnames = [_][]const u8{"trigger_console"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    const object = spawning.object;
    const command = prop.text(object, "message") orelse prop.text(object, "command") orelse return error.MissingAuthoredCommand;
    return .{ .control = .{ .console = if (std.mem.eql(u8, command, "disconnect")) .disconnect else if (std.mem.eql(u8, command, "s_daikatana")) .sword else if (std.mem.eql(u8, command, "weapon_select_1")) .first_weapon else return error.UnsupportedAuthoredCommand } };
}
pub fn use(control: *Control, activator: u32) !void {
    if ((try control.object()).flags & 1 != 0 and control.control.uses > 0) return;
    const player = control.world.find(activator) orelse return;
    const binding = control.world.get(player, data.Binding) catch return;
    if (binding.slot >= c.MAX_CLIENTS) return;
    control.control.uses += 1;
    control.control.ready_ms = control.now + 1000;
    const command = control.control.action.console;
    if (command == .disconnect) {
        engine.send(@intCast(binding.slot), "disconnect");
        return;
    }
    const id = if (command == .sword) @import("weapon_catalog").classes.daikatana.id else @import("weapon_catalog").starting((control.router.actors orelse return error.MissingActorDefinitions).episode);
    if ((try control.world.get(player, data.Weapons)).dk3Inventory & (@as(i32, 1) << id) == 0) return;
    var text: [32]u8 = undefined;
    engine.send(@intCast(binding.slot), try std.fmt.bufPrintZ(&text, "dk3_weapon {d}", .{id}));
}
pub fn touches(contact: context.Contact) !bool {
    return contact.player();
}
