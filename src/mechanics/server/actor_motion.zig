// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Ground locomotion shared by actor policies. Pathfinding never changes position directly.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const nav = @import("../../core/domain/navigation.zig");
const engine = @import("../../engine/server.zig");
const c = @import("../../engine/abi.zig").c;
const v = @import("../../core/domain/vector.zig");
const slide = @import("../../core/domain/slide.zig");
const Collision = @import("../../core/domain/collision.zig").Collision;

/// Support and line-of-travel probes test world geometry only: a body in the way (the enemy being
/// chased, above all) is the slide's to stop, not a missing floor or a blocked line.
fn worldMask(body: data.Body) u32 {
    return body.collision_mask & ~@as(u32, c.CONTENTS_BODY);
}
fn floorWith(collision: Collision, position: v.Vec3, body: data.Body, slot: u16) !?v.Vec3 {
    return floorWithin(collision, .{}, position, body, slot);
}
pub const Limits = struct { maximum_drop: f32 = 32 };
fn floorWithin(collision: Collision, limits: Limits, position: v.Vec3, body: data.Body, slot: u16) !?v.Vec3 {
    // Sweep upward first: a low ceiling limits step clearance, but does not
    // turn an otherwise supported walking corridor into a missing floor.
    const clearance = try collision.trace(.{ .start = position, .end = v.add(position, .{ 0, 0, 18 }), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = worldMask(body) });
    if (clearance.all_solid) return null;
    const hit = try collision.trace(.{ .start = clearance.end, .end = v.add(position, .{ 0, 0, -limits.maximum_drop - 0.25 }), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = worldMask(body) });
    if (hit.start_solid or hit.fraction == 1 or hit.normal[2] < 0.7 or hit.contents & (c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO) != 0) return null;
    return hit.end;
}
/// The navigation areas are compiled for the player's standing hull (feet 24 below the origin):
/// an actor of another height asks from where a player standing on its floor would be.
pub fn navigationOrigin(position: v.Vec3, body: data.Body) v.Vec3 {
    return .{ position[0], position[1], position[2] + body.mins[2] + 24 };
}
pub fn direct(position: v.Vec3, destination: v.Vec3, body: data.Body, slot: u16) !bool {
    return directWith(@import("actor_collision.zig").service(), position, destination, body, slot);
}
pub fn directWith(collision: Collision, position: v.Vec3, destination: v.Vec3, body: data.Body, slot: u16) !bool {
    return directWithin(collision, .{}, position, destination, body, slot);
}
fn directWithin(collision: Collision, limits: Limits, position: v.Vec3, destination: v.Vec3, body: data.Body, slot: u16) !bool {
    return directProbe(collision, limits, position, destination, body, slot);
}
/// Static raised-box probes can overlap a stair riser even where the swept
/// step motor crosses it. Qualify that alternative with the actual motor,
/// retaining floor, drop, liquid and final-height constraints throughout.
fn sweptWalk(collision: Collision, limits: Limits, position: v.Vec3, destination: v.Vec3, body: data.Body, slot: u16, speed: f32) !bool {
    const span = nav.horizontalDistance(position, destination);
    if (span > 512) return false;
    var motion: slide.State = .{ .position = position, .velocity = @splat(0) };
    if (speed <= 0) return false;
    // Ramps project horizontal motion onto their plane. Budget that slower
    // progress rather than assuming every tick covers a flat-ground stride.
    const steps: usize = @intFromFloat(@min(200, @ceil(span / (speed * 0.025)) + 12));
    for (0..steps) |_| {
        const before = motion.position;
        const wanted = nav.velocity(before, destination, speed, 0.05);
        motion.velocity[0] = wanted[0];
        motion.velocity[1] = wanted[1];
        const ground = try collision.trace(.{ .start = before, .end = v.add(before, .{ 0, 0, -0.25 }), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = worldMask(body) });
        const supported = !ground.start_solid and !ground.all_solid and ground.fraction < 1 and ground.normal[2] >= 0.7;
        if (supported and motion.velocity[2] < 0) motion.velocity[2] = 0;
        var stepper: slide.Context = .{ .service = collision, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = worldMask(body), .delta = 0.05, .gravity = 800, .ground = if (supported) ground.normal else null };
        try stepper.step(&motion);
        const floor = try collision.trace(.{ .start = motion.position, .end = v.add(motion.position, .{ 0, 0, -limits.maximum_drop - 0.25 }), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = worldMask(body) | c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO });
        // A stair's bevel can be the hull's temporary contact while the
        // actual step motor climbs it. It is not a standing destination.
        const climbing = motion.position[2] >= before[2] - 0.1 and floor.fraction < 0.01 and floor.normal[2] > 0.15;
        if (floor.start_solid or floor.all_solid or floor.fraction == 1 or (floor.normal[2] < 0.7 and !climbing) or floor.contents & (c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO) != 0) {
            walkRejected(slot, position, destination, motion.position, "support", floor.fraction, floor.start_solid, floor.normal[2]);
            return false;
        }
        if (before[2] - motion.position[2] > limits.maximum_drop) return false;
        if (nav.horizontalDistance(motion.position, destination) <= 8 and floor.normal[2] >= 0.7) return @abs(motion.position[2] - destination[2]) <= 24;
        if (nav.horizontalDistance(before, motion.position) < 0.01) {
            walkRejected(slot, position, destination, motion.position, "no-progress", 0, false, 0);
            return false;
        }
    }
    walkRejected(slot, position, destination, motion.position, "budget", 0, false, 0);
    return false;
}
fn walkRejected(slot: u16, start: v.Vec3, goal: v.Vec3, point: v.Vec3, reason: []const u8, fraction: f32, solid: bool, normal: f32) void {
    if (@import("builtin").is_test or engine.integer("developer") < 3) return;
    var text: [384]u8 = undefined;
    engine.print(std.fmt.bufPrintZ(&text, "dk3 actor walk rejected: slot={d} reason={s} start={d:.2},{d:.2},{d:.2} goal={d:.2},{d:.2},{d:.2} point={d:.2},{d:.2},{d:.2} fraction={d:.3} solid={d} normal={d:.3}\n", .{ slot, reason, start[0], start[1], start[2], goal[0], goal[1], goal[2], point[0], point[1], point[2], fraction, @intFromBool(solid), normal }) catch "");
}
fn directProbe(collision: Collision, limits: Limits, position: v.Vec3, destination: v.Vec3, body: data.Body, slot: u16) !bool {
    const distance = v.length(v.subtract(destination, position));
    if (distance > 512) return false;
    const count: usize = @intFromFloat(@ceil(distance / 24));
    var previous = position;
    for (0..@max(count, 1)) |i| {
        const fraction = @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(@max(count, 1)));
        var point = v.add(position, v.scale(v.subtract(destination, position), fraction));
        // Probe from the last supported height. Interpolating toward a lower
        // target can hide a cliff from the descent bound and alternate between
        // a direct goal and a detour while actual locomotion refuses the drop.
        point[2] = previous[2];
        const supported = try floorWithin(collision, limits, point, body, slot) orelse return false;
        // Cross a descending edge horizontally before falling. A diagonal
        // sweep between floor heights can cut through the supporting ledge.
        var start = previous;
        var end = supported;
        const base_z = @max(previous[2], supported[2]);
        const rise = try collision.trace(.{ .start = previous, .end = .{ previous[0], previous[1], base_z + 18 }, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = worldMask(body) });
        if (rise.start_solid or rise.all_solid or rise.end[2] < base_z) return false;
        start[2] = rise.end[2];
        end[2] = start[2];
        const hit = try collision.trace(.{ .start = start, .end = end, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = worldMask(body) });
        if (hit.start_solid or hit.fraction < 1) return false;
        previous = supported;
    }
    return @abs(previous[2] - destination[2]) <= 24;
}
/// A route service that falls back to the authored node graph where the player-hull navigation
/// areas have none: a small actor in a pipe, a corner or under a prop, where a player cannot stand.
pub const NodeFallback = struct {
    primary: nav.Service,
    routes: *const @import("air_routes.zig").Routes,
    body: data.Body,
    pub fn service(self: *NodeFallback) nav.Service {
        return .{ .context = self, .next_fn = next };
    }
    fn next(raw: *anyopaque, request: nav.Request) !?nav.Waypoint {
        const self: *NodeFallback = @ptrCast(@alignCast(raw));
        if (try self.primary.next(request)) |point| return point;
        // Requests carry the navigation origin; the node graph wants the body's own.
        const position = v.subtract(request.position, .{ 0, 0, self.body.mins[2] + 24 });
        return .{ .point = try self.routes.next(position, request.destination, self.body, request.slot) orelse return null };
    }
};
pub fn escape(service: nav.Service, position: v.Vec3, threat: v.Vec3, body: data.Body, slot: u16) !?v.Vec3 {
    return escapeWith(@import("actor_collision.zig").service(), service, position, threat, body, slot);
}
fn escapeWith(collision: Collision, service: nav.Service, position: v.Vec3, threat: v.Vec3, body: data.Body, slot: u16) !?v.Vec3 {
    const away = @import("../domain/actors.zig").fleeVelocity(position, threat, 1);
    var best: ?v.Vec3 = null;
    var score: f32 = nav.horizontalDistance(position, threat);
    // Prefer increasing distance from danger; retain only supported, reachable destinations.
    for ([_]f32{ 0, 45, -45, 90, -90, 135, -135, 180 }) |degrees| {
        const radians = degrees * std.math.pi / 180;
        const direction: v.Vec3 = .{ away[0] * @cos(radians) - away[1] * @sin(radians), away[0] * @sin(radians) + away[1] * @cos(radians), 0 };
        for ([_]f32{ 192, 96 }) |distance| {
            const candidate = try floorWith(collision, v.add(position, v.scale(direction, distance)), body, slot) orelse continue;
            const rank = nav.horizontalDistance(candidate, threat) - @abs(degrees) * 0.1;
            if (rank <= score) continue;
            if (!try directWith(collision, position, candidate, body, slot) and try service.next(.{ .position = navigationOrigin(position, body), .destination = candidate, .slot = slot }) == null) continue;
            best = candidate;
            score = rank;
        }
    }
    return best;
}
/// How a class flees.
pub const Flee = struct {
    /// The flight ends where it was headed, when blocked, when the panic ends, or when there is
    /// nowhere to run; it is not re-planned on the way.
    settles: bool = false,
};
pub fn step(actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, service: nav.Service, threat: v.Vec3, speed: f32, slot: u16, now: i64, elapsed: u32) !void {
    _ = try stepWithCollision(@import("actor_collision.zig").service(), .{}, actor, pose, body, velocity, service, threat, speed, slot, now, elapsed);
}
/// `step` for a class with its own flight rule; true when a settling flight ended this step.
pub fn stepFleeing(flee: Flee, actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, service: nav.Service, threat: v.Vec3, speed: f32, slot: u16, now: i64, elapsed: u32) !bool {
    return stepWithCollision(@import("actor_collision.zig").service(), flee, actor, pose, body, velocity, service, threat, speed, slot, now, elapsed);
}
fn stepWithCollision(collision: Collision, flee: Flee, actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, service: nav.Service, threat: v.Vec3, speed: f32, slot: u16, now: i64, elapsed: u32) !bool {
    return stepLimitedWithCollision(collision, .{}, flee, actor, pose, body, velocity, service, threat, speed, slot, now, elapsed);
}
pub fn stepLimited(limits: Limits, actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, service: nav.Service, threat: v.Vec3, speed: f32, slot: u16, now: i64, elapsed: u32) !void {
    _ = try stepLimitedWithCollision(@import("actor_collision.zig").service(), limits, .{}, actor, pose, body, velocity, service, threat, speed, slot, now, elapsed);
}
fn stepLimitedWithCollision(collision: Collision, limits: Limits, flee: Flee, actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, service: nav.Service, threat: v.Vec3, speed: f32, slot: u16, now: i64, elapsed: u32) !bool {
    const planning = @import("actor_collision.zig").asProbe(collision);
    const driven = body.motion_owner != null;
    var moving = !driven and (actor.mode == .flee or actor.mode == .chase);
    const worker = flee.settles;
    var settled = false;
    if (moving and actor.mode == .flee and worker and actor.route.fleeing and (actor.route.blocked or nav.horizontalDistance(pose.position, actor.route.destination) < 24 or now >= actor.panic_until)) {
        settled = true;
        actor.mode = .idle;
        actor.changed_ms = now;
        moving = false;
    }
    if (moving and actor.mode == .flee) {
        if (!actor.route.fleeing or (!worker and now >= actor.escape_until) or actor.route.blocked or nav.horizontalDistance(pose.position, actor.route.destination) < 24) {
            const destination = try escapeWith(planning, service, pose.position, threat, body.*, slot);
            actor.route = .{ .destination = destination orelse pose.position, .fleeing = true, .progress_ms = now, .progress_position = pose.position };
            actor.escape_until = now + 800;
            if (worker and destination == null) {
                settled = true;
                actor.mode = .idle;
                actor.changed_ms = now;
                moving = false;
            }
        }
    } else if (actor.route.fleeing) actor.route = .{};
    var goal: ?nav.Waypoint = null;
    var physical_corridor = false;
    if (moving) {
        const destination = if (actor.mode == .flee) actor.route.destination else actor.threat_position;
        goal = try actor.route.update(service, .{ .position = navigationOrigin(pose.position, body.*), .destination = destination, .slot = slot }, now);
        // A nearby visible goal needs no detour, but must have a continuous safe floor.
        if (try directWithin(planning, limits, pose.position, destination, body.*, slot)) goal = .{ .point = destination };
        physical_corridor = now < actor.route.physical_until_ms and v.length(v.subtract(destination, actor.route.physical_goal)) < 8;
        if (physical_corridor or try sweptWalk(planning, limits, pose.position, destination, body.*, slot, speed)) {
            if (!physical_corridor) {
                actor.route.physical_until_ms = now + 500;
                actor.route.physical_goal = destination;
            }
            physical_corridor = true;
            goal = .{ .point = destination };
            // Keep the physically qualified corridor long enough to walk it;
            // switching back after the first successful stride recreates the
            // same obstruction/route oscillation that caused the stall.
            actor.route.waypoint = goal;
            actor.route.refresh_ms = now + 2000;
        }
    }
    var motion: slide.State = .{ .position = pose.position, .velocity = velocity.linear };
    var remaining = elapsed;
    while (remaining > 0) {
        const milliseconds = @min(remaining, 50);
        remaining -= milliseconds;
        const delta = @as(f32, @floatFromInt(milliseconds)) * 0.001;
        const ground = try collision.trace(.{ .start = motion.position, .end = v.add(motion.position, .{ 0, 0, -0.25 }), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask });
        // Match the existing slide/player contract: overclip leaves a small
        // positive separating velocity at rest. Only a real upward departure
        // from the supporting plane should disable ground locomotion.
        const departing = motion.velocity[2] > 0 and v.dot(motion.velocity, ground.normal) > 10;
        var grounded = !departing and !ground.all_solid and !ground.start_solid and ground.fraction < 1 and ground.normal[2] >= 0.7;
        actor.ground_entity = if (grounded) ground.entity else c.ENTITYNUM_NONE;
        body.grounded = grounded;
        if ((grounded or physical_corridor) and !driven) {
            motion.velocity[0] = 0;
            motion.velocity[1] = 0;
            if (grounded and motion.velocity[2] < 0) motion.velocity[2] = 0;
            if (goal) |point| {
                const horizontal = nav.velocity(motion.position, point.point, speed, delta);
                const ahead = v.add(motion.position, v.scale(horizontal, @max(delta, 0.1)));
                if (point.jump or physical_corridor or try floorWithin(planning, limits, ahead, body.*, slot) != null or try sweptWalk(planning, limits, motion.position, ahead, body.*, slot, speed)) {
                    motion.velocity[0] = horizontal[0];
                    motion.velocity[1] = horizontal[1];
                    if (v.length(horizontal) > 0.1) pose.angles[1] = std.math.atan2(horizontal[1], horizontal[0]) * (180.0 / std.math.pi);
                    if (point.jump and now >= actor.jump_ready_ms) {
                        motion.velocity[2] = 270;
                        grounded = false;
                        body.grounded = false;
                        actor.ground_entity = c.ENTITYNUM_NONE;
                        actor.jump_ready_ms = now + 700;
                    }
                }
            }
        }
        var movement: slide.Context = .{ .service = collision, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask, .delta = delta, .gravity = 800, .ground = if (grounded) ground.normal else null };
        if (actor.mode == .dead) _ = try movement.move(&motion) else try movement.step(&motion);
    }
    pose.position = motion.position;
    velocity.linear = motion.velocity;
    if (!@import("builtin").is_test and engine.integer("developer") >= 3 and moving) {
        const point = if (goal) |waypoint| waypoint.point else pose.position;
        var text: [384]u8 = undefined;
        engine.print(try std.fmt.bufPrintZ(&text, "dk3 actor motor: t={d} slot={d} pos={d:.2},{d:.2},{d:.2} vel={d:.2},{d:.2},{d:.2} goal={d:.2},{d:.2},{d:.2} physical={d} blocked={d} ground={d}\n", .{ now, slot, pose.position[0], pose.position[1], pose.position[2], velocity.linear[0], velocity.linear[1], velocity.linear[2], point[0], point[1], point[2], @intFromBool(physical_corridor), @intFromBool(actor.route.blocked), @intFromBool(body.grounded) }));
    }
    return settled;
}

pub fn sidestep(pose: data.Transform, body: data.Body, slot: u16, roll: f32) !?v.Vec3 {
    return sidestepDistance(pose, body, slot, roll, 96);
}
pub fn sidestepDistance(pose: data.Transform, body: data.Body, slot: u16, roll: f32, requested: f32) !?v.Vec3 {
    const distance = @import("actor_catalog").evasion.distance(requested);
    const right = v.basis(pose.angles).right;
    const side: f32 = if (roll < 0.5) -1 else 1;
    for ([_]f32{ side, -side }) |sign| {
        const destination = v.add(pose.position, v.scale(right, sign * distance));
        const hit = try @import("actor_collision.zig").service().trace(.{ .start = pose.position, .end = destination, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask });
        if (hit.start_solid or hit.fraction < 1) continue;
        const ground = try @import("actor_collision.zig").service().trace(.{ .start = destination, .end = v.add(destination, .{ 0, 0, -32 }), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask });
        if (ground.start_solid or ground.fraction == 1 or ground.normal[2] < 0.7 or !try direct(pose.position, ground.end, body, slot)) continue;
        return ground.end;
    }
    return null;
}

test "settled ground actors start pursuit despite overclip lift and still jump" {
    const Fixture = struct {
        fn trace(_: *anyopaque, request: @import("../../core/domain/collision.zig").Request) !@import("../../core/domain/collision.zig").Trace {
            const bottom = request.start[2] + request.mins[2];
            const end_bottom = request.end[2] + request.mins[2];
            if (end_bottom < 0.125 and bottom >= 0.1249) {
                const fraction = std.math.clamp((bottom - 0.125) / (bottom - end_bottom), 0, 1);
                return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = c.ENTITYNUM_WORLD };
            }
            return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
        }
        fn next(_: *anyopaque, request: nav.Request) !?nav.Waypoint {
            return .{ .point = request.destination };
        }
    };
    var fixture: u8 = 0;
    const collision: Collision = .{ .context = &fixture, .trace_fn = Fixture.trace };
    const navigation: nav.Service = .{ .context = &fixture, .next_fn = Fixture.next };
    var actor: data.Actor = .{ .definition = @import("actor_catalog").find("monster_mishimaguard").? };
    var pose: data.Transform = .{ .position = .{ 0, 0, 24.125 } };
    var body: data.Body = .{ .mins = .{ -16, -16, -24 }, .maxs = .{ 16, 16, 32 }, .collision_mask = c.MASK_PLAYERSOLID };
    // Captured from stationary authored workers in e1m2a.
    var velocity: data.Velocity = .{ .linear = .{ 0, 0, 0.04 } };
    for (0..10) |i| _ = try stepWithCollision(collision, .{}, &actor, &pose, &body, &velocity, navigation, @splat(0), 100, 64, @intCast(i * 50), 50);
    // Exercise the actual idle-to-chase motor after real slide settling.
    try std.testing.expect(body.grounded);
    actor.mode = .chase;
    actor.threat_position = .{ 200, 0, 24.125 };
    for (0..20) |i| _ = try stepWithCollision(collision, .{}, &actor, &pose, &body, &velocity, navigation, actor.threat_position, 100, 64, @intCast(500 + i * 50), 50);
    try std.testing.expect(pose.position[0] > 90);
    try std.testing.expect(body.grounded);
    try std.testing.expectApproxEqAbs(@as(f32, 24.125), pose.position[2], 0.25);
    velocity.linear = .{ 0, 0, 270 };
    _ = try stepWithCollision(collision, .{}, &actor, &pose, &body, &velocity, navigation, actor.threat_position, 100, 64, 1550, 50);
    try std.testing.expect(!body.grounded and pose.position[2] > 30 and velocity.linear[2] > 200);
}

test "class descent bounds admit a supported plinth route and still reject cliffs and hazards" {
    const Fixture = struct {
        depth: f32 = 48,
        hazard: u32 = 0,
        fn trace(raw: *anyopaque, request: @import("../../core/domain/collision.zig").Request) !@import("../../core/domain/collision.zig").Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const floor: f32 = if (request.end[0] < 32) 0 else -self.depth;
            const from = request.start[2] + request.mins[2];
            const to = request.end[2] + request.mins[2];
            if (from >= floor and to < floor) {
                const fraction = (from - floor) / (from - to);
                return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = c.ENTITYNUM_WORLD, .contents = self.hazard };
            }
            return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
        }
    };
    var fixture: Fixture = .{};
    const collision: Collision = .{ .context = &fixture, .trace_fn = Fixture.trace };
    const body: data.Body = .{ .mins = .{ -24, -24, -24 }, .maxs = .{ 24, 24, 55 }, .collision_mask = c.MASK_PLAYERSOLID };
    const from: v.Vec3 = .{ 0, 0, 24 };
    const to: v.Vec3 = .{ 120, 0, -24 };
    try std.testing.expect(!try directWithin(collision, .{}, from, to, body, 1));
    try std.testing.expect(try directWithin(collision, .{ .maximum_drop = 64 }, from, to, body, 1));
    fixture.depth = 128;
    try std.testing.expect(!try directWithin(collision, .{ .maximum_drop = 64 }, from, to, body, 1));
    fixture.depth = 48;
    for ([_]u32{ c.CONTENTS_LAVA, c.CONTENTS_SLIME, c.CONTENTS_DK3_NITRO }) |hazard| {
        fixture.hazard = hazard;
        try std.testing.expect(!try directWithin(collision, .{ .maximum_drop = 64 }, from, to, body, 1));
    }
}
