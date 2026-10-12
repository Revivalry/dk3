// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: wisp. Authored wisp clusters are spawned by their own system, outside the actor
//! catalog (server/wisps.zig). Reference behaviour: wisp.cpp (docs/class-porting.md).
const data = @import("../../../../game/domain/components.zig");
const abi = @import("../../../../engine/abi.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
pub const classname = @import("actor_catalog").wisp.classname;
pub fn spawnForeign(_: *@import("../../../../mechanics/server/actor_classes/frame.zig").Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, now: i64) !void {
    try @import("wisps.zig").spawnOne(world, slots, projections, entity, now);
}
