// SPDX-License-Identifier: GPL-2.0-or-later
//! item-class: chest. Client render class: chests open, and their bright variant shows while revealing.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("item_catalog").chest.render_tag;
pub fn decorate(model: *context.Model) !void {
    try @import("../../../entities/chest/client/chests.zig").draw(model.rendered, model.draw.entity, model.draw.now);
    if (model.draw.entity.weapon == 2) model.bright = true;
}
