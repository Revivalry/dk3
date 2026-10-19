// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: healer. Client render class: health station glow.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("item_catalog").hosportal.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    @import("healers.zig").draw(draw.entity, draw.now);
    return false;
}
