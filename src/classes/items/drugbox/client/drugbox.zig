// SPDX-License-Identifier: GPL-2.0-or-later
//! item-class: drugbox. Client render class: drug boxes fade.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("item_catalog").drugbox.render_tag;
pub fn decorate(model: *context.Model) !void {
    model.rendered.shaderRGBA[3] = @intCast(std.math.clamp(model.draw.entity.time2, 0, 255));
}
