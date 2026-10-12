// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: zeus. Weapon description: data, hooks and class rules for zeus.
const profiles = @import("../../../mechanics/policy/weapons/profiles.zig");
pub const id: u5 = 14;
pub const spec: profiles.Spec = .{
    .player_grip = .pistol,
    .combat = .owned,
    .ammo_class = "ammo_zeus", // zeus
    .ammo_pack = 1,
    .visual = .{ .color = .{ 0.2, 0.65, 1 } },
    .world_model = "models/e2/a_zeus.dkm",
    .animation = .{
        .view_model = "models/e2/w_zeuseye.dkm",
        .ready = "ready",
        .away = "away",
        .fire = "shoota",
        .fire_end = "shootc",
        .idle = .{ null, null, null },
        .raise_ms = 750,
        .drop_ms = 500,
    },
    .audio = .{
        .fire = "e2/we_zeusshoot.wav",
        .ready = "e2/we_zeusready.wav",
        .away = "e2/we_zeusaway.wav",
    },
};
pub const identity = .{ .classname = "weapon_zeus", .label = "Eye of Zeus", .episode = 2, .interval = 8000 };

const shot_rules = @import("../../../mechanics/policy/weapons/shot.zig");
pub const maximum_targets = 20;
pub const visual = .{ .flare = "models/global/e_flblue.sp2", .color = .{ 0.25, 0.45, 0.85 } };
pub const sounds = [_][:0]const u8{ "global/e_lightninga.wav", "global/e_lightningb.wav", "global/e_lightningc.wav" };
pub const Chain = struct {
    owner: u32,
    damage: f32,
    range: f32,
    ammo_cost: i32,
    ready_ms: i64,
    expires_ms: i64,
    phase: enum { pending, active, finished } = .pending,
    closed_ms: ?i64 = null,
    targets: [maximum_targets]u32 = @splat(0),
    count: u8 = 0,
    active: u8 = 0,
    zaps: u8 = 0,
    pub fn contains(self: Chain, target: u32) bool {
        for (self.targets[0..self.count]) |persistent_id| if (persistent_id == target) return true;
        return false;
    }
    pub fn reserve(self: *Chain, target: u32) bool {
        if (self.count == maximum_targets or self.contains(target)) return false;
        self.targets[self.count] = target;
        self.count += 1;
        self.active += 1;
        return true;
    }
    pub fn zap(self: *Chain) f32 {
        const amount = self.damage * (if (self.zaps > 15) @as(f32, 0.25) else if (self.zaps > 10) @as(f32, 0.5) else if (self.zaps > 5) @as(f32, 0.75) else 1);
        self.zaps += 1;
        self.active -|= 1;
        return amount;
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Chain, map: anytype) !void {
        try map.one(&self.owner);
        try map.many(&self.targets);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Chain, clock: anytype) !void {
        try clock.shift(&self.ready_ms);
        try clock.shift(&self.expires_ms);
        try clock.deadline(&self.closed_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Chain, check: anytype) !void {
        if (self.count > maximum_targets or self.active > self.count or self.zaps > self.count or @as(u16, self.active) + self.zaps > self.count or self.damage < 0 or self.damage > 1000000 or self.range <= 0 or self.range > 8192 or self.ammo_cost <= 0 or self.ammo_cost > 32767) return error.InvalidSavedZeus;
        if ((self.phase == .finished) != (self.closed_ms != null) or (self.phase == .pending and self.count != 0) or (self.phase == .finished and self.active != 0)) return error.InvalidSavedZeus;
        for (self.targets[0..self.count], 0..) |entity_id, i| {
            if (entity_id == 0 or entity_id == self.owner) return error.InvalidSavedZeus;
            for (self.targets[0..i]) |previous| if (previous == entity_id) return error.InvalidSavedZeus;
        }
        const owner = check.find(self.owner) orelse return error.InvalidSavedZeus;
        try owner.require(.{ "Player", "Weapons", "Health", "Binding" });
        try check.require(.{ "Random", "Binding" });
        if ((try check.get("Binding")).model != 0) return error.InvalidSavedZeus;
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
};
pub const Bolt = struct {
    owner: u32,
    chain: u32,
    source: u32,
    target: u32,
    born_ms: i64,
    next_ms: i64,
    phase: enum { spreading, zapping, fading } = .spreading,
    endpoint: [3]f32 = @splat(0),
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Bolt, map: anytype) !void {
        try map.fields(self, .{ "owner", "chain", "source", "target" });
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Bolt, clock: anytype) !void {
        try clock.shift(&self.born_ms);
        try clock.shift(&self.next_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Bolt, check: anytype) !void {
        const parent = check.find(self.chain) orelse return error.InvalidSavedZeusBolt;
        const chain = parent.get("Zeus") catch return error.InvalidSavedZeusBolt;
        // Check bounds before invoking the class's bounded target-set operations.
        if (chain.count > maximum_targets or chain.owner != self.owner or !chain.contains(self.target)) return error.InvalidSavedZeusBolt;
        const source = check.find(self.source) orelse return error.InvalidSavedZeusBolt;
        const target = check.find(self.target) orelse return error.InvalidSavedZeusBolt;
        try source.require(.{ "Health", "Binding" });
        try target.require(.{ "Health", "Binding" });
        try check.require(.{"Binding"});
        if (self.next_ms < self.born_ms or (try check.get("Binding")).model != 0) return error.InvalidSavedZeusBolt;
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
};
pub fn releaseDelay(factor: f32) u32 {
    return @intFromFloat(1750 / factor);
}
pub fn predictionShot(controller: anytype) shot_rules.Shot {
    var result = shot_rules.standard(controller);
    // Gold charges only after a target is found (or on a deathmatch miss).
    if (controller.ps.ammo[id] >= result.cost) result.cost = 0;
    result.duration_ms = controller.scaled(1750) + 5000;
    return result;
}

pub fn update(controller: anytype) void {
    controller.automatic(@This());
}

test "Zeus graph never revisits a target and attenuates damage by consumed zaps" {
    const std = @import("std");
    var chain: Chain = .{ .owner = 99, .damage = 300, .range = 1500, .ammo_cost = 1, .ready_ms = 1750, .expires_ms = 7250 };
    try std.testing.expect(chain.reserve(1));
    try std.testing.expect(!chain.reserve(1));
    for (2..21) |target| try std.testing.expect(chain.reserve(@intCast(target)));
    try std.testing.expect(!chain.reserve(21));
    for (0..20) |index| {
        const expected: f32 = if (index > 15) 75 else if (index > 10) 150 else if (index > 5) 225 else 300;
        try std.testing.expectEqual(expected, chain.zap());
    }
    try std.testing.expectEqual(@as(u8, 0), chain.active);
    try std.testing.expectEqual(@as(u8, 20), chain.zaps);
    try std.testing.expect(!chain.reserve(1));
    try std.testing.expectEqual(@as(u32, 875), releaseDelay(2));
}
