// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: firefly. Client render class: firefly sprites.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
const firefly = @import("actor_catalog").firefly;
pub const body_tag = @import("actor_catalog").glow_particle.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    const entity = draw.entity;
    if (entity.frame < 0 or entity.frame >= firefly.models.len) return error.InvalidFireflyShape;
    const sprite = try sprites.register(firefly.models[@intCast(entity.frame)]);
    var color: [4]u8 = undefined;
    for (entity.origin2, color[0..3]) |axis, *channel| channel.* = @intFromFloat(std.math.clamp(axis, 0, 1) * 255);
    color[3] = @intCast(std.math.clamp(entity.time2, 0, 255));
    sprites.drawPlane(sprite, 0, trajectory.evaluate(entity.pos, draw.now), entity.angles2[0], false, v.scale(draw.ref.viewaxis[1], -1), draw.ref.viewaxis[2], color);
    return true;
}
