// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: laser_beam. Client presentation for the laser beam map entity class.
const c = @import("../../../../engine/abi.zig").c;
pub fn draw(entity: c.entityState_t, now: i32, ref: *const c.refdef_t) void {
    const origin = @import("../../../../engine/trajectory.zig").evaluate(entity.pos, now);
    // Supplied RF_BEAM presentation fixes the near radius to two, tapering to zero.
    @import("../../../../mechanics/client/beams.zig").tapered("dk3/fx/authored-laser", origin, entity.origin2, 2, 0, .{ 255, 255, 255, 128 }, ref);
    if (entity.frame > 0 and entity.frame <= 8) {
        var event = entity;
        event.pos.trBase = entity.origin2;
        event.origin2 = entity.angles2;
        @import("../../../../mechanics/client/actor_lasers.zig").sparks(event, now, .{ 255, 255, 255 }, @intCast(entity.frame));
    }
}
