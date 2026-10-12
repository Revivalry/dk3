// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: cambot. Client render class: the camera lamp.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const overlay_tags = [_]i32{ @import("actor_catalog").cambot.idle_tag, @import("actor_catalog").cambot.alert_tag };
pub fn overlay(model: *context.Model) !void {
    try @import("cambot.zig").draw(model.rendered, model.draw.entity, model.draw.now, model.draw.ref);
    model.draw.counters.lamps += 1;
}
