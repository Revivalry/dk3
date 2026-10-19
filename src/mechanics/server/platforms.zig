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
/// The phase of a path platform, or null for anything else.
pub fn pathPhase(world: *data.World, entity: ecs.Entity) ?PathPhase {
    inline for (motion) |Class| if (@hasDecl(Class, "pathPhase")) {
        if (Class.pathPhase(world, entity)) |phase| return phase;
    };
    return null;
}
