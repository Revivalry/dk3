// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: what riders, bots and the pusher may ask about brush movers without naming
//! them. The mover classes answer (world_system_classes.zig `motion`: `ownsPart`, `pathPhase`).
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const motion = @import("../../game/server/world_system_classes.zig").motion;
/// A path platform's phase (a lift or cart following path corners).
pub const PathPhase = struct { moving: bool, teleporting: bool, name: []const u8 };
/// Whether a mover class drives this entity.
pub fn isMoverPart(world: *data.World, entity: ecs.Entity) bool {
    inline for (motion) |Class| if (@hasDecl(Class, "ownsPart") and Class.ownsPart(world, entity)) return true;
    return false;
}
/// Whether the owning class is currently moving this part.
pub fn isMoving(world: *data.World, entity: ecs.Entity) bool {
    inline for (motion) |Class| if (@hasDecl(Class, "movingPart") and Class.ownsPart(world, entity)) return Class.movingPart(world, entity);
    return false;
}
/// Sample the owning mover's current motion segment without changing it.
pub fn sample(world: *data.World, entity: ecs.Entity, now: i64) !data.Transform {
    var pose = (try world.get(entity, data.Transform)).*;
    inline for (motion) |Class| if (@hasDecl(Class, "samplePart") and Class.ownsPart(world, entity)) {
        Class.samplePart(world, entity, now, &pose);
        break;
    };
    return pose;
}
/// The phase of a path platform, or null for anything else.
pub fn pathPhase(world: *data.World, entity: ecs.Entity) ?PathPhase {
    inline for (motion) |Class| if (@hasDecl(Class, "pathPhase")) {
        if (Class.pathPhase(world, entity)) |phase| return phase;
    };
    return null;
}
