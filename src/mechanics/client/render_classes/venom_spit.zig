// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: render class for venom spit trails.
const std = @import("std");
const c = @import("../../../engine/abi.zig").c;
const engine = @import("../../../engine/client.zig");
const v = @import("../../../core/domain/vector.zig");
const sprites = @import("../../../core/client/sprites.zig");
const trajectory = @import("../../../engine/trajectory.zig");
const context = @import("context.zig");
pub const body_tag = @import("actor_catalog").venom_spit.render_tag;
pub fn overlay(model: *context.Model) !void {
    @import("../venom_spit.zig").draw(model.draw.entity, model.draw.now);
}
