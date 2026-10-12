// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: thunderskeet. Client render class: the lightning spray sprite.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("actor_catalog").thunderskeet.spray_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    const entity = draw.entity;
    const sprite = try sprites.register(@import("actor_catalog").thunderskeet.spray_model);
    sprites.drawPlane(sprite, 0, trajectory.evaluate(entity.pos, draw.now), entity.angles2[0], true, v.scale(draw.ref.viewaxis[1], -1), draw.ref.viewaxis[2], .{ 255, 255, 255, 115 });
    return true;
}
