// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: render class for burst muzzle flashes.
const std = @import("std");
const c = @import("../../../engine/abi.zig").c;
const engine = @import("../../../engine/client.zig");
const v = @import("../../../core/domain/vector.zig");
const sprites = @import("../../../core/client/sprites.zig");
const trajectory = @import("../../../engine/trajectory.zig");
const context = @import("context.zig");
pub const body_tag = @import("actor_catalog").bursts.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    try @import("../gunner_bursts.zig").draw(draw.game, draw.entity, draw.entities, draw.now);
    return true;
}
