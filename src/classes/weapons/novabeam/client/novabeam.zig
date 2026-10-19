// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: novabeam. Client adapter: the beam from muzzle to flare.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const registry = @import("../../../../mechanics/client/weapon_classes/registry.zig");
pub const description = @import("weapon_catalog").classes.novabeam;
pub fn drawEffect(effect: registry.Effect) !void {
    const entity = effect.entity;
    const ref = effect.ref;
    if (entity.frame != 1) return;
    const visual = description.visual;
    var start = entity.pos.trBase;
    if (entity.otherEntityNum == effect.client) {
        const offset = description.muzzle;
        start = v.add(ref.vieworg, v.add(v.scale(ref.viewaxis[0], offset[1]), v.add(v.scale(ref.viewaxis[1], -offset[0]), .{ 0, 0, offset[2] - 22 })));
    }
    const alpha: u8 = @intFromFloat(std.math.clamp(entity.angles2[0], 0, 1) * 255);
    @import("../../../../mechanics/client/beams.zig").draw("dk3/fx/novabeam", start, entity.origin2, 4, .{ 255, 255, 255, alpha }, ref);
    const sprites = @import("../../../../core/client/sprites.zig");
    sprites.draw(try sprites.register(visual.muzzle), 0, start, 0.25, true, ref);
    sprites.draw(try sprites.register(visual.flare), 0, entity.origin2, 0.3, true, ref);
    for ([_]v.Vec3{ start, entity.origin2 }, [_]f32{ 200, 150 }) |position, radius| _ = engine.gateway.call(c.CG_R_ADDLIGHTTOSCENE, .{ &position, engine.floatArg(radius), engine.floatArg(0.8), engine.floatArg(0.4), engine.floatArg(0.2) });
}
/// The beam's last frame ends the first-person discharge.
pub fn viewEnd(entity: c.entityState_t) ?i64 {
    return if (entity.frame == 3) entity.time2 else null;
}
