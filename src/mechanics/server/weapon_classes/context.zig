// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the contexts the weapon systems hand to server weapon class hooks.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const data = @import("../../../game/domain/components.zig");
const ecs = @import("../../../core/ecs/world.zig");
const abi = @import("../../../engine/abi.zig");
const weapons = @import("../../domain/weapons.zig");
const v = @import("../../../core/domain/vector.zig");
const Slots = @import("../../../engine/slots.zig").Slots;

/// A shot being fired or launched.
pub const Fire = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    owner: ecs.Entity,
    shot: weapons.Fired,
    table: *const weapons.Table,
    now: i64,
};
/// A client command for the weapon its holder has in hand.
pub const Command = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    holder: ecs.Entity,
    now: i64,
};
/// One weapon-system tick.
pub const Step = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    table: *const weapons.Table,
    now: i64,
};
/// A projectile about to enter the world: its class may prepare its flight state.
pub const Flight = struct {
    projectile: *data.Projectile,
    start: v.Vec3,
    velocity: v.Vec3,
    /// The weapon's supplied speed.
    speed: f32,
    seed: u32,
};
/// A projectile being published.
pub const Projection = struct {
    world: *data.World,
    entity: ecs.Entity,
    projections: []abi.EntityProjection,
    projectile: *const data.Projectile,
    state: *abi.c.entityState_t,
    shared: *abi.c.entityShared_t,
    now: i64,
};

/// A blast that lingers where it bursts and comes back on the party: bots fire the weapon only
/// when a route names it, back out to `clear` from a lingering blast within `hold`, and wait.
pub const Lingering = struct { clear: f32, hold: f32 };
/// Entity fields of a weapon's projections that carry slot references, which resident-world
/// mirroring remaps.
pub const Links = struct {
    other: bool = false,
    other2: bool = false,
    /// `origin2[0..2]` carry two more slots.
    origin2: bool = false,
};
/// The persistent identities a projectile's projection refers to.
pub const Linked = union(enum) {
    /// `otherEntityNum` is the owner.
    owner: u32,
    /// `otherEntityNum`, `otherEntityNum2` and `origin2[0..2]` are these four (0 for none).
    targets: [4]u32,
};
/// One weapon entity's line for region probes (`regionProbe`).
pub const RegionProbe = struct { kind: []const u8, owner: u32, text: []const u8 };
