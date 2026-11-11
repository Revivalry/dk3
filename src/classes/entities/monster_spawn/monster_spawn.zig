// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: monster_spawn. Bounded clearance for an authored factory's initial body.
const collision = @import("../../../core/domain/collision.zig");
const v = @import("../../../core/domain/vector.zig");
pub const clearance_limit: f32 = 48;

pub fn placement(service: collision.Collision, request: collision.Request) !?v.Vec3 {
    const at = try service.trace(request);
    if (!at.start_solid and !at.all_solid) return request.start;
    return if (try service.separate(request, clearance_limit)) |clear| clear.end else null;
}

test "factory clearance retains valid origins and bounds recovery of embedded bodies" {
    const testing = @import("std").testing;
    const Floor = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            const a = request.start[2] + request.mins[2];
            const b = request.end[2] + request.mins[2];
            if (a < 0) return .{ .fraction = 0, .end = request.start, .normal = @splat(0), .start_solid = true, .all_solid = b < 0 };
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = a / (a - b);
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 } };
        }
    };
    var context: u8 = 0;
    const service: collision.Collision = .{ .context = &context, .trace_fn = Floor.trace };
    var request: collision.Request = .{ .start = .{ 0, 0, 24.125 }, .end = .{ 0, 0, 24.125 }, .mins = .{ -16, -16, -24 }, .maxs = .{ 16, 16, 32 }, .slot = 0, .mask = 1 };
    try testing.expectEqual(request.start, (try placement(service, request)).?);
    request.start[2] = 0.03125;
    request.end = request.start;
    const recovered = (try placement(service, request)).?;
    try testing.expectApproxEqAbs(@as(f32, 24.02), recovered[2], 0.001);
    request.start[2] = -40;
    request.end = request.start;
    try testing.expectEqual(@as(?v.Vec3, null), try placement(service, request));
}
