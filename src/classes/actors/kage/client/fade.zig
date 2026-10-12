// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: kage. Client render class: Kage, his ghosts and Nharre fade in and out.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const overlay_tags = [_]i32{@import("actor_catalog").fade.fade_tag};
pub fn decorate(model: *context.Model) !void {
    model.rendered.shaderRGBA[3] = @min(model.rendered.shaderRGBA[3], @as(u8, @intFromFloat(std.math.clamp(model.draw.entity.origin2[0], 0, 1) * 255)));
}
