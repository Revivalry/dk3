// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: train. Server behaviour of the train map entity class.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const rules = @import("../domain/trains.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const names = @import("../../../../mechanics/server/names.zig");
const abi = @import("../../../../engine/abi.zig");
const engine = @import("../../../../engine/server.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const c = abi.c;
pub fn spawn(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, now: i64) !void {
    var entities: [ecs.max_entities]ecs.Entity = undefined;
    var count: usize = 0;
    var query = world.queryAccess(data.World.mask(.{data.MapObject}), 0, 0);
    {
        defer query.deinit();
        while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, object| if (std.mem.eql(u8, object.classname, "func_train")) {
            entities[count] = entity;
            count += 1;
        };
    }
    for (entities[0..count]) |entity| {
        const object = (try world.get(entity, data.MapObject)).*;
        const transform = (try world.get(entity, data.Transform)).*;
        if (slots.find(entity) == null) {
            if (object.model.len != 0) return error.InvalidTrainModel;
            const slot = try slots.acquire(entity, null);
            projections[slot] = std.mem.zeroes(abi.EntityProjection);
            try world.put(entity, data.Binding{ .slot = slot });
            try world.put(entity, data.Body{});
            projections[slot].shared.svFlags = c.SVF_NOCLIENT;
            projections[slot].state.eType = c.ET_MOVER;
        }
        const speed = try prop.number(object, "speed", 100);
        try world.put(entity, data.Train{ .next_target = object.target, .speed = if (speed > 0) speed else 100, .position = .{ .base = transform.position, .end = transform.position }, .angles = .{ .base = transform.angles, .end = transform.angles }, .action = try @import("../../../../core/domain/time.zig").Deadline.after(now, 100), .force = object.flags & 64 != 0 or try prop.number(object, "forcemove", 0) != 0, .damage = @intFromFloat(try prop.number(object, "damage", try prop.number(object, "dmg", 2))) });
        try publish(world, entity, projections);
    }
}
fn corner(world: *data.World, name: []const u8) !?ecs.Entity {
    if (name.len == 0) return null;
    const matches = try names.named(world, name);
    if (matches.count == 0) return null;
    const entity = world.find(matches.ids[0]).?;
    if (!std.mem.eql(u8, (try world.get(entity, data.MapObject)).classname, "path_corner_train")) return null;
    return entity;
}
/// A stopped train's corner and the one it leaves for next: a rider tells a
/// stop part-way along a run from the end of it.
pub fn stops(world: *data.World, entity: ecs.Entity) !?struct { at: @import("../../../../core/domain/vector.zig").Vec3, next: @import("../../../../core/domain/vector.zig").Vec3 } {
    const train = world.get(entity, data.Train) catch return null;
    if (train.phase == .moving or train.phase == .teleporting) return null;
    const at = world.find(train.destination) orelse return null;
    const next = try corner(world, train.next_target) orelse return null;
    return .{ .at = (try world.get(at, data.Transform)).position, .next = (try world.get(next, data.Transform)).position };
}
pub fn publish(world: *data.World, entity: ecs.Entity, projections: []abi.EntityProjection) !void {
    const transform = (try world.get(entity, data.Transform)).*;
    const train = (try world.get(entity, data.Train)).*;
    const projection = &projections[(try world.get(entity, data.Binding)).slot];
    projection.shared.currentOrigin = transform.position;
    projection.shared.currentAngles = transform.angles;
    projection.state.pos = if (train.phase == .moving) @import("../../../../engine/trajectory.zig").fromMotion(train.position) else @import("../../../../engine/trajectory.zig").stationary(transform.position);
    projection.state.apos = if (train.phase == .moving) @import("../../../../engine/trajectory.zig").fromMotion(train.angles) else @import("../../../../engine/trajectory.zig").stationary(transform.angles);
    engine.link(projection);
}
fn arrived(world: *data.World, entity: ecs.Entity, now: i64) !void {
    const train = try world.get(entity, data.Train);
    const destination = world.find(train.destination) orelse {
        train.phase = .paused;
        train.action = .{};
        return;
    };
    const object = (try world.get(destination, data.MapObject)).*;
    train.next_target = object.target;
    train.arrival_pending = true;
    try train.reached(now, object.flags & 8 != 0, try prop.number(object, "health", 0));
}
fn initialize(world: *data.World, projections: []abi.EntityProjection, entity: ecs.Entity, now: i64) !bool {
    const train = try world.get(entity, data.Train);
    const object = (try world.get(entity, data.MapObject)).*;
    const first = try corner(world, train.next_target) orelse {
        train.phase = .paused;
        train.action = .{};
        return false;
    };
    const point = (try world.get(first, data.Transform)).position;
    try @import("../../../../mechanics/server/pusher.zig").teleport(world, projections, entity, point, now);
    train.position = .{ .base = point, .end = point };
    train.destination = try world.persistentId(first);
    train.next_target = (try world.get(first, data.MapObject)).target;
    train.phase = .paused;
    train.action = .{};
    train.departure_wait_ms = 0;
    const first_object = (try world.get(first, data.MapObject)).*;
    const named = object.targetname.len > 0;
    if (!rules.startsAtOnce(object.flags & 128 != 0, named, first_object.flags & 8 != 0, try prop.number(first_object, "health", 0))) {
        // An unnamed train still settles at its waiting corner as an arrival does.
        if (!named) try arrived(world, entity, now);
        return !named;
    }
    try leave(world, projections, entity, now);
    return true;
}
fn leave(world: *data.World, projections: []abi.EntityProjection, entity: ecs.Entity, now: i64) !void {
    const train = try world.get(entity, data.Train);
    const destination = try corner(world, train.next_target) orelse {
        train.phase = .paused;
        train.action = .{};
        return;
    };
    const previous = if (world.find(train.destination)) |point| (try world.get(point, data.MapObject)).* else null;
    var speed = train.speed;
    var rotation: data.Vec3 = @splat(0);
    var rates: data.Vec3 = @splat(0);
    var flags: u32 = 0;
    train.departure_wait_ms = 0;
    if (previous) |object| {
        train.departure_wait_ms = try prop.milliseconds(object, "wait", 0);
        const supplied_speed = try prop.number(object, "speed", 0);
        if (supplied_speed > 0) speed = supplied_speed;
        flags = object.flags;
        inline for (.{ "y", "z", "x" }, 0..) |axis, i| {
            rotation[i] = try prop.number(object, axis ++ "_distance", 0);
            rates[i] = try prop.number(object, axis ++ "_speed", 0);
        }
    }
    const transform = try world.get(entity, data.Transform);
    const destination_point = (try world.get(destination, data.Transform)).position;
    const leg = try rules.leg(transform.position, destination_point, transform.angles, speed, rotation, rates, flags);
    train.destination = try world.persistentId(destination);
    train.action = .{};
    train.position = .{ .base = transform.position, .end = destination_point, .start_ms = now, .duration_ms = leg.duration_ms };
    train.angles = .{ .base = transform.angles, .end = leg.angular_end, .start_ms = now, .duration_ms = leg.duration_ms };
    train.phase = .moving;
    if (flags & 32 != 0) {
        try @import("../../../../mechanics/server/pusher.zig").teleport(world, projections, entity, destination_point, now);
        train.phase = .teleporting;
        train.action = try @import("../../../../core/domain/time.zig").Deadline.after(now, 1);
    }
}
pub fn use(world: *data.World, projections: []abi.EntityProjection, entity: ecs.Entity, source: ?@import("../../../../mechanics/domain/world_references.zig").Ref, activator: u32, now: i64) !void {
    const train = try world.get(entity, data.Train);
    train.owner = activator;
    if (train.phase == .initializing) _ = try initialize(world, projections, entity, now);
    if (source) |other| if (other.world.alive(other.entity)) {
        const object = (other.get(data.MapObject) catch null);
        if (object) |value| {
            const redirected = prop.text(value.*, "path_target") orelse prop.text(value.*, "pathtarget");
            if (redirected) |name| if (name.len > 0) {
                train.next_target = name;
                try leave(world, projections, entity, now);
                try publish(world, entity, projections);
                return;
            };
        }
    };
    const triggered = if (world.find(train.destination)) |point| (try world.get(point, data.MapObject)).flags & 8 != 0 else false;
    if (train.canUse(triggered)) try leave(world, projections, entity, now);
    try publish(world, entity, projections);
}
pub const Arrivals = system_context.Arrivals;
const system_context = @import("../../../../mechanics/server/system_context.zig");
pub fn prepare(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, now: i64) !void {
    for (slots.occupants) |occupant| {
        const entity = occupant orelse continue;
        const train = world.get(entity, data.Train) catch continue;
        if (!train.action.due(now)) continue;
        switch (train.phase) {
            .initializing => {
                _ = try initialize(world, projections, entity, now);
            },
            .dwelling => try leave(world, projections, entity, now),
            .teleporting => try arrived(world, entity, now),
            else => {},
        }
        try publish(world, entity, projections);
    }
}
pub fn step(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, now: i64, elapsed: u32) !void {
    for (slots.occupants) |occupant| {
        const entity = occupant orelse continue;
        const train = world.get(entity, data.Train) catch continue;
        if (@import("../../../../mechanics/server/attachments.zig").attached(world, entity)) continue;
        const destination = if (train.phase == .moving) data.Transform{ .position = train.position.sample(now), .angles = train.angles.sample(now) } else (try world.get(entity, data.Transform)).*;
        const move: @import("../../../../mechanics/server/pusher.zig").Move = .{ .entity = entity, .destination = destination };
        if (try @import("../../../../mechanics/server/pusher.zig").push(world, slots, projections, &.{move}, now, elapsed, .held)) |blocker| {
            _ = try @import("../../../../mechanics/server/damage.zig").apply(world, blocker, train.damage, now, .{});
        }
    }
}
pub fn finish(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, now: i64) !Arrivals {
    var arrivals: Arrivals = .{};
    for (slots.occupants) |occupant| {
        const entity = occupant orelse continue;
        const train = world.get(entity, data.Train) catch continue;
        if (train.phase == .moving and train.position.finished(now)) try arrived(world, entity, now);
        try publish(world, entity, projections);
        if (train.arrival_pending) {
            train.arrival_pending = false;
            arrivals.entities[arrivals.count] = entity;
            arrivals.count += 1;
        }
    }
    return arrivals;
}
/// World-system hooks (world_system_classes.zig).
pub fn worldSpawn(spawning: *const system_context.Spawn) !void {
    try spawn(spawning.world, spawning.slots, spawning.projections, spawning.now);
}
pub fn worldPrepare(frame: *const system_context.Step) !void {
    try prepare(frame.world, frame.slots, frame.projections, frame.now);
}
pub fn worldMove(frame: *const system_context.Step) !void {
    try step(frame.world, frame.slots, frame.projections, frame.now, frame.elapsed);
}
pub fn worldFinish(frame: *const system_context.Step) !Arrivals {
    return finish(frame.world, frame.slots, frame.projections, frame.now);
}
/// A train arriving at a path corner fires the corner's `pathtarget`.
pub fn worldArrive(frame: *const system_context.Step, arrivals: *const Arrivals) !void {
    for (arrivals.slice()) |entity| {
        if (!frame.world.alive(entity)) continue;
        const train = (try frame.world.get(entity, data.Train)).*;
        if (frame.world.find(train.destination)) |point| {
            const object = (try frame.world.get(point, data.MapObject)).*;
            const name = @import("../../../../mechanics/server/properties.zig").text(object, "pathtarget") orelse "";
            try frame.targets.fireNamed(frame.world, frame.slots, frame.projections, name, entity, train.owner, frame.now);
        }
    }
}
/// An authored invisible train (no brush model) is projected here; a train with a brush model
/// takes the shared brush projection (projection_classes.zig).
pub const projected = .{data.Train};
/// Trains are admitted as brushes or as invisible trains, never on their own.
pub const restorable = false;
pub fn project(projecting: *const system_context.Project) !bool {
    const world = projecting.world;
    const entity = projecting.entity;
    if ((try world.get(entity, data.MapObject)).model.len != 0) return false;
    const body = (try world.get(entity, data.Body)).*;
    const projection = &projecting.projections[(try world.get(entity, data.Binding)).slot];
    projection.state.eType = abi.c.ET_MOVER;
    projection.shared.svFlags = abi.c.SVF_NOCLIENT;
    projection.shared.mins = body.mins;
    projection.shared.maxs = body.maxs;
    try publish(world, entity, projecting.projections);
    return true;
}
/// Target use stage (use_classes.zig).
pub fn useTarget(using: *@import("../../../../mechanics/server/entity_classes/registry.zig").Use) !bool {
    if ((using.world.get(using.entity, data.Train) catch null) == null) return false;
    try use(using.world, using.projections, using.entity, using.source, using.activator, using.now);
    return true;
}
/// Ridden-assembly hook (world_system_classes.zig `motion`): publishes a train part.
pub fn publishPart(world: *data.World, entity: ecs.Entity, projections: []abi.EntityProjection) !bool {
    if ((world.get(entity, data.Train) catch null) == null) return false;
    try publish(world, entity, projections);
    return true;
}
/// A resting train's stop and the next corner it heads for (world_system_classes.zig `motion`).
pub const nextStop = stops;
/// Attachment hook (world_system_classes.zig `motion`): a part whose parent moved carries its own
/// motion along.
pub fn carryPart(world: *data.World, entity: ecs.Entity, before: data.Transform, after: data.Transform) void {
    const pose = @import("../../../../mechanics/domain/poses.zig");
    if (world.get(entity, data.Train)) |train| {
        train.position.base = pose.point(train.position.base, before, after);
        train.position.end = pose.point(train.position.end, before, after);
        train.angles.base = pose.orientation(train.angles.base, before.angles, after.angles);
        train.angles.end = pose.orientation(train.angles.end, before.angles, after.angles);
    } else |_| {}
}
/// Attachment hook: a held assembly delays its parts' motion.
pub fn delayPart(world: *data.World, entity: ecs.Entity, elapsed: u32) void {
    if (world.get(entity, data.Train)) |train| {
        train.position.start_ms += elapsed;
        train.angles.start_ms += elapsed;
    } else |_| {}
}
/// Attachment hook: where a moving part is at `now`.
pub fn samplePart(world: *data.World, entity: ecs.Entity, now: i64, destination: *data.Transform) void {
    if (world.get(entity, data.Train)) |train| {
        if (train.phase == .moving) destination.* = .{ .position = train.position.sample(now), .angles = train.angles.sample(now) };
    } else |_| {}
}
/// Mover part ownership (platforms.zig).
pub fn ownsPart(world: *data.World, entity: ecs.Entity) bool {
    return (world.get(entity, data.Train) catch null) != null;
}
/// A train is a path platform (platforms.zig).
pub fn pathPhase(world: *data.World, entity: ecs.Entity) ?@import("../../../../mechanics/server/platforms.zig").PathPhase {
    const train = world.get(entity, data.Train) catch return null;
    return .{ .moving = train.phase == .moving, .teleporting = train.phase == .teleporting, .name = @tagName(train.phase) };
}
