// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: 3D vector arithmetic.
pub const Vec3 = [3]f32;
pub fn add(a: Vec3, b: Vec3) Vec3 {
    return .{ a[0] + b[0], a[1] + b[1], a[2] + b[2] };
}
pub fn subtract(a: Vec3, b: Vec3) Vec3 {
    return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}
pub fn closestInBounds(point: Vec3, mins: Vec3, maxs: Vec3) Vec3 {
    var result = point;
    for (0..3) |axis| result[axis] = @min(maxs[axis], @max(mins[axis], point[axis]));
    return result;
}
test "a large body's near surface can be in reach while its centre is outside" {
    const t = @import("std").testing;
    const eye: Vec3 = .{ 70, 0, 10 };
    const closest = closestInBounds(eye, .{ -40, -40, -24 }, .{ 40, 40, 24 });
    try t.expectEqual(Vec3{ 40, 0, 10 }, closest);
    try t.expectApproxEqAbs(@as(f32, 30), length(subtract(closest, eye)), 0.001);
    try t.expectEqual(Vec3{ 0, 0, 0 }, closestInBounds(.{ 0, 0, 0 }, .{ -40, -40, -24 }, .{ 40, 40, 24 }));
}
pub fn scale(a: Vec3, factor: f32) Vec3 {
    return .{ a[0] * factor, a[1] * factor, a[2] * factor };
}
pub fn dot(a: Vec3, b: Vec3) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}
pub fn cross(a: Vec3, b: Vec3) Vec3 {
    return .{ a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };
}
pub fn length(a: Vec3) f32 {
    return @sqrt(dot(a, a));
}
pub fn normalize(a: Vec3) Vec3 {
    const size = length(a);
    return if (size > 0) scale(a, 1 / size) else @splat(0);
}
pub fn clip(a: Vec3, normal: Vec3) Vec3 {
    const into = dot(a, normal);
    const backoff = if (into < 0) into * 1.001 else into / 1.001;
    return add(a, scale(normal, -backoff));
}
pub fn basis(angles: Vec3) struct { forward: Vec3, right: Vec3 } {
    const degrees = @import("std").math.pi / 180.0;
    const yaw = angles[1] * degrees;
    const pitch = angles[0] * degrees;
    const roll = angles[2] * degrees;
    const sy = @sin(yaw);
    const cy = @cos(yaw);
    const sp = @sin(pitch);
    const cp = @cos(pitch);
    const sr = @sin(roll);
    const cr = @cos(roll);
    return .{ .forward = .{ cp * cy, cp * sy, -sp }, .right = .{ -sr * sp * cy + cr * sy, -sr * sp * sy - cr * cy, -sr * cp } };
}

// Match the bundled x86 SSE conversion's nearest-even rounding at half units.
pub fn snap(value: f32) f32 {
    const low = @floor(value);
    const fraction = value - low;
    return if (fraction < 0.5) low else if (fraction > 0.5) low + 1 else if (@mod(low, 2) == 0) low else low + 1;
}
