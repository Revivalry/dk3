// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: remove_item. Volumes taking an inventory item from the player.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .remove_item;
pub const classnames = [_][]const u8{"trigger_remove_inventory_item"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    return .{ .control = .{ .remove_item = prop.text(spawning.object, "item") orelse return error.MissingRemovedItem } };
}
pub fn use(control: *Control, activator: u32) !void {
    const player = control.world.find(activator) orelse return;
    if ((control.world.get(player, data.Player) catch null) == null) return;
    try @import("../../../../mechanics/server/inventory_actions.zig").remove(control.world, player, control.control.action.remove_item);
}
pub fn touches(contact: context.Contact) !bool {
    return contact.player();
}
