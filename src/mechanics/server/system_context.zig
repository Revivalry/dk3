// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: what a class's world-system hooks receive (world_system_classes.zig,
//! projection_classes.zig). The shared schedules run the hooks; classes own what they do.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const abi = @import("../../engine/abi.zig");
const ecs = @import("../../core/ecs/world.zig");
const Slots = @import("../../engine/slots.zig").Slots;
/// Map spawn: `worldSpawn(*const Spawn) !void`.
pub const Spawn = struct {
    allocator: std.mem.Allocator,
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    now: i64,
};
/// One server frame: `worldPrepare`, `worldMove`, `worldFinish`, `worldArrive` and `worldStep`.
pub const Step = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    targets: *@import("targets.zig").Router,
    actors: *const @import("actors.zig").Actors,
    table: *const @import("../domain/weapons.zig").Table,
    now: i64,
    elapsed: u32,
};
/// Movers that reached their destination this frame (`worldFinish`), whose targets fire next
/// (`worldArrive`).
pub const Arrivals = struct {
    entities: [ecs.max_entities]ecs.Entity = undefined,
    count: usize = 0,
    pub fn add(self: *Arrivals, entity: ecs.Entity) void {
        self.entities[self.count] = entity;
        self.count += 1;
    }
    pub fn slice(self: *const Arrivals) []const ecs.Entity {
        return self.entities[0..self.count];
    }
};
/// Projecting one restored or transferred entity: `project(*const Project) !bool`, true when the
/// class projected it.
pub const Project = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    systems: *const @import("world_systems.zig").State,
    entity: ecs.Entity,
    now: i64,
};
