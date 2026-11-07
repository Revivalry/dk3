// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Exact collision-query reuse within an immutable prediction.
const std = @import("std");
const collision = @import("collision.zig");
const v = @import("vector.zig");

/// Construct on the stack for one synchronous prediction only. Neither the
/// backend geometry nor its query ownership may change during this scope.
/// Direct-mapped eviction bounds memory and never changes a query's result.
pub const Memo = struct {
    backend: collision.Collision,
    traces: [512]?Entry = @splat(null),
    points: [128]?Point = @splat(null),
    const Key = [15]u32;
    const Entry = struct { key: Key, result: collision.Trace };
    const Point = struct { key: [4]u32, result: u32 };

    pub fn service(self: *Memo) collision.Collision {
        return .{ .context = self, .trace_fn = trace, .contents_fn = contents };
    }
    fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
        const self: *Memo = @ptrCast(@alignCast(raw));
        var key: Key = undefined;
        inline for (.{ request.start, request.end, request.mins, request.maxs }, 0..) |point, i| {
            inline for (0..3) |axis| key[i * 3 + axis] = @bitCast(point[axis]);
        }
        key[12] = request.slot;
        key[13] = request.mask;
        key[14] = @intFromBool(request.brushes_only);
        const index = std.hash.Wyhash.hash(0, std.mem.asBytes(&key)) % self.traces.len;
        if (self.traces[index]) |entry| if (std.mem.eql(u32, &entry.key, &key)) return entry.result;
        const result = try self.backend.trace(request);
        self.traces[index] = .{ .key = key, .result = result };
        return result;
    }
    fn contents(raw: *anyopaque, point: v.Vec3, slot: u16) !u32 {
        const self: *Memo = @ptrCast(@alignCast(raw));
        const key: [4]u32 = .{ @bitCast(point[0]), @bitCast(point[1]), @bitCast(point[2]), slot };
        const index = std.hash.Wyhash.hash(0, std.mem.asBytes(&key)) % self.points.len;
        if (self.points[index]) |entry| if (std.mem.eql(u32, &entry.key, &key)) return entry.result;
        const result = try self.backend.contents(point, slot);
        self.points[index] = .{ .key = key, .result = result };
        return result;
    }
};

test "prediction memo keeps masks, hulls, skipped entities and contents distinct" {
    const Backend = struct {
        calls: u32 = 0,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return .{ .fraction = 1, .end = request.end, .normal = @splat(0), .contents = self.calls };
        }
        fn contents(raw: *anyopaque, _: v.Vec3, _: u16) !u32 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return self.calls;
        }
    };
    var backend: Backend = .{};
    var memo: Memo = .{ .backend = .{ .context = &backend, .trace_fn = Backend.trace, .contents_fn = Backend.contents } };
    const service = memo.service();
    var request: collision.Request = .{ .start = @splat(0), .end = .{ 1, 2, 3 }, .mins = @splat(-15), .maxs = @splat(15), .slot = 1, .mask = 1 };
    const first = try service.trace(request);
    try std.testing.expectEqualDeep(first, try service.trace(request));
    try std.testing.expectEqual(@as(u32, 1), backend.calls);
    request.mask = 2;
    _ = try service.trace(request);
    request.slot = 2;
    _ = try service.trace(request);
    request.maxs[2] = 32;
    _ = try service.trace(request);
    request.brushes_only = true;
    _ = try service.trace(request);
    try std.testing.expectEqual(@as(u32, 5), backend.calls);
    const point = try service.contents(.{ 1, 2, 3 }, 1);
    try std.testing.expectEqual(point, try service.contents(.{ 1, 2, 3 }, 1));
    _ = try service.contents(.{ 1, 2, 3 }, 2);
    try std.testing.expectEqual(@as(u32, 7), backend.calls);
}
