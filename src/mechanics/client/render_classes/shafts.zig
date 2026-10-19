// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: shafts drawn by style: magic shafts glow; stuck shafts fade (actors/shafts.zig).
const std = @import("std");
const c = @import("../../../engine/abi.zig").c;
const engine = @import("../../../engine/client.zig");
const v = @import("../../../core/domain/vector.zig");
const sprites = @import("../../../core/client/sprites.zig");
const trajectory = @import("../../../engine/trajectory.zig");
const context = @import("context.zig");
const shafts = @import("actor_catalog").shafts;
pub const body_tag = shafts.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    const entity = draw.entity;
    const kind = std.enums.fromInt(shafts.Kind, entity.weapon) orelse return error.InvalidActorShaft;
    if (!shafts.magic(kind)) return false;
    const origin = trajectory.evaluate(entity.pos, draw.now);
    sprites.draw(try sprites.register("models/global/we_flarered.sp2"), 0, origin, 1, true, draw.ref);
    _ = engine.gateway.call(c.CG_R_ADDLIGHTTOSCENE, .{ &origin, engine.floatArg(175), engine.floatArg(0.65), engine.floatArg(0.35), engine.floatArg(0.35) });
    return false;
}
pub fn decorate(model: *context.Model) !void {
    const entity = model.draw.entity;
    if (entity.time2 > 0) model.rendered.shaderRGBA[3] = @intCast(std.math.clamp(@divTrunc((@as(i64, entity.time2) - model.draw.now) * 255, 1000), 0, 255));
}
