// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: volumetric light beams, two widening translucent cones from a source to the
//! point the light lands, fading along their length.
const std = @import("std");
const c = @import("../../engine/abi.zig").c;
const engine = @import("../../engine/client.zig");
const v = @import("../../core/domain/vector.zig");
pub fn beam(start: v.Vec3, end: v.Vec3, radius: f32, tint: v.Vec3, opacity: u8) !void {
    const direction = v.subtract(end, start);
    const basis = v.basis(.{ -std.math.atan2(direction[2], @sqrt(direction[0] * direction[0] + direction[1] * direction[1])) * 180 / std.math.pi, std.math.atan2(direction[1], direction[0]) * 180 / std.math.pi, 0 });
    const up = v.cross(basis.right, basis.forward);
    const distance = v.length(direction);
    var color: [4]u8 = .{ 255, 255, 255, opacity };
    for (tint, color[0..3]) |channel, *out| out.* = @intFromFloat(std.math.clamp(channel, 0, 1) * 255);
    const shader = engine.gateway.call(c.CG_R_REGISTERSHADER, .{@as([*:0]const u8, "dk3/fx/spotlight")});
    for (0..2) |layer| {
        const scale: f32 = if (layer == 0) 1 else 2.0 / 3.0;
        const near = radius * scale;
        const far = near + distance * 0.2 * scale;
        for (0..16) |side| {
            var vertices: [4]c.polyVert_t = undefined;
            for (0..4) |i| {
                const angle = @as(f32, @floatFromInt(side + @as(usize, if (i == 1 or i == 2) 1 else 0))) * (2.0 * std.math.pi / 16.0);
                const width = if (i < 2) near else far;
                const origin = if (i < 2) start else end;
                vertices[i] = .{ .xyz = v.add(origin, v.add(v.scale(basis.right, @cos(angle) * width), v.scale(up, @sin(angle) * width))), .st = @splat(0), .modulate = if (i < 2) color else .{ 0, 0, 0, 0 } };
            }
            _ = engine.gateway.call(c.CG_R_ADDPOLYTOSCENE, .{ shader, @as(isize, 4), &vertices });
        }
    }
}
