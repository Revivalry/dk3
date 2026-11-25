// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Actor death outputs and dynamic death drops.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const Actors = @import("actors.zig").Actors;
const prop = @import("properties.zig");

pub fn death(actors: *Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *@import("targets.zig").Router, entity: ecs.Entity, now: i64) !void {
    const object = (try world.get(entity, data.MapObject)).*;
    var pose = (try world.get(entity, data.Transform)).*;
    const identity = try world.persistentId(entity);
    if (prop.text(object, "deathtarget")) |name| try router.fireNamed(world, slots, projections, name, entity, identity, now);
    if (prop.text(object, "spawnname")) |classname| {
        if (classname.len == 0) return;
        pose.position[2] += 0.03125;
        if (@import("actor_catalog").find(classname) != null) {
            _ = try actors.spawnDynamic(world, slots, projections, classname, pose.position, pose.angles, now);
        } else {
            if (std.mem.startsWith(u8, classname, "monster_")) return error.UnknownActorClass;
            _ = try @import("items.zig").spawnDynamic(world, slots, projections, classname, pose, now, actors.episode);
        }
    }
}
