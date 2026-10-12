// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: light. Client render class: lights and flames.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("../domain/lightstyles.zig").render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    try @import("lights.zig").draw(draw.game, draw.entity, draw.now, draw.ref);
    return true;
}
