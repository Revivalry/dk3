// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: wyndrax. Wyndrax owns recharge and ammunition; its attack wisps also serve Garroth.
/// The persistent attack payloads this class launches, by saved tag (domain/actor_attack.zig).
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .wyndrax, .traits = .{ .sidekicks = .refuse_melee, .attack = .sequence } }};
/// Pain: the reference's single 5% roll (`hita`).
pub const pain_chance = 5;
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "wyndrax";
pub const attacks = [_][]const u8{ "charged", "wispa", "chargea", "wispb", "wispc" };
const std = @import("std");
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { combat, powerup, approach_charge, find_swarm, approach_swarm, collect, retreat, wander } = .combat,
    ammo: u8 = 3,
    charged: bool = true,
    source: u32 = 0,
    charge: u32 = 0,
    destination: [3]f32 = @splat(0),
    until_ms: i64 = 0,
    running: bool = true,
    start_position: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.until_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (!saved.bounded(&self.destination, std.math.floatMax(f32)) or !saved.bounded(&self.start_position, std.math.floatMax(f32))) return error.InvalidSavedActor;
    }
    /// Maps saved persistent ids onto the restored world.
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.fields(self, .{ "source", "charge" });
    }
};
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_wyndrax", .kind = .wyndrax },
};
