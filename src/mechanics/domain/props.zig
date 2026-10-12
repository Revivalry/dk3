// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: physical props: authored decorations, gibs, corpses, debris and explosion
//! sprites share one animated, tossed or bouncing body. What spawns them and their extra roles
//! belong to their classes (server/prop_classes.zig).
const v = @import("../../core/domain/vector.zig");
const animation = @import("../../core/domain/animation.zig");
pub const render_tag = 10002;
pub const explosion_tag = 10003;
pub const Material = enum { unbreakable, wood, metal, glass, flesh };
pub const Movement = enum { stationary, toss, bounce };
pub const State = struct {
    model: []const u8,
    movement: Movement = .stationary,
    material: Material = .unbreakable,
    sequence: animation.Sequence = .{},
    looping: bool = false,
    started_ms: i64,
    scale: v.Vec3 = @splat(1),
    alpha: f32 = 1,
    spin: v.Vec3 = @splat(0),
    breakable: bool = false,
    explosive: bool = false,
    damage: f32 = 25,
    broken: bool = false,
    breaking_ms: ?i64 = null,
    expires_ms: ?i64 = null,
    fragment: bool = false,
    explosive_fragment: bool = false,
    explosion: bool = false,
    gib: ?@import("gibs.zig").State = null,
    corpse: ?struct { appearance: u8 } = null,
};
pub fn contact(velocity: v.Vec3, normal: v.Vec3, bounce: bool) v.Vec3 {
    const clipped = v.subtract(velocity, v.scale(normal, v.dot(velocity, normal) * (if (bounce) @as(f32, 1.5) else 1)));
    if (normal[2] > 0.7 and (!bounce or clipped[2] < 60)) return @splat(0);
    return clipped;
}
