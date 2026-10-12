// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: fireballs drawn by style: lit ones light their way; burning ones trail flames.
const std = @import("std");
const c = @import("../../../engine/abi.zig").c;
const engine = @import("../../../engine/client.zig");
const v = @import("../../../core/domain/vector.zig");
const sprites = @import("../../../core/client/sprites.zig");
const trajectory = @import("../../../engine/trajectory.zig");
const context = @import("context.zig");
const fireballs = @import("actor_catalog").fireballs;
pub const body_tag = fireballs.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    const kind = std.enums.fromInt(fireballs.Kind, draw.entity.weapon) orelse return error.InvalidActorFireball;
    if (!fireballs.style(kind).lit) return false;
    const origin = trajectory.evaluate(draw.entity.pos, draw.now);
    _ = engine.gateway.call(c.CG_R_ADDLIGHTTOSCENE, .{ &origin, engine.floatArg(150), engine.floatArg(0.95), engine.floatArg(0.35), engine.floatArg(0.15) });
    return false;
}
pub fn decorate(model: *context.Model) !void {
    const kind = std.enums.fromInt(fireballs.Kind, model.draw.entity.weapon) orelse return error.InvalidActorFireball;
    if (!fireballs.style(kind).burning) return;
    model.rendered.shaderRGBA = .{ 217, 64, 13, 77 };
    @import("../flame_particles.zig").trail(model.draw.entity, model.draw.now);
}
