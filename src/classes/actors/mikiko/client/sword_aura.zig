// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: mikiko. Client render class: the sword aura of Mikiko and Kage; Kage fades with it.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const overlay_tags = [_]i32{@import("actor_catalog").sword_aura_tag};
pub fn decorate(model: *context.Model) !void {
    const entity = model.draw.entity;
    if (entity.legsAnim == 1) model.rendered.shaderRGBA[3] = @min(model.rendered.shaderRGBA[3], @as(u8, @intCast(@divTrunc(std.math.clamp(entity.torsoAnim, 0, 1000) * 255, 1000))));
}
pub fn overlay(model: *context.Model) !void {
    try @import("../../../../mechanics/client/sword_aura.zig").draw(model.rendered, model.draw.entity, model.draw.now, model.draw.ref);
}
