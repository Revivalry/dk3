// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: protopod. A pod notices its enemy, then hatches a slaughterskeet and becomes a
//! shell.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const rules = @import("../../../../mechanics/domain/actors.zig");
const v = @import("../../../../core/domain/vector.zig");
const abi = @import("../../../../engine/abi.zig");
const c = abi.c;
const engine = @import("../../../../engine/server.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const perceive = @import("../../../../mechanics/server/actor_perception.zig").perceive;
pub fn pod(actors: *@import("../../../../mechanics/server/actors.zig").Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, body: *data.Body, now: i64) !void {
    if (now < actor.think_ms) return;
    actor.think_ms = now + 100;
    const definition = actors.table.definitions[actor.definition];
    const enemy = try perceive(world, slots, entity, actor, pose, definition, now);
    const random = try world.get(entity, data.Random);
    const xy = if (enemy.enemy) |target| @import("../../../../core/domain/navigation.zig").horizontalDistance(pose.position, (try target.get(data.Transform)).position) else std.math.inf(f32);
    actor.pod.notice(now, enemy.visible, xy, random.next());
    const previous = actor.pod.phase;
    if (actor.pod.tick(now, definition.hatch.lastFrameMs())) {
        actor.changed_ms = now;
        body.mass = 0.5;
        const child = try actors.spawnDynamic(world, slots, projections, "monster_slaughterskeet", v.add(pose.position, .{ 0, 0, 10 }), pose.angles, now);
        const child_actor = try world.get(child, data.Actor);
        child_actor.threat = actor.threat;
        child_actor.threat_position = actor.threat_position;
        child_actor.skeeter.enter(.hatching, now, actors.table.definitions[child_actor.definition].hatch.lastFrameMs());
        try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, definition.hatch_sound, pose.position, (try world.get(entity, data.Binding)).slot, c.CHAN_AUTO, now);
        var buffer: [140]u8 = undefined;
        engine.print(try std.fmt.bufPrintZ(&buffer, "dk3 pod: id={d} hatched={d} enemy={d}\n", .{ try world.persistentId(entity), try world.persistentId(child), actor.threat }));
    }
    if (previous != .shell and actor.pod.phase == .shell) {
        body.mins = .{ -8, -8, -2 };
        body.maxs = .{ 8, 8, 2 };
        (try world.get(entity, data.Health)).current = 1;
    }
}
