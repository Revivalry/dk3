// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: render class for meteor staves and fragments.
const std = @import("std");
const c = @import("../../../engine/abi.zig").c;
const engine = @import("../../../engine/client.zig");
const v = @import("../../../core/domain/vector.zig");
const sprites = @import("../../../core/client/sprites.zig");
const trajectory = @import("../../../engine/trajectory.zig");
const context = @import("context.zig");
pub const body_tag = @import("actor_catalog").meteors.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    return @import("../actor_meteors.zig").draw(draw.entity, draw.now, draw.ref);
}
