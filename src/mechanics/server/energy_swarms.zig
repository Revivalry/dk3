// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: collecting a swarm's particles (actors/energy_swarm.zig). A consumer names
//! itself and the swarm sends it particles one by one; it takes the count delivered.
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
/// How many of the swarm's particles are out (not collected and waiting to respawn).
pub fn active(world: *data.World, swarm: data.WispSwarm) u4 {
    var result: u4 = 0;
    for (swarm.children[0..swarm.count]) |id| if (world.find(id)) |entity| {
        const fly = world.get(entity, data.Firefly) catch continue;
        if (fly.wisp != null and fly.wisp.?.mode != .dormant) result += 1;
    };
    return result;
}
pub fn collect(world: *data.World, source: ecs.Entity, consumer: ecs.Entity) !void {
    const swarm = try world.get(source, data.WispSwarm);
    swarm.consumer = try world.persistentId(consumer);
    swarm.goal = (try world.get(consumer, data.Transform)).position;
}
pub fn release(world: *data.World, source: ecs.Entity) !void {
    (try world.get(source, data.WispSwarm)).consumer = 0;
}
pub fn take(world: *data.World, source: ecs.Entity) !u16 {
    const swarm = try world.get(source, data.WispSwarm);
    const result = swarm.delivered;
    swarm.delivered = 0;
    return result;
}
