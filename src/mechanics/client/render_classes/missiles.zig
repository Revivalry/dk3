// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: rocket glows, from each launching class's rocket style (actors/missiles.zig).
const std = @import("std");
const c = @import("../../../engine/abi.zig").c;
const engine = @import("../../../engine/client.zig");
const v = @import("../../../core/domain/vector.zig");
const sprites = @import("../../../core/client/sprites.zig");
const trajectory = @import("../../../engine/trajectory.zig");
const context = @import("context.zig");
const missiles = @import("actor_catalog").missiles;
pub const body_tag = missiles.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    const origin = trajectory.evaluate(draw.entity.pos, draw.now);
    const kind = std.enums.fromInt(missiles.Kind, draw.entity.weapon) orelse return error.InvalidActorMissile;
    const style = missiles.style(kind);
    sprites.draw(try sprites.register(style.glow), 0, origin, style.glow_scale, true, draw.ref);
    _ = engine.gateway.call(c.CG_R_ADDLIGHTTOSCENE, .{ &origin, engine.floatArg(style.light_radius), engine.floatArg(0.75), engine.floatArg(style.light_green), engine.floatArg(0.15) });
    return false;
}
