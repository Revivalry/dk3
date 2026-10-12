// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: psyclaw. Client render class: psychic spheres: a green flare, tinted translucent.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("actor_catalog").psyclaw.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    if (draw.entity.weapon != 0) return false;
    sprites.draw(try sprites.register("models/global/e_sflgreen.sp2"), 0, trajectory.evaluate(draw.entity.pos, draw.now), 1, true, draw.ref);
    return false;
}
pub fn decorate(model: *context.Model) !void {
    for (model.draw.entity.origin2, model.rendered.shaderRGBA[0..3]) |axis, *channel| channel.* = @intFromFloat(std.math.clamp(axis, 0, 1) * 255);
    model.rendered.shaderRGBA[3] = 115;
}
