// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: medusa. Client render class: glowing eyes while gazing.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const overlay_tags = [_]i32{@import("actor_catalog").medusa.gaze_tag};
pub fn overlay(model: *context.Model) !void {
    if (model.draw.entity.origin2[0] != 0) try @import("medusa.zig").eyes(model.rendered, model.draw.ref);
}
