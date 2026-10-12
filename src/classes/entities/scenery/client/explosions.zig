// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: scenery. Client render class: explosion sprites.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("../../../../mechanics/domain/props.zig").explosion_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    const entity = draw.entity;
    const sprite = try sprites.register(try engine.config(draw.game, c.CS_MODELS + @as(usize, @intCast(entity.modelindex))));
    const point = trajectory.evaluate(entity.pos, draw.now);
    sprites.draw(sprite, @intCast(entity.frame), point, entity.angles2[0], false, draw.ref);
    _ = engine.gateway.call(c.CG_R_ADDLIGHTTOSCENE, .{ &point, engine.floatArg(200), engine.floatArg(1), engine.floatArg(0.5), engine.floatArg(0) });
    return true;
}
