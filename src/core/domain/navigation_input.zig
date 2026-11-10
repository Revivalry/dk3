// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Body-space navigation goals and collision-qualified locomotion steering.
const v = @import("vector.zig");
const collision = @import("collision.zig");
/// Leave an expanded volume along the approach direction. A long lateral
/// dimension must not push a body far back through the doorway behind it.
pub fn outsidePoint(mins: v.Vec3, maxs: v.Vec3, position: v.Vec3, fallback: v.Vec3, hull_mins: v.Vec3, hull_maxs: v.Vec3, margin: f32) v.Vec3 {
    const centre = v.scale(v.add(mins, maxs), 0.5);
    var direction = v.subtract(position, centre);
    direction[2] = 0;
    if (v.length(direction) < 0.01) direction = .{ fallback[0] - centre[0], fallback[1] - centre[1], 0 };
    if (v.length(direction) < 0.01) direction = .{ -1, 0, 0 };
    direction = v.normalize(direction);
    var reach = @import("std").math.inf(f32);
    for (0..2) |axis| {
        if (@abs(direction[axis]) < 0.0001) continue;
        const edge = if (direction[axis] > 0) maxs[axis] - hull_mins[axis] + margin else mins[axis] - hull_maxs[axis] - margin;
        reach = @min(reach, (edge - centre[axis]) / direction[axis]);
    }
    var result = v.add(centre, v.scale(direction, reach));
    result[2] = position[2];
    return result;
}
test "thin trigger retreat follows its crossing axis rather than its long lateral span" {
    const testing = @import("std").testing;
    const mins: v.Vec3 = .{ 759, -1121, 943 };
    const maxs: v.Vec3 = .{ 777, -735, 1161 };
    const hull_mins: v.Vec3 = .{ -15, -15, -24 };
    const hull_maxs: v.Vec3 = .{ 15, 15, 32 };
    const west = outsidePoint(mins, maxs, .{ 768, -928, 980 }, .{ 632, -928, 952 }, hull_mins, hull_maxs, 16);
    try testing.expectEqual(v.Vec3{ 728, -928, 980 }, west);
    const east = outsidePoint(mins, maxs, .{ 780, -928, 980 }, .{ 900, -928, 952 }, hull_mins, hull_maxs, 16);
    try testing.expectEqual(v.Vec3{ 808, -928, 980 }, east);
}
/// A pickup's render/physics origin is not the collector's navigation origin.
/// Put the collector's feet on the pickup's support plane without moving the item.
pub fn pickupPoint(position: v.Vec3, pickup_mins: v.Vec3, collector_mins: v.Vec3) v.Vec3 {
    return .{ position[0], position[1], position[2] + pickup_mins[2] - collector_mins[2] };
}
/// A downward search may begin inside an overhang and leave it before finding
/// the floor. Accept that floor only if the final standing hull is actually clear.
pub const Support = struct { floor: ?collision.Trace = null, obstruction: ?u16 = null };
pub fn supportedPoint(service: collision.Collision, request: collision.Request) !Support {
    const hit = try service.trace(request);
    if (hit.all_solid) return .{ .obstruction = hit.entity };
    if (hit.fraction == 1 or hit.normal[2] < 0.7) return .{};
    if (hit.start_solid) {
        // Leaving an overhang is valid; projecting feet through a floor slab
        // onto the storey below is not. The caller can retry from a raised
        // origin when authored coordinates round into their support plane.
        if (request.maxs[2] - request.mins[2] > 1) {
            var feet = request;
            feet.end = feet.start;
            feet.maxs[2] = feet.mins[2] + 1;
            const contact = try service.trace(feet);
            if (contact.start_solid or contact.all_solid) return .{ .obstruction = contact.entity };
        }
        var stationary = request;
        stationary.start = hit.end;
        stationary.end = hit.end;
        const clearance = try service.trace(stationary);
        if (clearance.start_solid or clearance.all_solid) return .{ .obstruction = clearance.entity };
    }
    return .{ .floor = hit };
}
pub fn crouch(service: collision.Collision, position: v.Vec3, destination: v.Vec3, mins: v.Vec3, standing: v.Vec3, slot: u16, mask: u32) !bool {
    return crouchReach(service, position, destination, mins, standing, slot, mask, 32);
}
/// Match the clearance horizon to the obstruction query that requested it.
pub fn crouchReach(service: collision.Collision, position: v.Vec3, destination: v.Vec3, mins: v.Vec3, standing: v.Vec3, slot: u16, mask: u32, reach: f32) !bool {
    const delta = v.subtract(destination, position);
    const flat: v.Vec3 = .{ delta[0], delta[1], 0 };
    const end = v.add(position, v.scale(v.normalize(flat), @min(reach, v.length(flat))));
    const upright = try service.trace(.{ .start = position, .end = end, .mins = mins, .maxs = standing, .slot = slot, .mask = mask });
    if (!upright.start_solid and !upright.all_solid and upright.fraction == 1) return false;
    var low = standing;
    low[2] = 4;
    const ducked = try service.trace(.{ .start = position, .end = end, .mins = mins, .maxs = low, .slot = slot, .mask = mask });
    if (ducked.start_solid or ducked.all_solid) return false;
    if (ducked.fraction == 1) return true;
    // A low gap may start a step up (a jammed door's lower half): ducked,
    // rise by a step and go on, where a standing player could not.
    const rise = try service.trace(.{ .start = position, .end = v.add(position, .{ 0, 0, 18 }), .mins = mins, .maxs = low, .slot = slot, .mask = mask });
    if (rise.start_solid or rise.all_solid) return false;
    const lifted = rise.end;
    const across = v.add(end, .{ 0, 0, lifted[2] - position[2] });
    const stepped = try service.trace(.{ .start = lifted, .end = across, .mins = mins, .maxs = low, .slot = slot, .mask = mask });
    if (stepped.start_solid or stepped.all_solid or stepped.fraction < 1) return false;
    const tall = try service.trace(.{ .start = lifted, .end = across, .mins = mins, .maxs = standing, .slot = slot, .mask = mask });
    return tall.start_solid or tall.all_solid or tall.fraction < 1;
}

/// Qualify a short ordinary walk through an AAS gap. Every hull sweep and
/// support interval must work; a clear endpoint alone cannot authorize a route.
pub const Bounds = struct { mins: v.Vec3, maxs: v.Vec3 };
/// Keep vertical and lateral travel while removing the stride into a climbable
/// wall. Adding a negative projection doubles that inward stride instead.
pub fn climbHeading(movement: v.Vec3, normal: v.Vec3) v.Vec3 {
    var flat: v.Vec3 = .{ movement[0], movement[1], 0 };
    const into = v.dot(flat, normal);
    if (into < 0) flat = v.subtract(flat, v.scale(normal, into));
    return .{ flat[0], flat[1], movement[2] };
}
/// A deliberate step away from the surface releases the climb. Small lateral
/// corrections may still keep the body on its rungs.
pub fn leavesClimb(movement: v.Vec3, normal: v.Vec3) bool {
    return v.dot(.{ movement[0], movement[1], 0 }, normal) > 4;
}
/// Small rung alignment errors need small side commands. Normalizing them
/// into a full strafe throws the body off narrow ladders. While the view is
/// still turning toward the wall, its side axis may point away from the rungs.
pub fn climbStrafe(movement: v.Vec3, right: v.Vec3, normal: v.Vec3, magnitude: f32) f32 {
    if (@abs(v.dot(right, normal)) > 0.05) return 0;
    return @import("std").math.clamp(v.dot(movement, right) * 6, -magnitude, magnitude);
}
test "rung alignment settles small errors and waits for a tangential view axis" {
    const t = @import("std").testing;
    const normal: v.Vec3 = .{ -1, 0, 0 };
    const right: v.Vec3 = .{ 0, -1, 0 };
    try t.expectEqual(@as(f32, 0), climbStrafe(.{ 0, 0, 180 }, right, normal, 127));
    try t.expectEqual(@as(f32, 3), climbStrafe(.{ 0, -0.5, 180 }, right, normal, 127));
    try t.expectEqual(@as(f32, -127), climbStrafe(.{ 0, 100, 180 }, right, normal, 127));
    try t.expectEqual(@as(f32, 0), climbStrafe(.{ 0, -0.5, 180 }, .{ -0.5, -0.866, 0 }, normal, 127));
}
test "climb heading removes inward pressure on either wall and preserves escape and ascent" {
    const t = @import("std").testing;
    try t.expectEqual(v.Vec3{ 5, 0, 80 }, climbHeading(.{ 5, -3, 80 }, .{ 0, 1, 0 }));
    try t.expectEqual(v.Vec3{ 5, 3, 80 }, climbHeading(.{ 5, 3, 80 }, .{ 0, 1, 0 }));
    try t.expectEqual(v.Vec3{ 0, 7, 20 }, climbHeading(.{ 3, 7, 20 }, .{ -1, 0, 0 }));
    try t.expectEqual(v.Vec3{ 0, 7, -80 }, climbHeading(.{ 3, 7, -80 }, .{ -1, 0, 0 }));
    try t.expect(leavesClimb(.{ 0, 32, -24 }, .{ 0, 1, 0 }));
    try t.expect(leavesClimb(.{ -32, 0, 24 }, .{ -1, 0, 0 }));
    try t.expect(!leavesClimb(.{ 0, -32, 80 }, .{ 0, 1, 0 }));
    try t.expect(!leavesClimb(.{ 3, 7, -80 }, .{ -1, 0, 0 }));
}
pub fn walkPath(service: collision.Collision, request: collision.Request, forbidden: u32, hazards: []const Bounds) !?v.Vec3 {
    return walkPathDrop(service, request, forbidden, hazards, 18);
}
/// A caller may admit a bounded drop while escaping raised temporary footing.
/// Upward steps and every intervening collision/hazard check stay unchanged.
pub fn walkPathDrop(service: collision.Collision, request: collision.Request, forbidden: u32, hazards: []const Bounds, drop: f32) !?v.Vec3 {
    return walkPathSupported(service, request, forbidden, hazards, drop, request.mask);
}
/// A moving obstacle may block travel without being reliable footing. The
/// caller supplies the collision layers that can support the walking body.
pub fn walkPathSupported(service: collision.Collision, request: collision.Request, forbidden: u32, hazards: []const Bounds, drop: f32, support_mask: u32) !?v.Vec3 {
    const delta = v.subtract(request.end, request.start);
    const distance = @sqrt(delta[0] * delta[0] + delta[1] * delta[1]);
    if (distance > 640) return null;
    const count: usize = @max(1, @as(usize, @intFromFloat(@ceil(distance / 16))));
    var position = request.start;
    for (1..count + 1) |index| {
        var across = v.add(request.start, v.scale(delta, @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(count))));
        across[2] = position[2];
        var segment = request;
        segment.start = position;
        segment.end = across;
        const direct = try service.trace(segment);
        if (direct.start_solid or direct.all_solid) return null;
        if (direct.fraction < 1) {
            segment.end = v.add(position, .{ 0, 0, 18 });
            const up = try service.trace(segment);
            if (up.start_solid or up.all_solid or up.fraction < 1) return null;
            segment.start = segment.end;
            across[2] += 18;
            segment.end = across;
            const raised = try service.trace(segment);
            if (raised.start_solid or raised.all_solid or raised.fraction < 1) return null;
        }
        segment.start = across;
        segment.end = .{ across[0], across[1], position[2] - drop };
        segment.mask = support_mask;
        const support = (try supportedPoint(service, segment)).floor orelse return null;
        if (support.end[2] - position[2] > 18 or position[2] - support.end[2] > drop) return null;
        for (hazards) |hazard| {
            // Conservatively reject a hurt brush touching this short swept
            // interval, including the step clearance above the support plane.
            var overlaps = true;
            for (0..3) |axis| if (@max(position[axis], support.end[axis]) + request.maxs[axis] + (if (axis == 2) @as(f32, 18) else 0) <= hazard.mins[axis] or @min(position[axis], support.end[axis]) + request.mins[axis] >= hazard.maxs[axis]) {
                overlaps = false;
            };
            if (overlaps) return null;
        }
        position = support.end;
        if (try service.contents(v.add(position, .{ 0, 0, request.mins[2] + 1 }), request.slot) & forbidden != 0) return null;
    }
    return position;
}

/// Bounded local floor search for a missing area-graph corridor. Every edge
/// sweeps the actual hull and retains separate floors at the same grid column.
/// This proposes walking points only; callers still qualify their live motor.
pub fn groundDetour(service: collision.Collision, request: collision.Request, forbidden: u32, hazards: []const Bounds, points: []v.Vec3) !usize {
    return groundDetourMeasured(service, request, forbidden, hazards, points, null);
}
pub const FloorSearchStats = struct { nodes: usize = 0, expanded: usize = 0, walked: usize = 0, rejected: usize = 0, closest: f32 = @import("std").math.inf(f32) };
pub fn groundDetourMeasured(service: collision.Collision, request: collision.Request, forbidden: u32, hazards: []const Bounds, points: []v.Vec3, stats: ?*FloorSearchStats) !usize {
    return groundDetourStanceMeasured(service, request, forbidden, hazards, null, 12, points, stats);
}
/// A lower stance is supplied only by controllers that can execute it. The
/// returned floor corridor still requires qualification by their live motor.
pub fn groundDetourStanceMeasured(service: collision.Collision, request: collision.Request, forbidden: u32, hazards: []const Bounds, lowered_maxs: ?v.Vec3, arrival_radius: f32, points: []v.Vec3, stats: ?*FloorSearchStats) !usize {
    const std = @import("std");
    const radius = std.math.clamp(arrival_radius, 1, 48);
    if (v.length(v.subtract(request.end, request.start)) > 320 or points.len == 0) return 0;
    const Node = struct { point: v.Vec3, x: i16, y: i16, z: i16, previous: u16, cost: f32, closed: bool = false };
    const empty = std.math.maxInt(u16);
    var nodes: [1024]Node = undefined;
    var buckets: [4096]u16 = @splat(empty);
    const Key = struct {
        fn hash(x: i16, y: i16, z: i16) usize {
            return (@as(u32, @bitCast(@as(i32, x))) *% 73856093 ^ @as(u32, @bitCast(@as(i32, y))) *% 19349663 ^ @as(u32, @bitCast(@as(i32, z))) *% 83492791) & 4095;
        }
    };
    nodes[0] = .{ .point = request.start, .x = 0, .y = 0, .z = 0, .previous = empty, .cost = 0 };
    buckets[Key.hash(0, 0, 0)] = 0;
    var count: usize = 1;
    defer {
        if (stats) |measured| measured.nodes = count;
    }
    for (0..nodes.len) |_| {
        var selected: ?usize = null;
        var rank = std.math.inf(f32);
        for (nodes[0..count], 0..) |node, index| {
            if (node.closed) continue;
            const score = node.cost + v.length(v.subtract(node.point, request.end));
            if (score < rank) {
                selected = index;
                rank = score;
            }
        }
        const index = selected orelse return 0;
        const node = nodes[index];
        if (stats) |measured| {
            measured.expanded += 1;
            measured.closest = @min(measured.closest, v.length(v.subtract(node.point, request.end)));
        }
        nodes[index].closed = true;
        const delta = v.subtract(node.point, request.end);
        var terminal: ?v.Vec3 = null;
        // A fixed grid can miss the clear edge of a normal arrival disk,
        // especially beside a round prop. Qualify a short final connection
        // to the actual goal or a point strictly inside that same disk.
        if (@sqrt(delta[0] * delta[0] + delta[1] * delta[1]) <= 36 + radius) {
            const diagonal = radius * 0.70710677;
            for ([_][2]f32{ .{ 0, 0 }, .{ 12, 0 }, .{ -12, 0 }, .{ 0, 12 }, .{ 0, -12 }, .{ 8, 8 }, .{ 8, -8 }, .{ -8, 8 }, .{ -8, -8 }, .{ radius, 0 }, .{ -radius, 0 }, .{ 0, radius }, .{ 0, -radius }, .{ diagonal, diagonal }, .{ diagonal, -diagonal }, .{ -diagonal, diagonal }, .{ -diagonal, -diagonal } }, 0..) |offset, alternative| {
                if (alternative >= 9 and radius <= 12) break;
                var edge = request;
                edge.start = node.point;
                edge.end = v.add(request.end, .{ offset[0], offset[1], 0 });
                const floor = try searchFloorEdge(service, edge, forbidden, hazards, lowered_maxs) orelse continue;
                if (@abs(floor[2] - request.end[2]) <= 8) {
                    terminal = floor;
                    break;
                }
            }
        }
        if (terminal) |arrival| {
            var length: usize = 0;
            var cursor: u16 = @intCast(index);
            while (cursor != empty) : (cursor = nodes[cursor].previous) length += 1;
            if (length + 1 > points.len) return 0;
            points[length] = arrival;
            cursor = @intCast(index);
            var left = length;
            while (left > 0) {
                left -= 1;
                points[left] = nodes[cursor].point;
                cursor = nodes[cursor].previous;
            }
            return length + 1;
        }
        for ([_][2]i16{ .{ -1, -1 }, .{ 0, -1 }, .{ 1, -1 }, .{ -1, 0 }, .{ 1, 0 }, .{ -1, 1 }, .{ 0, 1 }, .{ 1, 1 } }) |offset| {
            const x = node.x + offset[0];
            const y = node.y + offset[1];
            if (@abs(x) > 12 or @abs(y) > 12) continue;
            var edge = request;
            edge.start = node.point;
            edge.end = .{ request.start[0] + @as(f32, @floatFromInt(x)) * 16, request.start[1] + @as(f32, @floatFromInt(y)) * 16, node.point[2] };
            const floor = try searchFloorEdge(service, edge, forbidden, hazards, lowered_maxs) orelse {
                if (stats) |measured| measured.rejected += 1;
                continue;
            };
            if (stats) |measured| measured.walked += 1;
            if (@abs(floor[2] - request.start[2]) > 256) continue;
            const z: i16 = @intFromFloat(@round((floor[2] - request.start[2]) / 8));
            const cost = node.cost + v.length(v.subtract(floor, node.point));
            var bucket = Key.hash(x, y, z);
            while (buckets[bucket] != empty) : (bucket = (bucket + 1) & 4095) {
                const other = &nodes[buckets[bucket]];
                if (other.x == x and other.y == y and other.z == z) break;
            }
            if (buckets[bucket] != empty) {
                const other = &nodes[buckets[bucket]];
                if (!other.closed and cost < other.cost) {
                    other.cost = cost;
                    other.previous = @intCast(index);
                }
            } else if (count < nodes.len) {
                buckets[bucket] = @intCast(count);
                nodes[count] = .{ .point = floor, .x = x, .y = y, .z = z, .previous = @intCast(index), .cost = cost };
                count += 1;
            }
        }
    }
    return 0;
}

fn searchFloorEdge(service: collision.Collision, request: collision.Request, forbidden: u32, hazards: []const Bounds, lowered_maxs: ?v.Vec3) !?v.Vec3 {
    if (try walkPathSupported(service, request, forbidden, hazards, 32, request.mask)) |floor| return floor;
    var lowered = request;
    lowered.maxs = lowered_maxs orelse return null;
    return walkPathSupported(service, lowered, forbidden, hazards, 32, request.mask);
}

test "floor recovery uses a lower stance only when its controller supplies one" {
    const Fixture = struct {
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            if (request.maxs[2] > 4 and @min(request.start[0], request.end[0]) < 72 and @max(request.start[0], request.end[0]) > 24)
                return .{ .fraction = 0, .end = request.start, .normal = .{ -1, 0, 0 } };
            const a = request.start[2] + request.mins[2];
            const b = request.end[2] + request.mins[2];
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
        }
    };
    var context: u8 = 0;
    const service: collision.Collision = .{ .context = &context, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents };
    const request: collision.Request = .{ .start = .{ 0, 0, 24 }, .end = .{ 96, 0, 24 }, .mins = .{ -15, -15, -24 }, .maxs = .{ 15, 15, 32 }, .slot = 0, .mask = 1 };
    var points: [128]v.Vec3 = undefined;
    try @import("std").testing.expectEqual(@as(usize, 0), try groundDetour(service, request, 0, &.{}, &points));
    try @import("std").testing.expect(try groundDetourStanceMeasured(service, request, 0, &.{}, .{ 15, 15, 4 }, 12, &points, null) > 0);
}

test "a declared wider arrival finds supported floor beside an embedded destination" {
    const Fixture = struct {
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            if (request.start[0] > 64) return .{ .fraction = 0, .end = request.start, .normal = .{ -1, 0, 0 }, .start_solid = true, .all_solid = true };
            if (request.end[0] > 64) return .{ .fraction = (64 - request.start[0]) / (request.end[0] - request.start[0]), .end = .{ 64, request.start[1], request.start[2] }, .normal = .{ -1, 0, 0 } };
            const a = request.start[2] + request.mins[2];
            const b = request.end[2] + request.mins[2];
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
        }
    };
    var context: u8 = 0;
    const service: collision.Collision = .{ .context = &context, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents };
    const request: collision.Request = .{ .start = .{ 0, 0, 24 }, .end = .{ 96, 0, 24 }, .mins = .{ -15, -15, -24 }, .maxs = .{ 15, 15, 32 }, .slot = 0, .mask = 1 };
    var points: [128]v.Vec3 = undefined;
    try @import("std").testing.expectEqual(@as(usize, 0), try groundDetour(service, request, 0, &.{}, &points));
    const count = try groundDetourStanceMeasured(service, request, 0, &.{}, null, 48, &points, null);
    try @import("std").testing.expect(count > 0);
    try @import("std").testing.expect(points[count - 1][0] <= 64 and v.length(v.subtract(points[count - 1], request.end)) <= 48.001);
}

test "bounded floor search goes around an obstruction and rejects harmful destination corridors" {
    const Fixture = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            const wall: @import("linked_routes.zig").Bounds = .{ .mins = .{ 24, -40, -32 }, .maxs = .{ 72, 40, 128 } };
            if (wall.intersects(request.start, request.end)) return .{ .fraction = 0, .end = request.start, .normal = .{ -1, 0, 0 } };
            const a = request.start[2] + request.mins[2];
            const b = request.end[2] + request.mins[2];
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 } };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var context: u8 = 0;
    const service: collision.Collision = .{ .context = &context, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents };
    var request: collision.Request = .{ .start = .{ 0, 0, 24 }, .end = .{ 128, 0, 24 }, .mins = .{ -8, -8, -24 }, .maxs = .{ 8, 8, 32 }, .slot = 0, .mask = 1 };
    var points: [128]v.Vec3 = undefined;
    const count = try groundDetour(service, request, 2, &.{}, &points);
    try @import("std").testing.expect(count > 2);
    var turned = false;
    for (points[0..count]) |point| turned = turned or @abs(point[1]) > 40;
    try @import("std").testing.expect(turned);
    try @import("std").testing.expect(v.length(v.subtract(points[count - 1], request.end)) <= 24);
    // The goal overlaps a corner; all nearby clear grid columns miss its
    // arrival disk. A physically qualified final edge must still reach it.
    request.end = .{ 67.7, -31.9, 24 };
    const corner_count = try groundDetour(service, request, 2, &.{}, &points);
    try @import("std").testing.expect(corner_count > 0);
    try @import("std").testing.expect(v.length(v.subtract(points[corner_count - 1], request.end)) <= 12.01);
    request.end = .{ 128, 0, 24 };
    const hazard: Bounds = .{ .mins = .{ 80, -512, -64 }, .maxs = .{ 512, 512, 128 } };
    try @import("std").testing.expectEqual(@as(usize, 0), try groundDetour(service, request, 2, &.{hazard}, &points));
    request.end = .{ 1024, 0, 24 };
    try @import("std").testing.expectEqual(@as(usize, 0), try groundDetour(service, request, 2, &.{}, &points));
}

test "local walking recovery requires supported intermediate steps and rejects walls gaps and hazards" {
    const t = @import("std").testing;
    const Fixture = struct {
        wall: bool = false,
        gap: bool = false,
        body_bridge: bool = false,
        hazard: bool = false,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (request.end[0] != request.start[0]) {
                if (request.end[0] >= 32 and (self.wall or request.start[2] < 40)) return .{ .fraction = 0.5, .end = request.start, .normal = .{ -1, 0, 0 } };
                return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            }
            if (request.end[2] < request.start[2]) {
                if (self.gap and request.start[0] >= 32 and request.start[0] <= 48 and !(self.body_bridge and request.mask & 2 != 0)) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
                const height: f32 = if (request.start[0] >= 32) 40 else 24;
                return .{ .fraction = 0.5, .end = .{ request.end[0], request.end[1], height }, .normal = .{ 0, 0, 1 } };
            }
            return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
        }
        fn contents(raw: *anyopaque, point: v.Vec3, _: u16) !u32 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            return if (self.hazard and point[0] >= 32) 4 else 0;
        }
    };
    var fixture: Fixture = .{};
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents };
    const request: collision.Request = .{ .start = .{ 0, 0, 24 }, .end = .{ 64, 0, 40 }, .mins = .{ -16, -16, -24 }, .maxs = .{ 16, 16, 32 }, .slot = 0, .mask = 1 };
    try t.expectEqual(@as(?v.Vec3, .{ 64, 0, 40 }), try walkPath(service, request, 4, &.{}));
    var elevated = request;
    elevated.start[2] = 80;
    try t.expectEqual(@as(?v.Vec3, null), try walkPath(service, elevated, 4, &.{}));
    try t.expectEqual(@as(?v.Vec3, .{ 64, 0, 40 }), try walkPathDrop(service, elevated, 4, &.{}, 64));
    try t.expectEqual(@as(?v.Vec3, null), try walkPath(service, request, 4, &.{.{ .mins = .{ 30, -8, 0 }, .maxs = .{ 34, 8, 80 } }}));
    fixture.wall = true;
    try t.expectEqual(@as(?v.Vec3, null), try walkPath(service, request, 4, &.{}));
    fixture.wall = false;
    fixture.gap = true;
    try t.expectEqual(@as(?v.Vec3, null), try walkPath(service, request, 4, &.{}));
    fixture.body_bridge = true;
    var bodies = request;
    bodies.mask = 3;
    try t.expect((try walkPath(service, bodies, 4, &.{})) != null);
    try t.expectEqual(@as(?v.Vec3, null), try walkPathSupported(service, bodies, 4, &.{}, 18, 1));
    fixture.gap = false;
    fixture.hazard = true;
    try t.expectEqual(@as(?v.Vec3, null), try walkPath(service, request, 4, &.{}));
}

test "low passage steering requires a clear crouched sweep and never crouches for a wall" {
    const t = @import("std").testing;
    const Fixture = struct {
        wall: bool = false,
        open: bool = false,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const blocked = self.wall or (!self.open and request.maxs[2] > 4);
            return .{ .fraction = if (blocked) 0.0 else 1.0, .end = if (blocked) request.start else request.end, .normal = .{ -1, 0, 0 } };
        }
    };
    var fixture: Fixture = .{};
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Fixture.trace };
    try t.expect(try crouch(service, .{ 0, 0, 24 }, .{ 64, 0, 24 }, .{ -12, -12, -24 }, .{ 12, 12, 30 }, 64, 1));
    fixture.wall = true;
    try t.expect(!try crouch(service, .{ 0, 0, 24 }, .{ 64, 0, 24 }, .{ -12, -12, -24 }, .{ 12, 12, 30 }, 64, 1));
    fixture.wall = false;
    fixture.open = true;
    try t.expect(!try crouch(service, .{ 0, 0, 24 }, .{ 64, 0, 24 }, .{ -12, -12, -24 }, .{ 12, 12, 30 }, 64, 1));
}

test "pickup approach shares the support plane for different item and collector bounds" {
    const t = @import("std").testing;
    for ([_]f32{ -8, 0, 1 }) |item_bottom| {
        for ([_]f32{ -24, -32 }) |collector_bottom| {
            const goal = pickupPoint(.{ 64, -128, 112 }, .{ -8, -8, item_bottom }, .{ -16, -16, collector_bottom });
            try t.expectEqual(@as(f32, 64), goal[0]);
            try t.expectEqual(@as(f32, -128), goal[1]);
            try t.expectEqual(112 + item_bottom, goal[2] + collector_bottom);
            // Raw model origins fail this contract, including floor-height weapons.
            try t.expect(goal[2] != 112);
        }
    }
}

test "control floor search can leave an overhang but must validate the final hull" {
    const t = @import("std").testing;
    const Fixture = struct {
        initial_solid: bool = true,
        final_solid: bool = false,
        feet_solid: bool = false,
        all_solid: bool = false,
        fraction: f32 = 0.156,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const stationary = v.length(v.subtract(request.start, request.end)) == 0;
            if (stationary and request.maxs[2] - request.mins[2] <= 1) return .{ .fraction = 0, .end = request.start, .normal = .{ 0, 0, 1 }, .start_solid = self.feet_solid };
            return .{ .fraction = if (stationary) 0 else self.fraction, .end = .{ 77, 1872, 152.125 }, .normal = .{ 0, 0, 1 }, .start_solid = if (stationary) self.final_solid else self.initial_solid, .all_solid = self.all_solid };
        }
    };
    var fixture: Fixture = .{};
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Fixture.trace };
    const request: collision.Request = .{ .start = .{ 77, 1872, 192 }, .end = .{ 77, 1872, -64 }, .mins = .{ -15, -15, -24 }, .maxs = .{ 15, 15, 32 }, .slot = 1, .mask = 1 };
    try t.expect((try supportedPoint(service, request)).floor != null);
    fixture.feet_solid = true;
    // A clear lower-floor endpoint cannot authorize crossing the upper slab.
    try t.expect((try supportedPoint(service, request)).floor == null);
    fixture.feet_solid = false;
    fixture.final_solid = true;
    try t.expect((try supportedPoint(service, request)).floor == null);
    fixture.initial_solid = false;
    try t.expect((try supportedPoint(service, request)).floor != null);
    fixture.all_solid = true;
    try t.expect((try supportedPoint(service, request)).floor == null);
    fixture.all_solid = false;
    fixture.fraction = 1;
    try t.expect((try supportedPoint(service, request)).floor == null);
}
