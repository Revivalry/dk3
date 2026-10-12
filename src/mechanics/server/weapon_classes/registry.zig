// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: maps weapon ids to their server class adapters and dispatches the hooks.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
//!
//! An adapter declares `pub const description`, its weapon description, and only the hooks it
//! needs. Weapons without an adapter use the shared combat policies alone.
//!
//! | Hook | Default |
//! |---|---|
//! | `fire(*Fire) !void` | required by the `.owned` combat policy |
//! | `fire_sound: bool` | true: the shared fire sound plays after `fire` |
//! | `launch(*Fire) !void` | the shared projectile spawn |
//! | `prepareFlight(*Flight) void` | nothing extra |
//! | `seeded: bool` | false: the projectile gets no random stream |
//! | `publishProjectile(*Projection) !bool` | false: the shared projectile projection |
//! | `decorateProjectile(*Projection) !void` | nothing extra |
//! | `step(*Step) !void` | none; steps run in adapter order |
//! | `missile_links: Links` / `effect_links: Links` | no slot references |
//! | `linked(*const Projectile, bool effect, i64) ?Linked` | none |
//! | `lingering: Lingering`, `lingersOn(*World, Entity) bool` | its blasts do not linger |
//! | `admitsDamage(*World, Entity, u5) bool` | every entity takes this weapon's damage |
//! | `holds(*World, Entity controller, u32 victim) bool` | its entities hold no victim frozen |
//! | `actionOwner(*World, Entity) ?u32` | its entities run no player's action |
//! | `actionSource(*World, Entity) ?u32` | an action entity originates at its owner |
//! | `actionInvolves(*World, Entity, u32) bool` | only its owner is involved |
//! | `removeAction(*World, *Slots, projections, Entity) !bool` | the shared removal |
//! | `effectOwner(*World, Entity) ?u32` / `effectSecond` | its effect entities name no slot |
//! | `probeBeam`/`probeArea`/`regionProbe` | its entities print nothing in probes |
//! | `command(*Command, []const u8) !bool` | no client commands |
const std = @import("std");
const catalog = @import("weapon_catalog");
const context = @import("context.zig");
pub const Fire = context.Fire;
pub const Command = context.Command;
pub const Step = context.Step;
pub const Flight = context.Flight;
pub const Projection = context.Projection;
pub const Links = context.Links;
pub const Linked = context.Linked;
pub const Lingering = context.Lingering;

const adapters = @import("../../../game/server/weapon_classes/classes.zig").adapters;
const owner: [@as(usize, catalog.count) + 1]?u8 = blk: {
    @setEvalBranchQuota(100_000);
    var table: [@as(usize, catalog.count) + 1]?u8 = @splat(null);
    for (adapters, 0..) |A, index| {
        if (!@hasDecl(A, "description")) @compileError(@typeName(A) ++ ": a weapon class adapter declares its description");
        if (table[A.description.id] != null) @compileError("weapon adapted twice: " ++ @typeName(A));
        table[A.description.id] = index;
    }
    for (catalog.weapons) |W| if (W.spec.combat == .owned and table[W.id] == null) @compileError(W.identity.classname ++ " fires through its class but has no server adapter");
    break :blk table;
};

pub fn fire(fired: *Fire) !void {
    switch (owner[fired.shot.weapon] orelse return error.MissingWeaponClass) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "fire")) adapters[i].fire(fired) else error.MissingWeaponClass,
        else => unreachable,
    }
}
pub fn fireSound(weapon: u5) bool {
    switch (owner[weapon] orelse return true) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "fire_sound")) adapters[i].fire_sound else true,
        else => unreachable,
    }
}
/// Launches a projectile through its class, or returns false for the shared spawn.
pub fn launch(fired: *Fire) !bool {
    switch (owner[fired.shot.weapon] orelse return false) {
        inline 0...adapters.len - 1 => |i| {
            if (!@hasDecl(adapters[i], "launch")) return false;
            try adapters[i].launch(fired);
            return true;
        },
        else => unreachable,
    }
}
pub fn prepareFlight(weapon: u5, flight: *Flight) void {
    switch (owner[weapon] orelse return) {
        inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], "prepareFlight")) adapters[i].prepareFlight(flight),
        else => unreachable,
    }
}
pub fn seeded(weapon: u5) bool {
    switch (owner[weapon] orelse return false) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "seeded")) adapters[i].seeded else false,
        else => unreachable,
    }
}
pub fn publishProjectile(weapon: u5, projection: *Projection) !bool {
    switch (owner[weapon] orelse return false) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "publishProjectile")) adapters[i].publishProjectile(projection) else false,
        else => unreachable,
    }
}
pub fn decorateProjectile(weapon: u5, projection: *Projection) !void {
    switch (owner[weapon] orelse return) {
        inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], "decorateProjectile")) try adapters[i].decorateProjectile(projection),
        else => unreachable,
    }
}
/// Which fields of a weapon's missile (`effect` false) or effect projection carry slots.
pub fn links(weapon: i32, effect: bool) Links {
    if (weapon <= 0 or weapon > catalog.count) return .{};
    switch (owner[@intCast(weapon)] orelse return .{}) {
        inline 0...adapters.len - 1 => |i| {
            const A = adapters[i];
            if (effect) return if (@hasDecl(A, "effect_links")) A.effect_links else .{};
            return if (@hasDecl(A, "missile_links")) A.missile_links else .{};
        },
        else => unreachable,
    }
}
/// The identities a projectile's projection refers to, if its class publishes any.
pub fn linked(projectile: *const @import("../../../game/domain/components.zig").Projectile, effect: bool, now: i64) ?Linked {
    switch (owner[projectile.weapon] orelse return null) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "linked")) adapters[i].linked(projectile, effect, now) else null,
        else => unreachable,
    }
}
/// The inventory bits of weapons whose blasts linger (`lingering`).
pub fn lingeringMask() i32 {
    var mask: i32 = 0;
    inline for (adapters) |A| if (@hasDecl(A, "lingering")) {
        mask |= @as(i32, 1) << A.description.id;
    };
    return mask;
}
/// The lingering blast an entity is, if any.
pub fn lingeringOf(world: *@import("../../../game/domain/components.zig").World, entity: @import("../../../core/ecs/world.zig").Entity) ?Lingering {
    inline for (adapters) |A| if (@hasDecl(A, "lingering")) if (A.lingersOn(world, entity)) return A.lingering;
    return null;
}
/// Whether an entity takes a weapon's damage: a weapon class may exempt its own entities.
pub fn admitsDamage(world: *@import("../../../game/domain/components.zig").World, entity: @import("../../../core/ecs/world.zig").Entity, weapon: u5) bool {
    inline for (adapters) |A| if (@hasDecl(A, "admitsDamage")) if (!A.admitsDamage(world, entity, weapon)) return false;
    return true;
}
/// A client command for the weapon in hand; false when it has none of that name.
/// Whether a weapon entity `controller` holds the entity with persistent id `victim` frozen.
pub fn holds(world: *@import("../../../game/domain/components.zig").World, controller: @import("../../../core/ecs/world.zig").Entity, victim: u32) bool {
    inline for (adapters) |A| if (@hasDecl(A, "holds")) {
        if (A.holds(world, controller, victim)) return true;
    };
    return false;
}
/// The player running the weapon action an entity carries, from its class.
pub fn actionOwner(world: *@import("../../../game/domain/components.zig").World, entity: @import("../../../core/ecs/world.zig").Entity) ?u32 {
    inline for (adapters) |A| if (@hasDecl(A, "actionOwner")) {
        if (A.actionOwner(world, entity)) |identity| return identity;
    };
    return null;
}
/// Where an action entity originates when not at its owner.
pub fn actionSource(world: *@import("../../../game/domain/components.zig").World, entity: @import("../../../core/ecs/world.zig").Entity) ?u32 {
    inline for (adapters) |A| if (@hasDecl(A, "actionSource")) {
        if (A.actionSource(world, entity)) |source| return source;
    };
    return null;
}
/// The identity whose slot a class's effect entity names in `otherEntityNum`.
pub fn effectOwner(world: *@import("../../../game/domain/components.zig").World, entity: @import("../../../core/ecs/world.zig").Entity) ?u32 {
    inline for (adapters) |A| if (@hasDecl(A, "effectOwner")) {
        if (A.effectOwner(world, entity)) |identity| return identity;
    };
    return null;
}
/// The identity whose slot a class's effect entity names in `otherEntityNum2`.
pub fn effectSecond(world: *@import("../../../game/domain/components.zig").World, entity: @import("../../../core/ecs/world.zig").Entity) ?u32 {
    inline for (adapters) |A| if (@hasDecl(A, "effectSecond")) {
        if (A.effectSecond(world, entity)) |identity| return identity;
    };
    return null;
}
/// Whether a class's action entity involves `identity` beyond its owner.
pub fn actionInvolves(world: *@import("../../../game/domain/components.zig").World, entity: @import("../../../core/ecs/world.zig").Entity, identity: u32) bool {
    inline for (adapters) |A| if (@hasDecl(A, "actionInvolves") and A.actionInvolves(world, entity, identity)) return true;
    return false;
}
/// Removes an action entity through its class; false when the shared removal applies.
pub fn removeAction(world: *@import("../../../game/domain/components.zig").World, slots: *@import("../../../engine/slots.zig").Slots, projections: []@import("../../../engine/abi.zig").EntityProjection, entity: @import("../../../core/ecs/world.zig").Entity) !bool {
    inline for (adapters) |A| if (@hasDecl(A, "removeAction")) {
        if (try A.removeAction(world, slots, projections, entity)) return true;
    };
    return false;
}
pub fn command(weapon: u5, commanding: *Command, name: []const u8) !bool {
    switch (owner[weapon] orelse return false) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "command")) adapters[i].command(commanding, name) else false,
        else => unreachable,
    }
}
/// Every weapon class's tick, in adapter order.
pub fn step(stepping: *Step) !void {
    inline for (adapters) |A| if (@hasDecl(A, "step")) try A.step(stepping);
}

test "owned combat weapons all have server adapters" {
    inline for (catalog.weapons) |W| if (W.spec.combat == .owned) try std.testing.expect(owner[W.id] != null);
}
