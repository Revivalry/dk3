// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: special_mover. Server behaviour of the special mover map entity class.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const abi = @import("../../../../engine/abi.zig");
const engine = @import("../../../../engine/server.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const pusher = @import("../../../../mechanics/server/pusher.zig");
const c = abi.c;
pub fn spawn(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, now: i64) !void {
    for (slots.occupants) |occupant| {
        const entity = occupant orelse continue;
        const object = (world.get(entity, data.MapObject) catch continue).*;
        if (!std.mem.eql(u8, object.classname, "func_rotate") and !std.mem.eql(u8, object.classname, "func_door_secret")) continue;
        const transform = (try world.get(entity, data.Transform)).*;
        const speed = try prop.number(object, "speed", 100);
        if (std.mem.eql(u8, object.classname, "func_rotate")) {
            var rate: data.Vec3 = @splat(0);
            rate[if (object.flags & 4 != 0) @as(usize, 2) else if (object.flags & 8 != 0) 0 else 1] = (if (speed > 0) speed else 100) * @as(f32, if (object.flags & 2 != 0) -1 else 1);
            try world.put(entity, data.Rotation{ .base = transform.angles, .rate = rate, .active = object.flags & 1 != 0, .started_ms = now, .damage = @intFromFloat(try prop.number(object, "damage", try prop.number(object, "dmg", 2))) });
        } else if (std.mem.eql(u8, object.classname, "func_door_secret")) {
            const body = (try world.get(entity, data.Body)).*;
            const size = v.add(body.maxs, v.scale(body.mins, -1));
            const basis = v.basis(transform.angles);
            const direction = if (object.flags & 4 != 0) v.cross(basis.right, basis.forward) else basis.right;
            var first: f32 = 0;
            var second: f32 = 0;
            for (0..3) |axis| {
                first += @abs(direction[axis]) * size[axis];
                second += @abs(basis.forward[axis]) * size[axis];
            }
            const middle = v.add(transform.position, v.scale(direction, first * @as(f32, if (object.flags & (2 | 4) != 0) -1 else 1)));
            var group = try world.persistentId(entity);
            if (prop.text(object, "team")) |team| if (team.len > 0) {
                for (slots.occupants) |other| {
                    const part = other orelse continue;
                    const secret = world.get(part, data.Secret) catch continue;
                    const part_object = (try world.get(part, data.MapObject)).*;
                    if (std.mem.eql(u8, team, prop.text(part_object, "team") orelse "")) group = @min(group, secret.group);
                }
            };
            try world.put(entity, data.Secret{ .closed = transform.position, .first = middle, .opened = v.add(middle, v.scale(basis.forward, second)), .motion = .{ .base = transform.position, .end = transform.position }, .speed = if (speed > 0) speed else 100, .wait_ms = try prop.milliseconds(object, "wait", 3), .stay_open = object.flags & 1 != 0, .damage = @intFromFloat(try prop.number(object, "damage", try prop.number(object, "dmg", 2))), .group = group });
            (try world.get(entity, data.Transform)).angles = @splat(0);
        } else continue;
        try publish(world, entity, projections);
    }
}
pub fn publish(world: *data.World, entity: ecs.Entity, projections: []abi.EntityProjection) !void {
    const transform = (try world.get(entity, data.Transform)).*;
    const projection = &projections[(try world.get(entity, data.Binding)).slot];
    projection.shared.currentOrigin = transform.position;
    projection.shared.currentAngles = transform.angles;
    const wire = @import("../../../../engine/trajectory.zig");
    projection.state.pos = wire.stationary(transform.position);
    projection.state.apos = wire.stationary(transform.angles);
    if (world.get(entity, data.Rotation)) |rotation| {
        if (rotation.active) projection.state.apos = wire.linear(rotation.base, rotation.rate, rotation.started_ms);
    } else |_| if (world.get(entity, data.Secret)) |secret| {
        if (secret.moving()) projection.state.pos = wire.fromMotion(secret.motion);
    } else |_| {}
    engine.link(projection);
}
/// Rotation fires targets on each toggle; secrets fire only on full opening.
pub fn use(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, entity: ecs.Entity, owner: u32, now: i64) !bool {
    if (world.get(entity, data.Rotation)) |rotation| {
        rotation.toggle((try world.get(entity, data.Transform)).angles, now);
        try publish(world, entity, projections);
        return true;
    } else |_| {}
    const original = try world.get(entity, data.Secret);
    const master = world.find(original.group) orelse return error.MissingMoverMaster;
    const control = try world.get(master, data.Secret);
    if (control.phase != .closed or !@import("../../../../mechanics/server/locks.zig").allows(world, (try world.get(master, data.MapObject)).*, owner)) return false;
    for (slots.occupants) |occupant| {
        const part = occupant orelse continue;
        const secret = world.get(part, data.Secret) catch continue;
        if (secret.group != control.group) continue;
        secret.phase = .closed;
        _ = try secret.use((try world.get(part, data.Transform)).position, now, owner);
        try publish(world, part, projections);
    }
    return false;
}
pub fn prepare(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, now: i64) !void {
    for (slots.occupants) |occupant| {
        const entity = occupant orelse continue;
        const secret = world.get(entity, data.Secret) catch continue;
        try secret.prepare((try world.get(entity, data.Transform)).position, now);
        try publish(world, entity, projections);
    }
}
pub fn step(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, now: i64, elapsed: u32) !void {
    for (slots.occupants) |occupant| {
        const entity = occupant orelse continue;
        if (@import("../../../../mechanics/server/attachments.zig").attached(world, entity)) continue;
        var moves: [ecs.max_entities]pusher.Move = undefined;
        var count: usize = 0;
        var damage: i32 = 0;
        if (world.get(entity, data.Rotation)) |rotation| {
            var transform = (try world.get(entity, data.Transform)).*;
            transform.angles = rotation.sample(now);
            moves[0] = .{ .entity = entity, .destination = transform };
            count = 1;
            damage = rotation.damage;
        } else |_| if (world.get(entity, data.Secret)) |master| {
            if (master.group != try world.persistentId(entity)) continue;
            damage = master.damage;
            for (slots.occupants) |part_occupant| {
                const part = part_occupant orelse continue;
                const secret = world.get(part, data.Secret) catch continue;
                if (secret.group != master.group) continue;
                var transform = (try world.get(part, data.Transform)).*;
                if (secret.moving()) transform.position = secret.motion.sample(now);
                moves[count] = .{ .entity = part, .destination = transform };
                count += 1;
            }
        } else |_| continue;
        if (try pusher.push(world, slots, projections, moves[0..count], now, elapsed)) |blocker| {
            _ = try @import("../../../../mechanics/server/damage.zig").apply(world, blocker, damage, now, .{});
        }
    }
}
pub fn finish(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, now: i64) !@import("../../mover/server/movers.zig").Arrivals {
    var arrivals: @import("../../mover/server/movers.zig").Arrivals = .{};
    for (slots.occupants) |occupant| {
        const entity = occupant orelse continue;
        const secret = world.get(entity, data.Secret) catch continue;
        if (try secret.finish(now)) {
            arrivals.entities[arrivals.count] = entity;
            arrivals.count += 1;
        }
        try publish(world, entity, projections);
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
pub fn worldFinish(frame: *const system_context.Step) !system_context.Arrivals {
    return finish(frame.world, frame.slots, frame.projections, frame.now);
}
/// A finished secret mover fires its owner's targets.
pub fn worldArrive(frame: *const system_context.Step, arrivals: *const system_context.Arrivals) !void {
    for (arrivals.slice()) |entity| {
        if (!frame.world.alive(entity)) continue;
        try frame.targets.fire(frame.world, frame.slots, frame.projections, entity, (try frame.world.get(entity, data.Secret)).owner, frame.now);
    }
}
const system_context = @import("../../../../mechanics/server/system_context.zig");
/// Target use stage (use_classes.zig): a secret or rotating brush that starts fires its targets.
pub fn useTarget(using: *@import("../../../../mechanics/server/entity_classes/registry.zig").Use) !bool {
    if ((using.world.get(using.entity, data.Secret) catch null) == null and (using.world.get(using.entity, data.Rotation) catch null) == null) return false;
    if (try use(using.world, using.slots, using.projections, using.entity, using.activator, using.now)) try using.router.fire(using.world, using.slots, using.projections, using.entity, using.activator, using.now);
    return true;
}
/// Ridden-assembly hook (world_system_classes.zig `motion`): publishes a secret or rotating part.
pub fn publishPart(world: *data.World, entity: ecs.Entity, projections: []abi.EntityProjection) !bool {
    if ((world.get(entity, data.Secret) catch null) == null and (world.get(entity, data.Rotation) catch null) == null) return false;
    try publish(world, entity, projections);
    return true;
}
/// Attachment hook (world_system_classes.zig `motion`): a part whose parent moved carries its own
/// motion along.
pub fn carryPart(world: *data.World, entity: ecs.Entity, before: data.Transform, after: data.Transform) void {
    const pose = @import("../../../../mechanics/domain/poses.zig");
    if (world.get(entity, data.Secret)) |secret| {
        secret.closed = pose.point(secret.closed, before, after);
        secret.first = pose.point(secret.first, before, after);
        secret.opened = pose.point(secret.opened, before, after);
        secret.motion.base = pose.point(secret.motion.base, before, after);
        secret.motion.end = pose.point(secret.motion.end, before, after);
    } else |_| {}
    if (world.get(entity, data.Rotation)) |rotation| {
        rotation.base = pose.orientation(rotation.base, before.angles, after.angles);
        rotation.rate = pose.rotate(rotation.rate, before.angles, after.angles);
    } else |_| {}
}
/// Attachment hook: a held assembly delays its parts' motion.
pub fn delayPart(world: *data.World, entity: ecs.Entity, elapsed: u32) void {
    if (world.get(entity, data.Rotation)) |rotation| rotation.started_ms += elapsed else |_| {}
    if (world.get(entity, data.Secret)) |secret| secret.motion.start_ms += elapsed else |_| {}
}
/// Attachment hook: where a moving part is at `now`.
pub fn samplePart(world: *data.World, entity: ecs.Entity, now: i64, destination: *data.Transform) void {
    if (world.get(entity, data.Secret)) |secret| {
        if (secret.moving()) destination.position = secret.motion.sample(now);
    } else |_| {}
    if (world.get(entity, data.Rotation)) |rotation| destination.angles = rotation.sample(now) else |_| {}
}
/// Mover part ownership (platforms.zig).
pub fn ownsPart(world: *data.World, entity: ecs.Entity) bool {
    return (world.get(entity, data.Secret) catch null) != null or (world.get(entity, data.Rotation) catch null) != null;
}
