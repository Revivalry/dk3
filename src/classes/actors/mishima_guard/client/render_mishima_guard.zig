// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: mishima_guard. Client render class: the pistol in the neural guard's right hand.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
const policy = @import("actor_catalog").mishima;
pub const overlay_tags = [_]i32{policy.render_tag};
pub fn overlay(model: *context.Model) !void {
    const parent = model.rendered;
    // The original model's mesh includes the gun.
    if (!@import("../../../../mechanics/client/neural_models.zig").isSkeletal(parent.hModel)) return;
    const hand = @import("../../../../mechanics/client/actor_hardpoints.zig").transform(parent, "tag_weapon") catch return;
    var gun = std.mem.zeroes(c.refEntity_t);
    gun.reType = c.RT_MODEL;
    gun.hModel = try @import("../../../../mechanics/client/models.zig").register(policy.pistol_model);
    if (gun.hModel == 0) return;
    gun.origin = hand.origin;
    for (&gun.axis, policy.pistol_axes, policy.pistol_grip) |*axis, local, grip| {
        axis.* = .{ 0, 0, 0 };
        for (hand.axis, local) |frame, amount| axis.* = v.add(axis.*, v.scale(frame, amount));
        gun.origin = v.subtract(gun.origin, v.scale(axis.*, grip));
    }
    gun.oldorigin = gun.origin;
    gun.nonNormalizedAxes = parent.nonNormalizedAxes;
    gun.renderfx = c.RF_MINLIGHT | (parent.renderfx & c.RF_NOSHADOW);
    gun.shaderRGBA = parent.shaderRGBA;
    _ = engine.gateway.call(c.CG_R_ADDREFENTITYTOSCENE, .{&gun});
}
