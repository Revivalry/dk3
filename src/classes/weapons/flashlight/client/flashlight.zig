// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: flashlight. Client adapter: lights where its rays land.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const registry = @import("../../../../mechanics/client/weapon_classes/registry.zig");
pub const description = @import("weapon_catalog").classes.flashlight;
pub fn drawEffect(effect: registry.Effect) !void {
    const entity = effect.entity;
    const W = description;
    const origin = if (entity.otherEntityNum == effect.client) effect.ref.vieworg else entity.pos.trBase;
    const angles = entity.apos.trBase;
    const strength = std.math.clamp(entity.angles2[0], 0, 1);
    for (W.rays) |offset| {
        const direction = v.basis(v.add(angles, .{ offset[0], offset[1], 0 })).forward;
        const hit = try engine.collisionService().trace(.{ .start = origin, .end = v.add(origin, v.scale(direction, 2000)), .mins = @splat(0), .maxs = @splat(0), .slot = @intCast(entity.otherEntityNum), .mask = c.MASK_SHOT });
        if (hit.sky or hit.fraction == 1) continue;
        const distance = v.length(v.subtract(hit.end, origin));
        const position = v.add(hit.end, v.scale(hit.normal, 2));
        const brightness = W.brightness(distance, strength);
        _ = engine.gateway.call(c.CG_R_ADDLIGHTTOSCENE, .{ &position, engine.floatArg(W.radius(distance, strength)), engine.floatArg(brightness), engine.floatArg(brightness), engine.floatArg(brightness) });
    }
}
