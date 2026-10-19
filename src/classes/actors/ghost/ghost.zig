// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: ghost. Kage's summoned actor wakes, seeks, strikes once and fades.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .ghost, .traits = .{ .attack = .sequence, .bloodless = true, .remains = .{ .never = true, .no_blood = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "ghost";
pub const attacks = [_][]const u8{"ataka"};
const std = @import("std");
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { dormant, waking, chase, attack, fading } = .dormant,
    owner: u32 = 0,
    alpha: f32 = 0,
    started_ms: i64 = 0,
    sound_ready_ms: i64 = 0,
    pub fn fade(self: *State, now: i64) void {
        if (self.phase == .fading) return;
        self.phase = .fading;
        self.started_ms = now;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        if (self.phase == .dormant) try saved.active(&self.started_ms, delta) else try saved.shift(&self.started_ms, delta);
        try saved.active(&self.sound_ready_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, check: saved.Check) !void {
        if (!std.math.isFinite(self.alpha) or self.alpha < 0 or self.alpha > 1) return error.InvalidSavedActor;
        // A ghost summoned by Kage keeps its summoner.
        if (check.owned and self.owner != 0) if (check.kindOf(self.owner) catch return error.InvalidSavedActor) |summoner| if (summoner != .kage) return error.InvalidSavedActor;
    }
    /// Maps saved persistent ids onto the restored world.
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.owner);
    }
};
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_ghost", .kind = .ghost, .run = "flya", .death = "flya" },
};
