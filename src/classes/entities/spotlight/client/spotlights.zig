// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: spotlight. Beam scattering is separate from surface illumination.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
pub fn draw(game: *const c.gameState_t, entity: c.entityState_t, now: i32, ref: *const c.refdef_t) !void {
    const start = @import("../../../../engine/trajectory.zig").evaluate(entity.pos, now);
    if (entity.weapon & 2 != 0) try flare(game, entity, start, ref);
    if (entity.weapon & 1 == 0) {
        if (entity.weapon & 2 == 0) {
            const brightness: f32 = @bitCast(entity.time2);
            if (std.math.isFinite(brightness) and brightness >= 0 and brightness <= 1000000) _ = engine.gateway.call(c.CG_R_ADDLIGHTTOSCENE, .{ &start, engine.floatArg(brightness), engine.floatArg(entity.angles2[0]), engine.floatArg(entity.angles2[1]), engine.floatArg(entity.angles2[2]) });
        }
        return;
    }
    try cone(start, entity.origin2, @floatFromInt(entity.frame), entity.angles2);
}
pub fn cone(start: v.Vec3, end: v.Vec3, radius: f32, tint: v.Vec3) !void {
    try @import("../../../../mechanics/client/light_beams.zig").beam(start, end, radius, tint, 64);
    _ = engine.gateway.call(c.CG_R_ADDADDITIVELIGHTTOSCENE, .{ &end, engine.floatArg(75), engine.floatArg(tint[0]), engine.floatArg(tint[1]), engine.floatArg(tint[2]) });
}

fn flare(game: *const c.gameState_t, entity: c.entityState_t, point: v.Vec3, ref: *const c.refdef_t) !void {
    if (entity.modelindex <= 0 or entity.modelindex >= c.MAX_MODELS) return;
    const delta = v.subtract(ref.vieworg, point);
    const distance = v.length(delta);
    const hit = try engine.collisionService().trace(.{ .start = ref.vieworg, .end = point, .mins = @splat(0), .maxs = @splat(0), .slot = c.ENTITYNUM_NONE, .mask = c.MASK_SOLID });
    if (hit.start_solid or hit.all_solid or (1 - hit.fraction) * distance > 16) return;
    const half = @floor(@floor(distance) / 2);
    const alpha = std.math.clamp(1 - half / 512, 0, 1);
    if (alpha == 0) return;
    const model = try engine.config(game, @intCast(c.CS_MODELS + entity.modelindex));
    const sprites = @import("../../../../core/client/sprites.zig");
    const media = try sprites.register(model);
    const color: [4]u8 = .{ 255, 255, 255, @intFromFloat(alpha * 255) };
    sprites.drawPlane(media, 0, v.add(point, v.scale(v.normalize(delta), half)), 1 + alpha, false, v.scale(ref.viewaxis[1], -1), ref.viewaxis[2], color);
}
