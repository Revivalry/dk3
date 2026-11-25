// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Combat sweeps through hash-qualified corridor brushes. Landing travel and
//! cinematic cuts cannot become portals. Dynamic solids remain map-owned.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const collision = @import("../../core/domain/collision.zig");
const walk = @import("../../core/domain/portal_trace.zig");
const access = @import("region_access.zig");
const engine = @import("../../engine/server.zig");
const worlds = @import("../../engine/worlds.zig");
const c = @import("../../engine/abi.zig").c;
const v = @import("../../core/domain/vector.zig");

const Backend = struct {
    skip: u32,
    pub fn local(self: Backend, owner: u32, request: collision.Request) !collision.Trace {
        const context = access.byHandle(@enumFromInt(owner)) orelse return error.TraceWorldUnavailable;
        const scope = try context.select();
        defer scope.deinit();
        var selected = request;
        selected.slot = skipSlot(&context.world.?, &context.slots, self.skip);
        return engine.collisionService().trace(selected);
    }
    pub fn crossing(_: Backend, owner: u32, request: collision.Request, visited: *const [256]bool) !?walk.Crossing {
        const region = access.region orelse return null;
        const context = access.byHandle(@enumFromInt(owner)) orelse return error.TraceWorldUnavailable;
        const map = region.manifest.find(std.mem.sliceTo(&context.map_name, 0)) orelse return null;
        var nearest: ?walk.Crossing = null;
        for (region.manifest.edges[0..region.manifest.edge_count], 0..) |edge, index| {
            if (visited[index] or edge.source != map or edge.kind != .identity) continue;
            if ((request.end[edge.axis] - request.start[edge.axis]) * @as(f32, @floatFromInt(edge.direction)) <= 0) continue;
            const destination = access.byMap(edge.destination) orelse return error.SeamWorldNotAdmitted;
            const id = (context.world.?.id_first & 0xff000000) | @as(u32, edge.exit);
            const exit = context.world.?.find(id) orelse return error.SeamExitMissing;
            const binding = try context.world.?.get(exit, data.Binding);
            const position = (try context.world.?.get(exit, data.Transform)).position;
            // Trigger angles are behavioral, not BSP rotation (brushes.zig).
            const hit = try worlds.trace(context.handle.?, v.subtract(request.start, position), v.subtract(request.end, position), request.mins, request.maxs, binding.model, -1);
            const fraction: f32 = if (hit.startsolid != 0) 0 else hit.fraction;
            if (fraction >= 1 or (nearest != null and nearest.?.fraction <= fraction)) continue;
            nearest = .{ .fraction = fraction, .world = @intFromEnum(destination.handle.?), .edge = @intCast(index), .source_entity = binding.slot };
        }
        return nearest;
    }
};

/// Binding is an O(1) hint, checked against the authoritative transport owner.
/// Transitional entities with no binding, or a stale hint, retain the scan.
fn skipSlot(world: *data.World, slots: *const @import("../../engine/slots.zig").Slots, identity: u32) u16 {
    const entity = world.find(identity) orelse return c.ENTITYNUM_NONE;
    if (world.get(entity, data.Binding) catch null) |binding| if (binding.slot < slots.occupants.len) {
        if (slots.occupants[binding.slot]) |occupant| if (occupant.index == entity.index and occupant.generation == entity.generation) return binding.slot;
    };
    return slots.find(entity) orelse c.ENTITYNUM_NONE;
}

test "collision skip binding hints preserve authoritative slot lookup across stale bindings" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    var slots: @import("../../engine/slots.zig").Slots = .{};
    const entity = try world.create(17, .{data.Transform{}});
    const other = try world.create(18, .{data.Transform{}});
    const slot = try slots.acquire(entity, null);
    const other_slot = try slots.acquire(other, null);
    try std.testing.expectEqual(slot, skipSlot(&world, &slots, 17));
    try world.put(entity, data.Binding{ .slot = slot });
    try std.testing.expectEqual(slot, skipSlot(&world, &slots, 17));
    (try world.get(entity, data.Binding)).slot = other_slot;
    try std.testing.expectEqual(slot, skipSlot(&world, &slots, 17));
    (try world.get(entity, data.Binding)).slot = 65535;
    try std.testing.expectEqual(slot, skipSlot(&world, &slots, 17));
    try slots.release(slot, entity);
    try std.testing.expectEqual(@as(u16, c.ENTITYNUM_NONE), skipSlot(&world, &slots, 17));
    try std.testing.expectEqual(@as(u16, c.ENTITYNUM_NONE), skipSlot(&world, &slots, 99));
}

pub fn trace(request: collision.Request) !collision.Trace {
    if (access.region == null) return engine.collisionService().trace(request);
    const handle = worlds.current();
    const context = access.byHandle(handle) orelse return engine.collisionService().trace(request);
    const skip = if (request.slot < context.slots.occupants.len) (if (context.slots.occupants[request.slot]) |entity| try context.world.?.persistentId(entity) else 0) else 0;
    return walk.trace(Backend{ .skip = skip }, @intFromEnum(handle), request);
}

/// Continue a moving controller from the owner reached by its previous segment.
/// The skipped actor remains a persistent ID, never a slot in another world.
pub fn from(owner: u32, request: collision.Request, skip: u32) !collision.Trace {
    if (owner == 0) return trace(request);
    return walk.trace(Backend{ .skip = skip }, owner, request);
}
pub fn owned(world: *data.World, request: collision.Request, skip: u32) !collision.Trace {
    const owner = access.contextFor(world) orelse return engine.collisionService().trace(request);
    return from(@intFromEnum(owner.handle.?), request, skip);
}
pub fn contents(owner: u32, point: v.Vec3, skip: u32) !u32 {
    if (owner == 0) return engine.collisionService().contents(point, c.ENTITYNUM_NONE);
    const context = access.byHandle(@enumFromInt(owner)) orelse return error.TraceWorldUnavailable;
    const scope = try context.select();
    defer scope.deinit();
    const slot: u16 = if (context.world.?.find(skip)) |entity| context.slots.find(entity) orelse c.ENTITYNUM_NONE else c.ENTITYNUM_NONE;
    return engine.collisionService().contents(point, slot);
}
pub fn reaches(local: *data.World, hit: collision.Trace, target: @import("../domain/world_references.zig").Ref) bool {
    const owner = if (hit.world == 0) local else &(access.byHandle(@enumFromInt(hit.world)) orelse return false).world.?;
    if (owner != target.world or hit.start_solid or hit.all_solid) return false;
    if (hit.fraction == 1) return true;
    const binding = target.get(data.Binding) catch return false;
    return hit.entity == binding.slot;
}

/// PVS is map-local. A straight cross-seam sightline must be in the PVS of each
/// segment's own map; prefetched maps and cinematic landings confer no visibility.
pub fn inPvs(world: *data.World, origin: v.Vec3, target: @import("../domain/world_references.zig").Ref, point: v.Vec3) !bool {
    const source = access.contextFor(world) orelse return engine.inPvs(origin, point);
    var owner = source;
    var request: collision.Request = .{ .start = origin, .end = point, .mins = @splat(0), .maxs = @splat(0), .slot = c.ENTITYNUM_NONE, .mask = 0 };
    var traversed: [256]bool = @splat(false);
    while (true) {
        const scope = try owner.select();
        defer scope.deinit();
        if (&owner.world.? == target.world) return engine.inPvs(request.start, point);
        const next = try (Backend{ .skip = 0 }).crossing(@intFromEnum(owner.handle.?), request, &traversed) orelse return false;
        const boundary = v.add(request.start, v.scale(v.subtract(point, request.start), next.fraction));
        if (!engine.inPvs(request.start, boundary)) return false;
        traversed[next.edge] = true;
        request.start = boundary;
        owner = access.byHandle(@enumFromInt(next.world)) orelse return error.TraceWorldUnavailable;
    }
}
