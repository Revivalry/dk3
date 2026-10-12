// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Client render class: summoning effects.
const std = @import("std");
const c = @import("../../../engine/abi.zig").c;
const engine = @import("../../../engine/client.zig");
const v = @import("../../../core/domain/vector.zig");
const sprites = @import("../../../core/client/sprites.zig");
const trajectory = @import("../../../engine/trajectory.zig");
const context = @import("context.zig");
pub const body_tag = @import("actor_catalog").summon_effect.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    try @import("../summon_effects.zig").draw(draw.entity, draw.now, draw.ref);
    return true;
}
