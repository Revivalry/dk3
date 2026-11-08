// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Party lane yielding and physical, unlocked door use, plus scripted motion.
//! The catch-up warp to the leader is companion_catchup.zig.
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const v = @import("../../../../core/domain/vector.zig");
const abi = @import("../../../../engine/abi.zig");
const engine = @import("../../../../engine/server.zig");
const c = abi.c;
const Slots = @import("../../../../engine/slots.zig").Slots;
const std = @import("std");
pub fn prepare(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, body: data.Body, now: i64) !void {
    const companion = try world.get(entity, data.Companion);
    if (!companion.enabled or companion.stopped or companion.authored != .none or companion.puzzle != null or body.motion_owner != null or actor.scripted_pose != null or actor.reaction != null) return;
    const slot = (try world.get(entity, data.Binding)).slot;
    if (now < companion.yielding_until_ms) {
        actor.mode = .chase;
        actor.threat_position = companion.yield_position;
        try yieldTo(world, entity, companion.yield_position, now);
        return;
    }
    var yielding_to: ?@import("../../../../mechanics/domain/world_references.zig").Ref = null;
    if (@import("../../../../mechanics/server/region_access.zig").find(world, companion.owner)) |owner| {
        const leader = (try owner.get(data.Transform)).*;
        const motion = (try owner.get(data.Velocity)).linear;
        const delta = v.subtract(pose.position, leader.position);
        // Yield only when occupying the leader's movement lane, even on Stay.
        const facing = v.basis(.{ 0, leader.angles[1], 0 }).forward;
        const close_ahead = @import("../../../../core/domain/navigation.zig").horizontalDistance(pose.position, leader.position) < 56 and v.dot(v.normalize(.{ delta[0], delta[1], 0 }), facing) > 0.5;
        var blocks_hull = false;
        if (owner.world == world and v.length(delta) < 96) {
            const leader_body = (try owner.get(data.Body)).*;
            const leader_slot = (try owner.get(data.Binding)).slot;
            const contact = try @import("../../../../mechanics/server/actor_collision.zig").service().trace(.{ .start = leader.position, .end = v.add(leader.position, v.scale(facing, 56)), .mins = leader_body.mins, .maxs = leader_body.maxs, .slot = leader_slot, .mask = leader_body.collision_mask });
            // A peripheral corner of the hull can block motion even when
            // the companion's centre is outside the view-direction cone.
            blocks_hull = contact.entity == slot and contact.fraction < 1;
        }
        if (v.length(delta) < 96 and (blocks_hull or close_ahead or (v.length(motion) > 20 and v.dot(v.normalize(motion), v.normalize(delta)) > 0.5))) yielding_to = owner;
    }
    if (actor.mode == .chase) {
        const toward = if (actor.route.waypoint) |point| point.point else actor.threat_position;
        // Climbing straight up (a ladder under a hatch): the door is overhead.
        const flat: v.Vec3 = .{ toward[0] - pose.position[0], toward[1] - pose.position[1], 0 };
        const direction = if (toward[2] - pose.position[2] > 18 and v.length(flat) < 24) v.Vec3{ 0, 0, 1 } else v.normalize(flat);
        const hit = try @import("../../../../mechanics/server/actor_collision.zig").service().trace(.{ .start = pose.position, .end = v.add(pose.position, v.scale(direction, 64)), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask });
        if (hit.fraction < 1) if (@import("../../../../mechanics/server/region_access.zig").victim(world, slots, hit)) |obstacle| {
            const doors = @import("../../../../mechanics/server/entity_classes/registry.zig");
            // An authored obstacle may be a door the party opens on its class's terms.
            if ((obstacle.get(data.MapObject) catch null) != null) {
                if (obstacle.world == world) {
                    // Opening may relocate ECS component columns.
                    if (try doors.openForParty(world, slots, projections, obstacle.entity, try world.persistentId(entity), now)) return;
                } else {
                    const context = @import("../../../../mechanics/server/region_access.zig").contextFor(obstacle.world) orelse return error.PartyWorldUnavailable;
                    const scope = try context.select();
                    defer scope.deinit();
                    if (try doors.openForParty(obstacle.world, &context.slots, &context.projection, obstacle.entity, try world.persistentId(entity), now)) return;
                }
            }
            if ((obstacle.get(data.Player) catch null) != null or ((obstacle.get(data.Companion) catch null) != null and (if (obstacle.world == world) hit.entity < slot else try obstacle.id() < try world.persistentId(entity)))) {
                yielding_to = obstacle;
            }
        };
    }
    if (yielding_to) |other| {
        const other_pose = (try other.get(data.Transform)).*;
        const roll: f32 = if (companion.identity == .mikiko) 0 else 1;
        if (try passingSpot(@import("../../../../mechanics/server/actor_collision.zig").service(), pose.position, body, slot, other_pose, (try other.get(data.Body)).*, roll)) |point| {
            companion.yield_position = point;
            companion.yielding_until_ms = now + 1000;
            actor.route = .{};
            actor.mode = .chase;
            actor.threat_position = point;
            try yieldTo(world, entity, point, now);
        }
    }
}
/// Reserve actual passing room, rather than a combat sidestep's reduced
/// distance. If the passage is too narrow for that, back away along it.
fn passingSpot(collision: @import("../../../../core/domain/collision.zig").Collision, position: v.Vec3, body: data.Body, slot: u16, other: data.Transform, other_body: data.Body, roll: f32) !?v.Vec3 {
    const side = v.basis(.{ 0, other.angles[1], 0 }).right;
    const sign: f32 = if (roll < 0.5) -1 else 1;
    const away = v.normalize(.{ position[0] - other.position[0], position[1] - other.position[1], 0 });
    const forward = v.basis(.{ 0, other.angles[1], 0 }).forward;
    const along = v.scale(forward, if (v.dot(away, forward) >= 0) @as(f32, 1) else -1);
    const clearance = @max(@abs(body.mins[0]), body.maxs[0]) + @max(@abs(other_body.mins[0]), other_body.maxs[0]) + 4;
    const candidates = [_]v.Vec3{ v.scale(side, sign * 64), v.scale(side, -sign * 64), v.scale(away, 64), v.scale(along, 64), v.scale(away, 96), v.scale(along, 96) };
    const wet = try collision.contents(v.add(position, .{ 0, 0, body.mins[2] + 1 }), slot) & c.CONTENTS_WATER != 0;
    const forbidden: u32 = @as(u32, c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO) | (if (wet) 0 else @as(u32, c.CONTENTS_WATER));
    for (candidates, 0..) |offset, index| {
        if (v.length(offset) < 1) continue;
        const candidate = v.add(position, offset);
        if (index < 2 and @abs(v.dot(v.subtract(candidate, other.position), side)) < clearance) continue;
        // The supported rollout already checks every swept hull and stair.
        // A level sweep here would reject a legal retreat up a single tread,
        // leaving both bodies locked face to face in a narrow passage.
        const supported = try @import("../../../../core/domain/navigation_input.zig").walkPathSupported(collision, .{ .start = position, .end = candidate, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask }, forbidden, &.{}, 22, body.collision_mask & ~@as(u32, c.CONTENTS_BODY)) orelse continue;
        return supported;
    }
    return null;
}
test "a follower backs out of a narrow lane and rejects an unsupported retreat" {
    const col = @import("../../../../core/domain/collision.zig");
    const Fixture = struct {
        gap: bool = false,
        step: bool = false,
        fn trace(raw: *anyopaque, request: col.Request) !col.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (request.end[0] + request.maxs[0] > 20 or request.end[0] + request.mins[0] < -20)
                return .{ .fraction = 0, .end = request.start, .normal = .{ -1, 0, 0 } };
            if (self.step and request.end[1] > request.start[1] and request.end[1] >= 40 and request.start[2] < 40)
                return .{ .fraction = 0.5, .end = request.start, .normal = .{ 0, -1, 0 } };
            if (request.end[2] < request.start[2] and !(self.gap and request.start[1] > 40)) {
                const height = -request.mins[2] + (if (self.step and request.start[1] >= 40) @as(f32, 16) else 0);
                if (request.start[2] >= height and request.end[2] <= height) {
                    const fraction = (request.start[2] - height) / (request.start[2] - request.end[2]);
                    return .{ .fraction = fraction, .end = .{ request.end[0], request.end[1], height }, .normal = .{ 0, 0, 1 } };
                }
            }
            return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var fixture: Fixture = .{};
    const collision: col.Collision = .{ .context = &fixture, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents };
    const body: data.Body = .{ .mins = .{ -12, -12, -24 }, .maxs = .{ 12, 12, 30 }, .collision_mask = c.MASK_PLAYERSOLID };
    const leader: data.Transform = .{ .position = .{ 0, 0, 24 }, .angles = .{ 0, 90, 0 } };
    const other: data.Body = .{ .mins = .{ -15, -15, -24 }, .maxs = .{ 15, 15, 32 } };
    const chosen = (try passingSpot(collision, .{ 0, 27, 24 }, body, 1, leader, other, 0)).?;
    try std.testing.expect(chosen[1] >= 91 and @abs(chosen[0]) < 1);
    const off_center = (try passingSpot(collision, .{ -6, 27, 24 }, body, 1, leader, other, 0)).?;
    try std.testing.expect(off_center[1] >= 91 and @abs(off_center[0] + 6) < 1);
    fixture.step = true;
    const upstairs = (try passingSpot(collision, .{ 0, 27, 24 }, body, 1, leader, other, 0)).?;
    try std.testing.expect(upstairs[1] >= 91 and upstairs[2] == 40);
    fixture.gap = true;
    try std.testing.expectEqual(null, try passingSpot(collision, .{ 0, 27, 24 }, body, 1, leader, other, 0));
}
/// Step aside along a straight, braked line; fighting goes on meanwhile.
fn yieldTo(world: *data.World, entity: ecs.Entity, point: v.Vec3, now: i64) !void {
    const companion = try world.get(entity, data.Companion);
    const flown = @import("companion_pilot.zig").entry(world, try world.persistentId(entity), @intFromEnum(companion.identity), now);
    flown.intent.destination = point;
    flown.intent.direct = true;
    flown.intent.brake = true;
    flown.intent.close_in = false;
    flown.intent.leash = null;
}

/// Scripted motion (an authored performance walking the companion): reuse
/// native collision/step/swim/ladder physics with supplied class hull and
/// speed. Routing only submits commands; it never installs a waypoint position.
/// Ordinary party movement is flown by the shared pilot (companion_pilot).
pub fn move(world: *data.World, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, service: @import("../../../../core/domain/navigation.zig").Service, definition: @import("../../../../mechanics/domain/actors.zig").Definition, speed: f32, threat: v.Vec3, slot: u16, now: i64, elapsed: u32) !void {
    const nav = @import("../../../../core/domain/navigation.zig");
    const movement = @import("../../../../mechanics/domain/player_move.zig");
    const ground = @import("../../../../mechanics/server/actor_motion.zig");
    const companion = try world.get(entity, data.Companion);
    const moving = body.motion_owner == null and (actor.mode == .chase or actor.mode == .flee);
    if (moving and actor.mode == .flee) {
        if (!actor.route.fleeing or now >= actor.escape_until or actor.route.blocked or nav.horizontalDistance(pose.position, actor.route.destination) < 24) {
            actor.route = .{ .destination = (try ground.escape(service, pose.position, threat, body.*, slot)) orelse pose.position, .fleeing = true, .progress_ms = now, .progress_position = pose.position };
            actor.escape_until = now + 800;
        }
    } else if (actor.route.fleeing) actor.route = .{};
    var command: movement.Command = .{ .time_ms = now, .angles = .{ 0, pose.angles[1], 0 } };
    var goal: ?nav.Waypoint = null;
    if (moving) {
        const destination = if (actor.mode == .flee) actor.route.destination else actor.threat_position;
        goal = try actor.route.update(service, .{ .position = pose.position, .destination = destination, .slot = slot, .player = true }, now);
        if (try ground.direct(pose.position, destination, body.*, slot)) goal = .{ .point = destination };
        // A visible submerged destination has no ground-floor requirement.
        if (companion.motor.water_level > 1 and try @import("../../../../mechanics/server/actor_collision.zig").service().contents(destination, slot) & c.MASK_WATER != 0) {
            const clear = try @import("../../../../mechanics/server/actor_collision.zig").service().trace(.{ .start = pose.position, .end = destination, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask });
            if (!clear.start_solid and clear.fraction == 1) goal = .{ .point = destination };
        }
    }
    var desired_speed = speed;
    if (goal) |point| {
        const delta = v.subtract(point.point, pose.position);
        const distance = nav.horizontalDistance(point.point, pose.position);
        if (distance > 0.1) {
            pose.angles[1] = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
            command.angles[1] = pose.angles[1];
            command.forward = 127;
            // Arrive without running past a short scripted destination.
            desired_speed = @min(speed, distance * 1000 / @as(f32, @floatFromInt(@max(elapsed, 1))));
        }
        if (companion.motor.water_level > 1) {
            if (distance > 0.1) {
                command.angles[0] = -std.math.atan2(delta[2], distance) * 180 / std.math.pi;
                desired_speed = @min(speed, v.length(delta) * 1000 / @as(f32, @floatFromInt(@max(elapsed, 1))));
            } else if (@abs(delta[2]) > 4) command.up = if (delta[2] > 0) 127 else -127;
        } else if (point.ladder and @abs(delta[2]) > 4) {
            command.up = if (delta[2] > 0) 127 else -127;
        } else if (point.crouch or try @import("../../../../core/domain/navigation_input.zig").crouch(@import("../../../../mechanics/server/actor_collision.zig").service(), pose.position, point.point, definition.mins, definition.maxs, slot, body.collision_mask)) {
            command.up = -127;
        } else if (point.jump and body.grounded and now >= actor.jump_ready_ms and !companion.motor.jump_held) {
            command.up = 127;
            actor.jump_ready_ms = now + 700;
        }
    }
    // Cinematic pauses and explicit motion owners must not accumulate commands.
    companion.motor.command_ms = @max(companion.motor.command_ms, now - elapsed);
    companion.motor.mode = if (body.motion_owner != null) .frozen else .normal;
    var motion: @import("../../../../core/domain/slide.zig").State = .{ .position = pose.position, .velocity = velocity.linear };
    const result = try movement.run(&companion.motor, &motion, command, .{ .speed = desired_speed, .jump_speed = definition.upward_speed, .slot = slot, .mask = body.collision_mask, .water_mask = c.MASK_WATER, .solid_mask = c.CONTENTS_SOLID, .currents = @import("../../../../mechanics/player_state.zig").currents, .mins = definition.mins, .maxs = definition.maxs, .snap_velocity = false }, @import("../../../../mechanics/server/actor_collision.zig").service());
    for (result.events[0..result.event_count]) |event| switch (event) {
        .jump => companion.jump_started_ms = now,
        else => {},
    };
    body.mins = result.mins;
    body.maxs = result.maxs;
    actor.ground_entity = companion.motor.ground_entity;
    body.grounded = actor.ground_entity != c.ENTITYNUM_NONE;
    pose.position = motion.position;
    velocity.linear = motion.velocity;
}
