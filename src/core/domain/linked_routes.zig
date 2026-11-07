// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Shortest directed link routes with a reachable partial endpoint.
const std = @import("std");
const v = @import("vector.zig");
pub const Node = struct { position: v.Vec3, first: usize, count: usize };
pub const Edge = struct { to: usize, cost: f32 };
pub const Bounds = struct {
    mins: v.Vec3,
    maxs: v.Vec3,
    pub fn intersects(self: Bounds, from: v.Vec3, to: v.Vec3) bool {
        var enter: f32 = 0;
        var leave: f32 = 1;
        for (0..3) |axis| {
            const delta = to[axis] - from[axis];
            if (@abs(delta) < 0.0001) {
                if (from[axis] < self.mins[axis] or from[axis] > self.maxs[axis]) return false;
            } else {
                const a = (self.mins[axis] - from[axis]) / delta;
                const b = (self.maxs[axis] - from[axis]) / delta;
                enter = @max(enter, @min(a, b));
                leave = @min(leave, @max(a, b));
                if (enter > leave) return false;
            }
        }
        return true;
    }
};

pub fn route(allocator: std.mem.Allocator, nodes: []const Node, edges: []const Edge, origin: v.Vec3, destination: v.Vec3, points: []v.Vec3) !usize {
    return routeAvoiding(allocator, nodes, edges, origin, destination, points, &.{});
}
pub fn routeAvoiding(allocator: std.mem.Allocator, nodes: []const Node, edges: []const Edge, origin: v.Vec3, destination: v.Vec3, points: []v.Vec3, excluded: []const Bounds) !usize {
    if (nodes.len == 0 or points.len == 0) return 0;
    const cost = try allocator.alloc(f32, nodes.len);
    defer allocator.free(cost);
    @memset(cost, std.math.inf(f32));
    const previous = try allocator.alloc(?usize, nodes.len);
    defer allocator.free(previous);
    @memset(previous, null);
    const visited = try allocator.alloc(bool, nodes.len);
    defer allocator.free(visited);
    @memset(visited, false);
    var start: usize = 0;
    for (nodes, 0..) |node, index| if (v.length(v.subtract(node.position, origin)) < v.length(v.subtract(nodes[start].position, origin))) {
        start = index;
    };
    cost[start] = 0;
    for (0..nodes.len) |_| {
        var next: ?usize = null;
        for (cost, visited, 0..) |distance, done, index| if (!done and std.math.isFinite(distance) and (next == null or distance < cost[next.?])) {
            next = index;
        };
        const from = next orelse break;
        visited[from] = true;
        const node = nodes[from];
        links: for (edges[node.first..][0..node.count]) |edge| {
            if (edge.to >= nodes.len or !std.math.isFinite(edge.cost) or edge.cost < 0) return error.InvalidRouteLink;
            for (excluded) |box| if (box.intersects(node.position, nodes[edge.to].position)) continue :links;
            if (cost[from] + edge.cost < cost[edge.to]) {
                cost[edge.to] = cost[from] + edge.cost;
                previous[edge.to] = from;
            }
        }
    }
    var end = start;
    for (nodes, visited, 0..) |node, reachable, index| if (reachable and v.length(v.subtract(node.position, destination)) < v.length(v.subtract(nodes[end].position, destination))) {
        end = index;
    };
    var length: usize = 1;
    var at = end;
    while (previous[at]) |before| {
        length += 1;
        at = before;
    }
    if (length > points.len) return error.RouteTooLong;
    at = end;
    var left = length;
    while (left > 0) {
        left -= 1;
        points[left] = nodes[at].position;
        at = previous[at] orelse break;
    }
    return length;
}

test "directed route keeps its corridor and reports disconnected goals without truncation" {
    const nodes = [_]Node{
        .{ .position = .{ 0, 0, 0 }, .first = 0, .count = 1 },
        .{ .position = .{ 0, 100, 0 }, .first = 1, .count = 1 },
        .{ .position = .{ 100, 100, 0 }, .first = 2, .count = 0 },
        .{ .position = .{ 110, 100, 0 }, .first = 2, .count = 0 },
    };
    const edges = [_]Edge{ .{ .to = 1, .cost = 100 }, .{ .to = 2, .cost = 100 } };
    var points: [4]v.Vec3 = undefined;
    try std.testing.expectEqual(3, try route(std.testing.allocator, &nodes, &edges, .{ 0, 0, 0 }, .{ 110, 100, 0 }, &points));
    try std.testing.expectEqual(nodes[1].position, points[1]);
    try std.testing.expectEqual(nodes[2].position, points[2]);
    try std.testing.expectError(error.RouteTooLong, route(std.testing.allocator, &nodes, &edges, .{ 0, 0, 0 }, .{ 110, 100, 0 }, points[0..2]));
    try std.testing.expectEqual(1, try route(std.testing.allocator, &nodes, &edges, .{ 100, 100, 0 }, .{ 0, 0, 0 }, &points));
}

test "excluded volumes reject a crossing link and retain a supported alternate corridor" {
    const nodes = [_]Node{
        .{ .position = .{ 0, 0, 0 }, .first = 0, .count = 2 },
        .{ .position = .{ 100, 0, 0 }, .first = 2, .count = 1 },
        .{ .position = .{ 0, 100, 0 }, .first = 3, .count = 1 },
        .{ .position = .{ 200, 100, 0 }, .first = 4, .count = 1 },
        .{ .position = .{ 200, 0, 0 }, .first = 5, .count = 0 },
    };
    const edges = [_]Edge{ .{ .to = 1, .cost = 100 }, .{ .to = 2, .cost = 100 }, .{ .to = 4, .cost = 100 }, .{ .to = 3, .cost = 200 }, .{ .to = 4, .cost = 100 } };
    const barrier: Bounds = .{ .mins = .{ 40, -10, -10 }, .maxs = .{ 60, 10, 10 } };
    var points: [5]v.Vec3 = undefined;
    try std.testing.expectEqual(4, try routeAvoiding(std.testing.allocator, &nodes, &edges, nodes[0].position, nodes[4].position, &points, &.{barrier}));
    try std.testing.expectEqual(nodes[2].position, points[1]);
    try std.testing.expectEqual(nodes[3].position, points[2]);
    try std.testing.expect(barrier.intersects(nodes[1].position, nodes[0].position));
    try std.testing.expect(!barrier.intersects(.{ 0, 0, 20 }, .{ 100, 0, 20 }));
}
