// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: an entity is held when the entity owning its motion (a persistent actor attack
//! or a weapon entity) holds it frozen. Holders answer through their class hooks: attack handlers'
//! `holds` (actor_attacks.zig) and weapon adapters' `holds` (weapon_classes/registry.zig).
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const access = @import("region_access.zig");
pub fn held(world: *data.World, target: ecs.Entity) bool {
    if (@import("actor_attacks.zig").holds(world, target)) return true;
    const owner = (world.get(target, data.Body) catch return false).motion_owner orelse return false;
    const controller = access.find(world, owner) orelse return false;
    return @import("weapon_classes/registry.zig").holds(controller.world, controller.entity, world.persistentId(target) catch return false);
}
