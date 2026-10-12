// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: buboid. Client render class: melting and its drips.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const overlay_tags = [_]i32{@import("actor_catalog").buboid.melt_tag};
pub fn decorate(model: *context.Model) !void {
    model.rendered.shaderRGBA[3] = @intFromFloat(std.math.clamp(model.draw.entity.origin2[0], 0, 1) * 255);
}
pub fn overlay(model: *context.Model) !void {
    @import("buboid.zig").emit(model.rendered, model.draw.entity, model.draw.now);
}
