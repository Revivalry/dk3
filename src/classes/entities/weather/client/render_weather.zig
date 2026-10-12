// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: weather. Client render class: rain and snow.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("../domain/weather.zig").render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    @import("weather.zig").emit(draw.entity, draw.now, draw.ref);
    return true;
}
