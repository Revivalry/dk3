// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Actions tied to their owner's body follow a seamless ownership transfer and
//! end on disconnection. Free projectiles retain their own spatial owner.
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const Slots = @import("../../engine/slots.zig").Slots;
pub fn owner(world: *data.World, entity: ecs.Entity) ?u32 {
    inline for (.{ data.Melee, data.WeaponLaunch }) |T| if (world.get(entity, T) catch null) |action| return action.owner;
    return weapon_classes.actionOwner(world, entity) orelse @import("actor_attacks.zig").actionOwner(world, entity);
}
/// Chained lightning originates at each hop's actor, independently of the
/// player owning the chain. Carry only the hop actually attached to a mover.
pub fn attachment(world: *data.World, entity: ecs.Entity) ?u32 {
    return weapon_classes.actionSource(world, entity) orelse owner(world, entity);
}
pub fn cancel(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, player: ecs.Entity) !void {
    const identity = try world.persistentId(player);
    try cancelLocal(world, slots, projections, identity);
    // Personal graphs can have hops or a captured victim in another ready map.
    // Persistent ownership, not spatial proximity, decides disconnection cleanup.
    const access = @import("region_access.zig");
    const region = access.region orelse return;
    if (&region.initial.world.? != world) {
        const scope = try region.initial.select();
        defer scope.deinit();
        try cancelLocal(&region.initial.world.?, &region.initial.slots, &region.initial.projection, identity);
    }
    for (region.residents.entries) |maybe| if (maybe) |entry| if (entry.ready) if (entry.context) |context| {
        if (&context.world.? == world) continue;
        const scope = try context.select();
        defer scope.deinit();
        try cancelLocal(&context.world.?, &context.slots, &context.projection, identity);
    };
}
fn cancelLocal(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, identity: u32) !void {
    var pending: [ecs.max_entities]ecs.Entity = undefined;
    var count: usize = 0;
    {
        var query = world.queryAccess(0, 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities()) |entity| {
            if (owner(world, entity) == identity or weapon_classes.actionInvolves(world, entity, identity)) {
                pending[count] = entity;
                count += 1;
            }
        };
    }
    for (pending[0..count]) |entity| {
        if (try weapon_classes.removeAction(world, slots, projections, entity)) continue;
        if ((world.get(entity, data.Binding) catch null) != null) try @import("weapon_entities.zig").remove(world, slots, projections, entity) else try world.destroy(entity);
    }
}

test "a lightning hop follows its source while cancellation retains player ownership" {
    const t = @import("std").testing;
    var world = data.World.init(t.allocator, 2);
    defer world.deinit();
    const bolt = try world.create(null, .{data.ZeusBolt{ .owner = 12, .chain = 24, .source = 16777217, .target = 36, .born_ms = 0, .next_ms = 100 }});
    try t.expectEqual(@as(?u32, 12), owner(&world, bolt));
    try t.expectEqual(@as(?u32, 16777217), attachment(&world, bolt));
}
const weapon_classes = @import("weapon_classes/registry.zig");
