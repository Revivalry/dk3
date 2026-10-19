// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: dwarf. Client render class: thrown axes fade once stuck.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("actor_catalog").dwarf.axe_tag;
pub fn decorate(model: *context.Model) !void {
    model.rendered.shaderRGBA[3] = @intCast(std.math.clamp(@divTrunc((@as(i64, model.draw.entity.time2) - model.draw.now) * 255, 1000), 0, 255));
}
