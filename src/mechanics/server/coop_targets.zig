// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Resolves co-op route selectors to authored world entities and their physical
//! extents. Read-only: selection never creates, moves or activates anything.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const c = abi.c;
const v = @import("../../core/domain/vector.zig");
const route = @import("../domain/coop_route.zig");
const catalog = @import("actor_catalog");
const Frame = @import("coop_motor.zig").Frame;
pub const Filter = enum { any, pickup, actor, hostile, mover, exit };
pub const Resolved = struct {
    entity: ?ecs.Entity = null,
    id: u32 = 0,
    /// Origin for point entities, box centre for brush entities.
    point: v.Vec3,
    mins: v.Vec3,
    maxs: v.Vec3,
    slot: ?u16 = null,
    brush: bool = false,
};
pub fn resolve(frame: Frame, target: route.Target, filter: Filter) !?Resolved {
    if (target.entityless()) return .{ .point = target.point.?, .mins = target.point.?, .maxs = target.point.? };
    const world = frame.world;
    if (target.id != 0 or target.index != 0) {
        const id = if (target.id != 0) target.id else namespace(world) | target.index;
        const entity = world.find(id) orelse return null;
        if (!try accepts(world, entity, filter, true)) return null;
        return try describe(frame, entity);
    }
    const origin = target.near orelse (try world.get(frame.entity, data.Transform)).position;
    var best: ?Resolved = null;
    var nearest: f32 = std.math.inf(f32);
    var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Transform }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, object| {
        if (!target.name.empty() and !std.mem.eql(u8, object.targetname, target.name.slice())) continue;
        if (!target.class.empty() and !std.mem.eql(u8, object.classname, target.class.slice())) continue;
        if (!try accepts(world, entity, filter, !target.name.empty())) continue;
        const candidate = try describe(frame, entity);
        const distance = v.length(v.subtract(candidate.point, origin));
        if (distance >= nearest) continue;
        nearest = distance;
        best = candidate;
    };
    return best;
}
/// Authored entities keep the birth namespace of their map, which survives
/// restoration; stationary exits identify it independently of admission order.
pub fn namespace(world: *data.World) u32 {
    var query = world.queryAccess(data.World.mask(.{ data.Exit, data.MapObject }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities()) |entity| return (world.persistentId(entity) catch continue) & 0xff000000;
    return world.id_first & 0xff000000;
}
fn accepts(world: *data.World, entity: ecs.Entity, filter: Filter, named: bool) !bool {
    return switch (filter) {
        .any => true,
        .pickup => if (world.get(entity, data.Pickup) catch null) |pickup| pickup.visible else false,
        .actor, .hostile => blk: {
            const actor = world.get(entity, data.Actor) catch break :blk false;
            const health = world.get(entity, data.Health) catch break :blk false;
            if (health.current <= 0) break :blk false;
            // An explicitly named actor is a valid target whatever its class.
            break :blk filter == .actor or named or route.hostile(catalog.entries[actor.definition].kind);
        },
        .mover => @import("platforms.zig").isMoverPart(world, entity),
        .exit => (world.get(entity, data.Exit) catch null) != null,
    };
}
pub fn describe(frame: Frame, entity: ecs.Entity) !Resolved {
    const world = frame.world;
    const pose = (try world.get(entity, data.Transform)).*;
    var result: Resolved = .{ .entity = entity, .id = try world.persistentId(entity), .point = pose.position, .mins = pose.position, .maxs = pose.position };
    if (world.get(entity, data.Body) catch null) |body| {
        result.mins = v.add(pose.position, body.mins);
        result.maxs = v.add(pose.position, body.maxs);
    }
    if (world.get(entity, data.Binding) catch null) |binding| if (binding.slot < frame.projections.len) {
        const shared = frame.projections[binding.slot].shared;
        result.slot = binding.slot;
        // A shot-only authored volume can use a runtime box instead of its
        // trigger-textured inline collision model. Its pose is still the brush
        // origin; aim at its physical centre rather than that editor origin.
        const inline_volume = if (world.get(entity, data.MapObject) catch null) |object| object.model.len > 1 and object.model[0] == '*' else false;
        // Pickup bounds can be far above or below their model origin. Their
        // navigation helper applies that offset once; replacing the origin
        // with the box centre here applies it twice and selects another floor.
        const pickup = (world.get(entity, data.Pickup) catch null) != null;
        if (shared.linked != 0 and (inline_volume or shared.bmodel != 0 or (shared.contents & c.CONTENTS_TRIGGER != 0 and !pickup))) {
            const physical = try @import("bot_routes.zig").bodyBounds(world, entity);
            result.mins = physical.mins;
            result.maxs = physical.maxs;
            result.point = try @import("bot_routes.zig").center(world, entity);
            result.brush = true;
        }
    };
    return result;
}
/// The collector stands above the pickup's physical support plane. A model
/// origin embedded in its floor is not itself an actor navigation destination.
pub fn pickupPoint(frame: Frame, found: Resolved) !?v.Vec3 {
    const entity = found.entity orelse return null;
    _ = frame.world.get(entity, data.Pickup) catch return null;
    const body = try frame.world.get(entity, data.Body);
    const pose = try frame.world.get(entity, data.Transform);
    const collector = try frame.world.get(frame.entity, data.Body);
    return @import("../../core/domain/navigation_input.zig").pickupPoint(pose.position, body.mins, collector.mins);
}
test "pickup selectors retain model origins while trigger volumes retain physical centres" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    const pose: data.Transform = .{ .position = .{ -1808, -128, -1608 } };
    const body: data.Body = .{ .mins = .{ -7, -12, -24 }, .maxs = .{ 7, 11, -10 } };
    const pickup = try world.create(10, .{ pose, body, data.Pickup{ .kind = .{ .health = 50 } }, data.Binding{ .slot = 1 } });
    const trigger = try world.create(11, .{ pose, body, data.Binding{ .slot = 2 } });
    const collector = try world.create(12, .{data.Body{ .mins = .{ -15, -15, -24 }, .maxs = .{ 15, 15, 32 } }});
    var projections = std.mem.zeroes([3]abi.EntityProjection);
    for (projections[1..]) |*projection| {
        projection.shared.linked = 1;
        projection.shared.contents = c.CONTENTS_TRIGGER;
    }
    var slots: @import("../../engine/slots.zig").Slots = .{};
    const frame: Frame = .{ .world = &world, .slots = &slots, .projections = &projections, .clients = undefined, .service = undefined, .index = 0, .entity = collector, .now = 0 };
    const item = try describe(frame, pickup);
    try std.testing.expect(!item.brush);
    try std.testing.expectEqual(pose.position, item.point);
    try std.testing.expectEqual(@as(f32, -1608), @import("../../core/domain/navigation_input.zig").pickupPoint(item.point, body.mins, .{ -15, -15, -24 })[2]);
    try std.testing.expectEqual(@as(?v.Vec3, pose.position), try pickupPoint(frame, item));
    (try world.get(pickup, data.Transform)).position = .{ 0, 0, 10 };
    (try world.get(pickup, data.Body)).mins[2] = -10;
    try std.testing.expectEqual(@as(?v.Vec3, .{ 0, 0, 24 }), try pickupPoint(frame, try describe(frame, pickup)));
    const volume = try describe(frame, trigger);
    try std.testing.expect(volume.brush);
    try std.testing.expectEqual(v.scale(v.add(volume.mins, volume.maxs), 0.5), volume.point);
}
/// Observable authored state; a change means a control, trigger or target reacted.
/// Moving now: binary movers (doors, plats) or path trains (lifts, carts).
pub fn moving(world: *data.World, entity: ecs.Entity) bool {
    return @import("platforms.zig").isMoving(world, entity);
}
test "rotating brush parts remain valid landing surfaces while their motion toggles" {
    var world = data.World.init(std.testing.allocator, 2);
    defer world.deinit();
    const entity = try world.create(1, .{ data.Transform{}, data.Rotation{ .base = @splat(0), .rate = .{ 25, 0, 0 }, .active = true } });
    try std.testing.expect(try accepts(&world, entity, .mover, true));
    try std.testing.expect(moving(&world, entity));
    const predicted = try @import("platforms.zig").sample(&world, entity, 1000);
    try std.testing.expectApproxEqAbs(@as(f32, 25), predicted.angles[0], 0.001);
    try std.testing.expectEqual(v.Vec3{ 0, 0, 0 }, (try world.get(entity, data.Transform)).angles);
    (try world.get(entity, data.Rotation)).active = false;
    try std.testing.expect(try accepts(&world, entity, .mover, true));
    try std.testing.expect(!moving(&world, entity));
}
/// "closed"/"opening"/"open"/"closing" for movers, the phase name for trains.
pub fn moverState(world: *data.World, entity: ecs.Entity) ?[]const u8 {
    if (world.get(entity, data.Mover) catch null) |mover| return @tagName(mover.state);
    if (@import("platforms.zig").pathPhase(world, entity)) |phase| return phase.name;
    return null;
}
pub fn signature(world: *data.World, id: u32) u64 {
    const entity = world.find(id) orelse return 0;
    var hash = std.hash.Wyhash.init(1);
    if (world.get(entity, data.Mover) catch null) |mover| {
        // Automatic arrival/return is not a response to this action. The
        // group master records accepted presses, including renewed holds.
        const master = world.find(mover.group) orelse entity;
        const accepted = world.get(master, data.Mover) catch mover;
        hash.update(std.mem.asBytes(&accepted.uses));
    }
    if (@import("platforms.zig").pathPhase(world, entity)) |phase| hash.update(phase.name);
    if (world.get(entity, data.Trigger) catch null) |trigger| hash.update(std.mem.asBytes(&trigger.uses));
    if (world.get(entity, data.WorldControl) catch null) |control| hash.update(std.mem.asBytes(&control.uses));
    if (world.get(entity, data.Health) catch null) |health| hash.update(std.mem.asBytes(&health.current));
    if (world.get(entity, data.Pickup) catch null) |pickup| hash.update(std.mem.asBytes(&pickup.visible));
    if (world.get(entity, data.Exit) catch null) |exit| hash.update(std.mem.asBytes(&exit.latched));
    inline for (@import("../../game/server/world_system_classes.zig").observables) |Class| if (Class.observed(world, entity)) |count| hash.update(std.mem.asBytes(&count.value));
    return hash.final() | 1;
}

test "a timed control's renewed hold changes its observable reaction" {
    var world = data.World.init(std.testing.allocator, 1);
    defer world.deinit();
    const entity = try world.create(7, .{data.Mover{ .closed = @splat(0), .opened = @splat(0), .motion = .{}, .state = .open, .wait_ms = 2000 }});
    const initial = signature(&world, 7);
    const mover = try world.get(entity, data.Mover);
    try std.testing.expectEqual(null, try mover.use(1000, 1));
    try std.testing.expectEqual(@as(?i64, 3001), mover.return_at.at_ms);
    const renewed = signature(&world, 7);
    try std.testing.expect(initial != renewed);
    try std.testing.expectEqual(renewed, signature(&world, 7));
    _ = try mover.use(1500, 1);
    try std.testing.expect(renewed != signature(&world, 7));
}
test "automatic return is not a press and a grouped leaf observes its master's accepted use" {
    var world = data.World.init(std.testing.allocator, 2);
    defer world.deinit();
    const master = try world.create(7, .{data.Mover{ .closed = @splat(0), .opened = .{ 0, 0, 64 }, .motion = .{}, .state = .open, .wait_ms = 2000 }});
    _ = try world.create(8, .{data.Mover{ .closed = @splat(0), .opened = .{ 0, 0, 64 }, .motion = .{}, .group = 7 }});
    const before = signature(&world, 8);
    const mover = try world.get(master, data.Mover);
    mover.start(false, mover.opened, 1000, 500, false);
    try std.testing.expectEqual(before, signature(&world, 8));
    _ = try mover.reached(1500, true);
    try std.testing.expectEqual(before, signature(&world, 8));
    try std.testing.expectEqual(@as(?bool, true), try mover.use(1600, 1));
    try std.testing.expect(before != signature(&world, 8));
    mover.start(true, mover.closed, 1600, 500, false);
    const opening = signature(&world, 8);
    try std.testing.expectEqual(null, try mover.use(1700, 1));
    try std.testing.expectEqual(opening, signature(&world, 8));
}
