// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: collision trace requests and results.
const vector = @import("vector.zig");
// A zero world denotes the caller's local collision service. Region queries
// return a checked engine world handle alongside its local entity slot.
pub const Trace = struct { fraction: f32, world: u32 = 0, contents: u32 = 0, sky: bool = false, no_impact: bool = false, material: enum { ordinary, metal, wood } = .ordinary, end: vector.Vec3, normal: vector.Vec3, start_solid: bool = false, all_solid: bool = false, entity: u16 = 2047, slick: bool = false, ladder: bool = false, holy: bool = false };
pub const Request = struct { brushes_only: bool = false, start: vector.Vec3, end: vector.Vec3, mins: vector.Vec3, maxs: vector.Vec3, slot: u16, mask: u32 };
pub const Collision = struct {
    context: *anyopaque,
    trace_fn: *const fn (*anyopaque, Request) anyerror!Trace,
    contents_fn: ?*const fn (*anyopaque, vector.Vec3, u16) anyerror!u32 = null,
    pub fn contents(self: Collision, point: vector.Vec3, skip: u16) !u32 {
        return (self.contents_fn orelse return error.MissingPointContents)(self.context, point, skip);
    }
    pub fn trace(self: Collision, request: Request) !Trace {
        return self.trace_fn(self.context, request);
    }
    /// Recover a shallow initial overlap using an outside-to-inside sweep.
    /// A trace that starts inside a brush has no separating plane. Search
    /// only a caller-bounded neighbourhood and retain the nearest valid plane.
    pub fn separate(self: Collision, request: Request, limit: f32) !?Trace {
        var best: ?Trace = null;
        var distance = limit + 1;
        const directions = comptime blk: {
            var result: [26]vector.Vec3 = undefined;
            var count: usize = 0;
            for ([_]f32{ -1, 0, 1 }) |x| for ([_]f32{ -1, 0, 1 }) |y| for ([_]f32{ -1, 0, 1 }) |z| {
                if (x == 0 and y == 0 and z == 0) continue;
                result[count] = vector.normalize(.{ x, y, z });
                count += 1;
            };
            break :blk result;
        };
        for (1..5) |step| for (directions) |direction| {
            var probe = request;
            probe.start = vector.add(request.start, vector.scale(direction, limit * @as(f32, @floatFromInt(step)) / 4));
            probe.end = request.start;
            const hit = try self.trace(probe);
            if (hit.start_solid or hit.all_solid or hit.fraction == 1 or vector.length(hit.normal) < 0.9) continue;
            const separation = vector.length(vector.subtract(hit.end, request.start));
            if (separation >= distance or separation > limit) continue;
            var clear = request;
            clear.start = vector.add(hit.end, vector.scale(hit.normal, 0.02));
            clear.end = clear.start;
            const check = try self.trace(clear);
            if (check.start_solid or check.all_solid) continue;
            best = hit;
            best.?.end = clear.start;
            distance = separation;
        };
        return best;
    }
};

test "shallow overlap obtains a separating plane while deep overlap stays bounded" {
    const t = @import("std").testing;
    const Floor = struct {
        fn trace(_: *anyopaque, request: Request) !Trace {
            const a = request.start[2] + request.mins[2];
            const b = request.end[2] + request.mins[2];
            if (a < 0) return .{ .fraction = 0, .end = request.start, .normal = @splat(0), .start_solid = true, .all_solid = b < 0 };
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = a / (a - b);
            return .{ .fraction = fraction, .end = vector.add(request.start, vector.scale(vector.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 } };
        }
    };
    var context: u8 = 0;
    const service: Collision = .{ .context = &context, .trace_fn = Floor.trace };
    const request: Request = .{ .start = .{ 0, 0, 1.5 }, .end = .{ 0, 0, 1.5 }, .mins = @splat(-2), .maxs = @splat(2), .slot = 0, .mask = 1 };
    const recovered = (try service.separate(request, 1)).?;
    try t.expectApproxEqAbs(@as(f32, 2.02), recovered.end[2], 0.001);
    try t.expectEqual(vector.Vec3{ 0, 0, 1 }, recovered.normal);
    var deep = request;
    deep.start[2] = -4;
    try t.expectEqual(@as(?Trace, null), try service.separate(deep, 1));
}

test "a shallow corner overlap can separate along both contact planes" {
    const Corner = struct {
        fn trace(_: *anyopaque, request: Request) !Trace {
            if (request.start[0] < 0 or request.start[1] < 0) return .{ .fraction = 0, .end = request.start, .normal = @splat(0), .start_solid = true, .all_solid = request.end[0] < 0 or request.end[1] < 0 };
            var result: Trace = .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            for (0..2) |axis| if (request.end[axis] < 0) {
                const fraction = request.start[axis] / (request.start[axis] - request.end[axis]);
                if (fraction <= result.fraction) {
                    result.fraction = fraction;
                    result.end = vector.add(request.start, vector.scale(vector.subtract(request.end, request.start), fraction));
                    result.normal = @splat(0);
                    result.normal[axis] = 1;
                }
            };
            return result;
        }
    };
    var context: u8 = 0;
    const service: Collision = .{ .context = &context, .trace_fn = Corner.trace };
    const request: Request = .{ .start = .{ -0.2, -0.2, 0 }, .end = .{ -0.2, -0.2, 0 }, .mins = @splat(0), .maxs = @splat(0), .slot = 0, .mask = 1 };
    const repaired = (try service.separate(request, 1)).?;
    try @import("std").testing.expect(repaired.end[0] >= 0 and repaired.end[1] >= 0);
    try @import("std").testing.expect(vector.length(vector.subtract(repaired.end, request.start)) <= 1);
}
