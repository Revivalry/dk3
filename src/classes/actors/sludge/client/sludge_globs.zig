// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: sludge. Client render class: glowing sludge globs.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
const sludge = @import("actor_catalog").sludge;
pub const body_tag = sludge.render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    const origin = trajectory.evaluate(draw.entity.pos, draw.now);
    sprites.draw(try sprites.register(sludge.glow), 0, origin, 2, true, draw.ref);
    _ = engine.gateway.call(c.CG_R_ADDLIGHTTOSCENE, .{ &origin, engine.floatArg(300), engine.floatArg(0.5), engine.floatArg(1), engine.floatArg(0.5) });
    return false;
}
