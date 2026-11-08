// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: current weapon posture supplied by the wielder's movement owner.
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");

pub fn motion(world: *data.World, entity: ecs.Entity) !data.Player {
    if (world.get(entity, data.Player) catch null) |player| return player.*;
    const actor = try world.get(entity, data.Actor);
    return try @import("actor_classes/registry.zig").weaponMotion(@import("actor_catalog").entries[actor.definition].kind, world, entity) orelse error.MissingWeaponMotion;
}

test "weapon releases sample current player crouch rather than launch-time posture" {
    const t = @import("std").testing;
    var world = data.World.init(t.allocator, 2);
    defer world.deinit();
    const entity = try world.create(null, .{data.Player{}});
    try t.expectEqual(@as(f32, 22), (try motion(&world, entity)).view_height);
    (try world.get(entity, data.Player)).ducked = true;
    (try world.get(entity, data.Player)).view_height = 12;
    try t.expect((try motion(&world, entity)).ducked);
    try t.expectEqual(@as(f32, 12), (try motion(&world, entity)).view_height);
}
