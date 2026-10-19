// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: render class for boss wisps (fading) and lightning.
const std = @import("std");
const c = @import("../../../engine/abi.zig").c;
const engine = @import("../../../engine/client.zig");
const v = @import("../../../core/domain/vector.zig");
const sprites = @import("../../../core/client/sprites.zig");
const trajectory = @import("../../../engine/trajectory.zig");
const context = @import("context.zig");
pub const body_tag = @import("actor_catalog").wisp_lightning.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    return @import("../wisp_lightning.zig").draw(draw.entity, draw.now, draw.ref);
}
pub fn decorate(model: *context.Model) !void {
    model.rendered.shaderRGBA[3] = @intFromFloat(std.math.clamp(model.draw.entity.origin2[0], 0, 1) * 255);
}
