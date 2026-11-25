// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Serial collision transaction. Nothing is published to ECS before every push succeeds.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const v = @import("../../core/domain/vector.zig");
const c = abi.c;
pub const Move = @import("attachments.zig").Move;
const Backup = struct { slot: u16, origin: v.Vec3, angles: v.Vec3, ground: i32, yaw_delta: i32 = 0 };
const Contact = struct { riding: bool, depth: usize, initial_overlap: bool, hit: @import("../../core/domain/collision.zig").Trace };
fn recoverContact(service: @import("../../core/domain/collision.zig").Collision, request: @import("../../core/domain/collision.zig").Request, destination: v.Vec3, contact: Contact) !?@import("../../core/domain/collision.zig").Trace {
    if (contact.riding or contact.depth != 0 or !contact.hit.start_solid) return null;
    const floor_refused = destination[2] < request.start[2] and contact.hit.entity == c.ENTITYNUM_WORLD;
    if (!contact.initial_overlap and !floor_refused) return null;
    return service.separate(request, 18);
}
fn riderGround(world: *data.World, entity: ecs.Entity) ?i32 {
    // Nonblocking corpses do not obstruct a solid mover. Trying to
    // push a corpse trapped against the world can otherwise hold a train
    // forever: further crush damage cannot kill it a second time.
    if (world.get(entity, data.Body)) |body| {
        if (body.contents & c.CONTENTS_CORPSE != 0 and body.contents & c.MASK_PLAYERSOLID == 0) return null;
    } else |_| {}
    if (world.get(entity, data.Player)) |player| {
        if (player.mode == .noclip or player.mode == .spectator) return null;
        return player.ground_entity;
    } else |_| {}
    if (world.get(entity, data.Performer)) |performer| return performer.ground_entity else |_| {}
    if (world.get(entity, data.Actor)) |actor| return actor.ground_entity else |_| {}
    return null;
}
const Transaction = struct {
    world: *data.World,
    slots: *const Slots,
    projections: []abi.EntityProjection,
    saved: *[ecs.max_entities]Backup,
    count: *usize,
    seen: *[ecs.max_entities]bool,
    fn pushBody(self: *Transaction, slot: u16, wanted: v.Vec3, riding: bool, yaw_delta: i32, depth: usize, mover_slot: u16, initial_overlap: bool) anyerror!?ecs.Entity {
        const entity = self.slots.occupants[slot].?;
        if (self.seen[slot] or depth >= 32) return entity;
        const other = &self.projections[slot];
        const old = other.shared.currentOrigin;
        const mask = (try self.world.get(entity, data.Body)).collision_mask;
        const record = self.count.*;
        self.saved[record] = .{ .slot = slot, .origin = old, .angles = other.shared.currentAngles, .ground = other.state.groundEntityNum, .yaw_delta = yaw_delta };
        self.count.* += 1;
        self.seen[slot] = true;
        // A body staged by this transaction must not block the next body in
        // its own contact chain. All participants are restored on refusal.
        engine.unlink(other);
        var linked = false;
        defer if (!linked) engine.link(other);
        const collision = engine.collisionService();
        var destination = wanted;
        var hit = try collision.trace(.{ .start = destination, .end = destination, .mins = other.shared.mins, .maxs = other.shared.maxs, .slot = slot, .mask = mask });
        // An authored non-rider can already straddle a retracted brush.
        // Translating it with a descending leaf pushes its feet into the
        // stationary floor and prevents either body from ever escaping.
        // A new descending contact can meet the same floor constraint. Give
        // that non-rider a bounded side escape too, checked against every live
        // collider. Riders and new horizontal pushes keep their swept refusal.
        if (try recoverContact(collision, .{ .start = old, .end = old, .mins = other.shared.mins, .maxs = other.shared.maxs, .slot = slot, .mask = mask }, destination, .{ .riding = riding, .depth = depth, .initial_overlap = initial_overlap, .hit = hit })) |contact| {
            destination = contact.end;
            self.saved[record].yaw_delta = 0;
            hit = try collision.trace(.{ .start = destination, .end = destination, .mins = other.shared.mins, .maxs = other.shared.maxs, .slot = slot, .mask = mask });
        }
        for (0..32) |_| {
            if (!hit.start_solid) break;
            // The leaf rotates while the pushed hull remains axis-aligned.
            // Resolve only a small real contact overlap, without an impulse.
            // Find the brush plane independently of neighbouring bodies.
            // Their overlap is resolved by the same transaction below; a
            // touching crowd must not hide a shallow wall contact's normal.
            const request: @import("../../core/domain/collision.zig").Request = .{ .start = destination, .end = destination, .mins = other.shared.mins, .maxs = other.shared.maxs, .slot = slot, .mask = mask };
            var brushes = request;
            brushes.mask &= ~@as(u32, c.CONTENTS_BODY);
            if (try collision.separate(request, 2) orelse try collision.separate(brushes, 2)) |contact| {
                destination = contact.end;
                hit = try collision.trace(.{ .start = destination, .end = destination, .mins = other.shared.mins, .maxs = other.shared.maxs, .slot = slot, .mask = mask });
                if (!hit.start_solid) break;
            }
            if (depth == 0) {
                const remains = try collision.trace(.{ .start = old, .end = old, .mins = other.shared.mins, .maxs = other.shared.maxs, .slot = slot, .mask = mask });
                if (!remains.start_solid) {
                    destination = old;
                    self.saved[record].yaw_delta = 0;
                    other.state.groundEntityNum = c.ENTITYNUM_NONE;
                    hit = remains;
                    break;
                }
            }
            if (hit.entity >= self.slots.occupants.len or self.seen[hit.entity]) break;
            const neighbour = self.slots.occupants[hit.entity] orelse break;
            if (riderGround(self.world, neighbour) == null) break;
            const body = self.world.get(neighbour, data.Body) catch break;
            if (body.contents & c.CONTENTS_BODY == 0) break;
            const next = v.add(self.projections[hit.entity].shared.currentOrigin, v.subtract(destination, old));
            if (try self.pushBody(hit.entity, next, false, 0, depth + 1, mover_slot, false)) |blocker| return blocker;
            if (engine.integer("developer") >= 2) {
                var text: [160]u8 = undefined;
                engine.print(try std.fmt.bufPrintZ(&text, "zig push chain mover={d} body={d} neighbour={d} depth={d}\n", .{ mover_slot, slot, hit.entity, depth + 1 }));
            }
            hit = try collision.trace(.{ .start = destination, .end = destination, .mins = other.shared.mins, .maxs = other.shared.maxs, .slot = slot, .mask = mask });
        }
        if (hit.start_solid) {
            if (engine.integer("developer") > 1) {
                var message: [256]u8 = undefined;
                engine.print(try std.fmt.bufPrintZ(&message, "zig push blocked mover={d} rider={d} grounded={any} hit={d} old={d:.2},{d:.2},{d:.2} new={d:.2},{d:.2},{d:.2}\n", .{ mover_slot, slot, riding, hit.entity, old[0], old[1], old[2], destination[0], destination[1], destination[2] }));
            }
            return entity;
        }
        other.shared.currentOrigin = destination;
        if (!riding) other.state.groundEntityNum = c.ENTITYNUM_NONE;
        engine.link(other);
        linked = true;
        return null;
    }
};
fn pushProjected(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, moves: []const Move) !?ecs.Entity {
    var saved: [ecs.max_entities]Backup = undefined;
    var count: usize = 0;
    var seen: [ecs.max_entities]bool = @splat(false);
    var transaction: Transaction = .{ .world = world, .slots = slots, .projections = projections, .saved = &saved, .count = &count, .seen = &seen };
    var committed = false;
    defer if (!committed) {
        for (saved[0..count]) |before| {
            const projection = &projections[before.slot];
            projection.shared.currentOrigin = before.origin;
            projection.shared.currentAngles = before.angles;
            projection.state.groundEntityNum = before.ground;
            engine.link(projection);
        }
    };
    // Move all brush parts before testing riders against the new assembly.
    for (moves) |move| {
        const slot = (try world.get(move.entity, data.Binding)).slot;
        if (seen[slot]) return error.DuplicateMoverPart;
        seen[slot] = true;
        const projection = &projections[slot];
        saved[count] = .{ .slot = slot, .origin = projection.shared.currentOrigin, .angles = projection.shared.currentAngles, .ground = projection.state.groundEntityNum };
        count += 1;
        projection.shared.currentOrigin = move.destination.position;
        projection.shared.currentAngles = move.destination.angles;
        engine.link(projection);
    }
    for (moves, 0..) |move, part_index| {
        const before = saved[part_index];
        const projection = &projections[before.slot];
        const translation = v.add(move.destination.position, v.scale(before.origin, -1));
        const rotation = v.add(move.destination.angles, v.scale(before.angles, -1));
        if (v.dot(translation, translation) + v.dot(rotation, rotation) == 0) continue;
        const axes = v.basis(rotation);
        const up = v.cross(axes.right, axes.forward);
        // Engine slots give stable iteration order; includes riders outside swept bounds.
        for (slots.occupants, 0..) |occupant, index| {
            const entity = occupant orelse continue;
            if (seen[index]) continue;
            const ground = riderGround(world, entity) orelse continue;
            // Every rider keeps its own clip policy. Applying player-only
            // clip walls to a creature or NPC can hold an otherwise legal
            // physical push indefinitely.
            const other = &projections[index];
            const riding = ground == before.slot;
            var initial_overlap = false;
            if (!riding) {
                var intersects = true;
                for (0..3) |axis| if (other.shared.absmin[axis] >= projection.shared.absmax[axis] or other.shared.absmax[axis] <= projection.shared.absmin[axis]) {
                    intersects = false;
                    break;
                };
                if (!intersects) continue;
                // Rotating brushes have conservative spherical world bounds.
                // An overlap with another actor inside those bounds is not
                // evidence of contact with this moving leaf.
                if (!engine.entityContact(projection, v.add(other.shared.currentOrigin, other.shared.mins), v.add(other.shared.currentOrigin, other.shared.maxs))) continue;
                var previous = projection.*;
                previous.shared.currentOrigin = before.origin;
                previous.shared.currentAngles = before.angles;
                initial_overlap = engine.entityContact(&previous, v.add(other.shared.currentOrigin, other.shared.mins), v.add(other.shared.currentOrigin, other.shared.maxs));
            }
            const old = other.shared.currentOrigin;
            const offset = v.add(old, v.scale(before.origin, -1));
            const rotated = v.add(v.add(v.scale(axes.forward, offset[0]), v.scale(axes.right, -offset[1])), v.scale(up, offset[2]));
            const destination = v.add(v.add(old, translation), v.add(rotated, v.scale(offset, -1)));
            if (try transaction.pushBody(@intCast(index), destination, riding, @intFromFloat(rotation[1] * 65536 / 360), 0, before.slot, initial_overlap)) |blocker| return blocker;
        }
    }
    for (saved[0..count]) |before| {
        const entity = slots.occupants[before.slot].?;
        const projection = &projections[before.slot];
        (try world.get(entity, data.Transform)).* = .{ .position = projection.shared.currentOrigin, .angles = projection.shared.currentAngles };
        if (world.get(entity, data.Player)) |player| {
            player.ground_entity = @intCast(projection.state.groundEntityNum);
            player.delta_angles[1] +%= before.yaw_delta;
        } else |_| if (world.get(entity, data.Actor)) |actor| {
            actor.ground_entity = @intCast(projection.state.groundEntityNum);
        } else |_| {}
        if (world.get(entity, data.Performer)) |performer| {
            performer.ground_entity = @intCast(projection.state.groundEntityNum);
        } else |_| {}
    }
    committed = true;
    return null;
}
test "a new descending non-rider contact escapes sideways when the floor refuses its push" {
    const collision = @import("../../core/domain/collision.zig");
    const Corner = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            if (request.start[0] < 9 or request.start[2] < 10) return .{ .fraction = 0, .end = request.start, .normal = @splat(0), .start_solid = true, .all_solid = true };
            if (request.end[0] >= 9) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = (request.start[0] - 9) / (request.start[0] - request.end[0]);
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 1, 0, 0 } };
        }
    };
    var raw: u8 = 0;
    const service: collision.Collision = .{ .context = &raw, .trace_fn = Corner.trace };
    var request: collision.Request = .{ .start = .{ 0, 0, 10 }, .end = .{ 0, 0, 10 }, .mins = @splat(0), .maxs = @splat(0), .slot = 0, .mask = 1 };
    const refused: collision.Trace = .{ .fraction = 0, .end = .{ 0, 0, -1 }, .normal = @splat(0), .entity = c.ENTITYNUM_WORLD, .start_solid = true };
    const context: Contact = .{ .riding = false, .depth = 0, .initial_overlap = false, .hit = refused };
    const escaped = (try recoverContact(service, request, .{ 0, 0, -1 }, context)).?;
    try std.testing.expect(escaped.end[0] >= 9);
    try std.testing.expectApproxEqAbs(@as(f32, 10), escaped.end[2], 0.001);
    try std.testing.expect(v.length(v.subtract(escaped.end, request.start)) <= 18);
    var rider = context;
    rider.riding = true;
    try std.testing.expectEqual(@as(?collision.Trace, null), try recoverContact(service, request, .{ 0, 0, -1 }, rider));
    try std.testing.expectEqual(@as(?collision.Trace, null), try recoverContact(service, request, .{ -1, 0, 10 }, context));
    request.start[0] = -30;
    request.end = request.start;
    try std.testing.expectEqual(@as(?collision.Trace, null), try recoverContact(service, request, .{ -30, 0, -1 }, context));
}
test "spawned and borrowed cinematic performers participate in mover riding" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    const performer: data.Performer = .{ .unique = "charonferry", .classname = "cine_charon", .model = "models/cinematic/c_char_e2m2.dkm", .ground_entity = 17 };
    const spawned = try world.create(1, .{ performer, data.Body{ .contents = 0 } });
    const borrowed = try world.create(2, .{ performer, data.Body{ .contents = 0 }, data.Actor{ .definition = 0, .ground_entity = 2047 } });
    try std.testing.expectEqual(@as(?i32, 17), riderGround(&world, spawned));
    try std.testing.expectEqual(@as(?i32, 17), riderGround(&world, borrowed));
}
test "nonblocking remains cannot stall solid movers" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    const entity = try world.create(1, .{ data.Actor{ .definition = 0, .ground_entity = 17 }, data.Body{ .contents = c.CONTENTS_CORPSE } });
    try std.testing.expectEqual(@as(?i32, null), riderGround(&world, entity));
    (try world.get(entity, data.Body)).contents = c.CONTENTS_BODY;
    try std.testing.expectEqual(@as(?i32, 17), riderGround(&world, entity));
}

pub fn publishAssembly(world: *data.World, projections: []abi.EntityProjection, assembly: *const @import("attachments.zig").Assembly) anyerror!void {
    for (assembly.parts[0..assembly.count]) |part| {
        const binding = world.get(part.entity, data.Binding) catch continue;
        if (!try publishMoverPart(world, part.entity, projections)) {
            const projection = &projections[binding.slot];
            const transform = (try world.get(part.entity, data.Transform)).*;
            projection.shared.currentOrigin = transform.position;
            const object = world.get(part.entity, data.MapObject) catch null;
            projection.shared.currentAngles = if (object) |value| @import("brushes.zig").collisionAngles(value.classname, transform.angles) else transform.angles;
            projection.state.pos.trType = c.TR_STATIONARY;
            projection.state.pos.trBase = transform.position;
            projection.state.apos.trType = c.TR_STATIONARY;
            projection.state.apos.trBase = transform.angles;
            engine.link(projection);
        }
    }
}
/// What a refused commit does to the assembly's own travel clock, chosen by the class
/// whose parts are moving. Held travel resumes from where the brush stopped once the way
/// clears, which is what a door owes an actor standing in its sweep. Running travel keeps
/// the authored timing anyway, so a mover whose travel cannot complete still arrives when
/// its motion says it does and delivers its arrival - a press does not have to reach the
/// bottom of its travel to have been pressed.
pub const Travel = enum { held, running };
/// An idle mobile flyer must not remain indefinitely in a moving brush's
/// pinch point. Select a clear local stroke; its class still owns locomotion.
fn requestYield(world: *data.World, projections: []abi.EntityProjection, blocker: ecs.Entity, moves: []const Move, now: i64) !void {
    const actor = world.get(blocker, data.Actor) catch return;
    if (actor.mode == .dead or actor.threat != 0 or now < actor.yield_until_ms) return;
    const object = world.get(blocker, data.MapObject) catch return;
    if (!@import("actor_catalog").spawnflags.moves(object.flags)) return;
    const kind = @import("actor_catalog").entries[actor.definition].kind;
    if (!@import("actor_classes/registry.zig").routes(kind).air) return;
    if (world.get(blocker, data.Script) catch null) |script| if (script.active) return;
    const body = (try world.get(blocker, data.Body)).*;
    if (body.motion_owner != null) return;
    const pose = (try world.get(blocker, data.Transform)).position;
    const slot = (try world.get(blocker, data.Binding)).slot;
    const service = engine.collisionService();
    var start = pose;
    if (try service.separate(.{ .start = pose, .end = pose, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask }, 1)) |contact| start = contact.end;
    var source: v.Vec3 = @splat(0);
    var nearest = std.math.inf(f32);
    for (moves) |move| {
        const brush = &projections[(try world.get(move.entity, data.Binding)).slot];
        const centre = v.scale(v.add(brush.shared.absmin, brush.shared.absmax), 0.5);
        const distance = v.length(v.subtract(centre, pose));
        if (distance < nearest) {
            source = centre;
            nearest = distance;
        }
    }
    var best: ?v.Vec3 = null;
    var clearance: f32 = nearest + 16;
    for ([_]f32{ 64, 128 }) |radius| for (0..10) |heading| {
        const angle = @as(f32, @floatFromInt(heading)) * std.math.pi / 4;
        const point = v.add(start, if (heading < 8) v.Vec3{ @cos(angle) * radius, @sin(angle) * radius, 0 } else v.Vec3{ 0, 0, if (heading == 8) radius else -radius });
        const trace = try service.trace(.{ .start = start, .end = point, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask });
        if (engine.integer("developer") >= 3 and @mod(now, 500) == 0) {
            var text: [192]u8 = undefined;
            engine.print(try std.fmt.bufPrintZ(&text, "zig yield probe actor={d} heading={d} radius={d} start={d} all={d} fraction={d:.2} hit={d}\n", .{ try world.persistentId(blocker), heading, radius, @intFromBool(trace.start_solid), @intFromBool(trace.all_solid), trace.fraction, trace.entity }));
        }
        if (trace.start_solid or trace.all_solid or v.length(v.subtract(trace.end, pose)) < 24) continue;
        // Stop inside the clear corridor, rather than asking the route graph
        // to reach an endpoint exactly on the obstruction's clipping plane.
        const safe = v.add(trace.end, v.scale(v.normalize(v.subtract(start, trace.end)), 1));
        const lane = try service.trace(.{ .start = start, .end = safe, .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask });
        if (lane.start_solid or lane.all_solid or lane.fraction < 1) continue;
        if (try service.contents(safe, slot) & (c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_WATER) != 0) continue;
        const distance = v.length(v.subtract(safe, source));
        if (distance > clearance) {
            best = safe;
            clearance = distance;
        }
    };
    if (best) |point| {
        actor.yield_point = point;
        actor.yield_until_ms = now + 2000;
        if (engine.integer("developer") >= 2) {
            var text: [192]u8 = undefined;
            engine.print(try std.fmt.bufPrintZ(&text, "zig mover yield actor={d} point={d:.2},{d:.2},{d:.2}\n", .{ try world.persistentId(blocker), point[0], point[1], point[2] }));
        }
    }
}
pub fn push(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, moves: []const Move, now: i64, elapsed: u32, travel: Travel) anyerror!?ecs.Entity {
    var assembly = try @import("attachments.zig").prepare(world, moves, now, true);
    var projected: [ecs.max_entities]Move = undefined;
    var count: usize = 0;
    for (assembly.parts[0..assembly.count]) |part| {
        _ = world.get(part.entity, data.Binding) catch continue;
        projected[count] = .{ .entity = part.entity, .destination = part.after };
        count += 1;
    }
    try @import("item_support.zig").bind(world, projections, projected[0..count]);
    if (try pushProjected(world, slots, projections, projected[0..count])) |blocker| {
        try requestYield(world, projections, blocker, moves, now);
        if (travel == .held) try assembly.delay(world, elapsed);
        try publishAssembly(world, projections, &assembly);
        return blocker;
    }
    try assembly.commit(world);
    try publishAssembly(world, projections, &assembly);
    return null;
}
pub fn teleport(world: *data.World, projections: []abi.EntityProjection, entity: ecs.Entity, destination: data.Vec3, now: i64) anyerror!void {
    var transform = (try world.get(entity, data.Transform)).*;
    transform.position = destination;
    var assembly = try @import("attachments.zig").prepare(world, &.{.{ .entity = entity, .destination = transform }}, now, false);
    try assembly.commit(world);
    try publishAssembly(world, projections, &assembly);
}

/// Static brush parents can still own animated children.
pub fn staticRoots(world: *data.World, slots: *const Slots, projections: []abi.EntityProjection, now: i64, elapsed: u32) !void {
    var roots: [ecs.max_entities]bool = @splat(false);
    var query = world.queryAccess(data.World.mask(.{data.Attachment}), 0, 0);
    {
        defer query.deinit();
        while (query.next()) |view| for (view.read(data.Attachment)) |attachment| {
            var parent = world.find(attachment.parent_id) orelse continue;
            for (0..ecs.max_entities) |_| {
                const next = world.get(parent, data.Attachment) catch break;
                parent = world.find(next.parent_id) orelse break;
            } else return error.CyclicAttachment;
            if (@import("platforms.zig").isMoverPart(world, parent)) continue;
            const slot = slots.find(parent) orelse continue;
            roots[slot] = true;
        };
    }
    for (roots, 0..) |enabled, slot| if (enabled) {
        const entity = slots.occupants[slot].?;
        const destination = (try world.get(entity, data.Transform)).*;
        _ = try push(world, slots, projections, &.{.{ .entity = entity, .destination = destination }}, now, elapsed, .held);
    };
}
/// Publishes a part through the brush mover class owning it; false when none does.
fn publishMoverPart(world: *data.World, entity: @import("../../core/ecs/world.zig").Entity, projections: []abi.EntityProjection) !bool {
    inline for (@import("../../game/server/world_system_classes.zig").motion) |Class| if (@hasDecl(Class, "publishPart")) {
        if (try Class.publishPart(world, entity, projections)) return true;
    };
    return false;
}
