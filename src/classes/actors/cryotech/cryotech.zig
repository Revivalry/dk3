// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: cryotech. Cryotech spray timings and muzzle positions reviewed against the authored class.
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .cryotech, .traits = .{ .attack = .ground } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "cryotech";
/// Aidata: the freezing spray is weapon 2 and is the class's primary attack.
pub fn parseTuning(row: anytype, _: class_traits.Kind, definition: anytype) !void {
    definition.damage = try row.number("weapon2_base_damage", 0);
    definition.random_damage = try row.number("weapon2_random_damage", 0);
    definition.range = try row.number("weapon2_distance", 0);
    if (definition.damage < 0 or definition.random_damage < 0 or definition.range <= 0) return error.InvalidCryotechWeapon;
}
pub const attacks = [_][]const u8{ "bambb", "bambc" };
/// The reference's generic pain: 25% rolls, `hita` on the second roll for a hit of 35 or more.
pub const pain_chance = 25;
pub const pain_limit = 35;
pub const Event = struct { frame: u16, offset: [3]f32 };
pub const pulses = [_]Event{
    .{ .frame = 8, .offset = .{ 17.30, 27.28, 11.96 } },   .{ .frame = 10, .offset = .{ 12.44, 29.27, 14.44 } },
    .{ .frame = 12, .offset = .{ 6.15, 30.87, 16.48 } },   .{ .frame = 14, .offset = .{ 0.15, 31.36, 18.29 } },
    .{ .frame = 16, .offset = .{ -5.34, 30.82, 19.59 } },  .{ .frame = 18, .offset = .{ -8.84, 29.94, 19.62 } },
    .{ .frame = 20, .offset = .{ -11.23, 29.48, 17.42 } }, .{ .frame = 22, .offset = .{ -11.39, 29.53, 13.50 } },
};
pub const maintenance = [_]Event{
    .{ .frame = 0, .offset = .{ 9.16, 32.68, 9.67 } },   .{ .frame = 2, .offset = .{ 10.59, 34.30, 10.29 } },
    .{ .frame = 4, .offset = .{ 9.38, 33.97, 10.75 } },  .{ .frame = 6, .offset = .{ 9.94, 34.60, 10.54 } },
    .{ .frame = 8, .offset = .{ 10.34, 34.20, 10.59 } },
};
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    pulse: u4 = 0,
    ready_ms: i64 = 0,
    ambient_started: ?i64 = null,
    ambient_frame: u16 = 0,
    ambient_elapsed: i64 = -1,
    pub fn begin(self: *State, now: i64) void {
        self.pulse = 0;
        self.ready_ms = now + 3000;
    }
    pub fn next(self: *State, elapsed: i64, fps: u16) ?Event {
        if (self.pulse >= pulses.len) return null;
        const event = pulses[self.pulse];
        if (elapsed * fps < @as(i64, event.frame) * 1000) return null;
        self.pulse += 1;
        return event;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.ready_ms, delta);
        try saved.deadline(&self.ambient_started, delta);
    }
};
pub const Spray = struct {
    owner: u32,
    damage: f32,
    origin: [3]f32,
    angles: [3]f32,
    born_ms: i64,
    stepped_ms: i64,
    contacted: bool = false,
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Spray, map: anytype) !void {
        try map.one(&self.owner);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Spray, clock: anytype) !void {
        try clock.shift(&self.born_ms);
        try clock.shift(&self.stepped_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Spray, check: anytype) !void {
        try check.require(.{ "Transform", "Velocity", "Body", "Binding" });
        if (self.owner == 0 or self.damage < 0 or self.damage > 1000000 or self.stepped_ms < self.born_ms or self.stepped_ms > self.born_ms + 800) return error.InvalidSavedCryoSpray;
    }
};
pub const spray_speed: f32 = 250;
pub const spray_lifetime_ms: i64 = 800;
pub const render_tag = 10005;
test "a delayed Cryotech frame emits every crossed pulse exactly once" {
    var state: State = .{};
    state.begin(1000);
    try std.testing.expect(state.next(799, 10) == null);
    for (pulses[0..4]) |expected| try std.testing.expectEqual(expected, state.next(1400, 10).?);
    try std.testing.expect(state.next(1400, 10) == null);
    var restored = state;
    for (pulses[4..]) |expected| try std.testing.expectEqual(expected, restored.next(2900, 10).?);
    try std.testing.expect(restored.next(2900, 10) == null);
    try std.testing.expectEqual(@as(i64, 4000), restored.ready_ms);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_cryotech", .kind = .cryotech },
};
