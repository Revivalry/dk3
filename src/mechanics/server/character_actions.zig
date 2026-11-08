// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Attribute accents are emitted on actual movement/fire events.
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const rules = @import("weapon_catalog").character;
pub fn sound(world: *data.World, slots: *@import("../../engine/slots.zig").Slots, projections: []abi.EntityProjection, entity: ecs.Entity, action: rules.Action, now: i64) !void {
    const character = (world.get(entity, data.Character) catch return).*;
    const level = character.attribute(if (action == .jump) .acro else .power, now);
    const sample = rules.actionSound(action, level) orelse return;
    const point = (try world.get(entity, data.Transform)).position;
    const slot = (try world.get(entity, data.Binding)).slot;
    // A separate accent channel retains the weapon's own firing sound.
    try @import("events.zig").configuredSound(world, slots, projections, sample.path, point, slot, abi.c.CHAN_ITEM, now, .{ .volume = sample.volume });
}
