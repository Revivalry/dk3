// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: inmater. Client render class: actor laser beams.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("actor_catalog").laser.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    try @import("../../../../mechanics/client/actor_lasers.zig").draw(draw.entity, draw.now, draw.ref);
    return true;
}
