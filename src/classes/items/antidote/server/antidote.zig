// SPDX-License-Identifier: GPL-2.0-or-later
//! item-class: antidote. Damage admission consumes the saved protective charge.
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const Options = @import("../../../../mechanics/domain/damage.zig").Options;
pub fn absorb(world: *data.World, entity: ecs.Entity, amount: i32, now: i64, options: Options) !bool {
    const character = world.get(entity, data.Character) catch return false;
    if (character.invincible_until > now) return false;
    const context = @import("../../../../mechanics/server/region_access.zig").contextFor(world) orelse return false;
    if (!character.item_protection.antidote.absorb(amount, context.clients.episode, options.toxic)) return false;
    try @import("../../../../mechanics/server/events.zig").soundAt(world, &context.slots, &context.projection, entity, "artifacts/antidoteuse.wav", now);
    return true;
}
