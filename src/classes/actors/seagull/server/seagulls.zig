// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: seagull. Authored seagull paths keep their shallow steering and sampled vertical motion.
const data = @import("../../../../game/domain/components.zig");
const v = @import("../../../../core/domain/vector.zig");
const catalog = @import("actor_catalog");
const Actors = @import("../../../../mechanics/server/actors.zig").Actors;
pub fn move(actors: *Actors, world: *data.World, slots: *@import("../../../../engine/slots.zig").Slots, actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, slot: u16, elapsed: u32, now: i64, slow: f32, destination: ?v.Vec3) !void {
    const definition = actors.table.definitions[actor.definition];
    if (now >= (actor.seagull.motion_ms orelse now)) {
        actor.seagull.motion_ms = now + 100;
        if (destination == null) velocity.linear = @splat(0);
        if (destination) |goal| if (try actors.air_routes.next(pose.position, goal, body.*, slot)) |point| {
            @import("../../../../mechanics/server/actor_flight.zig").steer(pose, velocity, point, definition.walk_speed * 2 * slow, 0.01);
            try @import("../../../../mechanics/server/actor_flight.zig").avoid(world, slots, pose.*, body.*, velocity, slot, point, definition.walk_speed * 2 * slow);
            actor.seagull.bobbing = true;
        } else {
            velocity.linear = @splat(0);
        };
        if (actor.seagull.bobbing) {
            velocity.linear[2] += catalog.seagull.bob(actor.seagull.wave);
            actor.seagull.wave = if (actor.seagull.wave == 9) 0 else actor.seagull.wave + 1;
        }
    }
    try @import("../../../../mechanics/server/actor_flight.zig").move(pose, body.*, velocity, slot, elapsed);
    body.grounded = false;
    actor.ground_entity = @import("../../../../engine/abi.zig").c.ENTITYNUM_NONE;
}
