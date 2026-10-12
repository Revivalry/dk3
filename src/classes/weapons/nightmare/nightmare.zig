// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: nightmare. Weapon description: data, hooks and class rules for nightmare.
const profiles = @import("../../../mechanics/policy/weapons/profiles.zig");
pub const id: u5 = 20;
pub const spec: profiles.Spec = .{
    .player_grip = .pistol, // nightmare
    .combat = .owned,
    .credited_kill_ammo = 1,
    .visual = .{ .projectile_model = "models/e3/we_nnreaper.dkm", .color = .{ 0.9, 0.2, 1 } },
    .world_model = "models/e3/a_nmare.dkm",
    .animation = .{
        .view_model = "models/e3/w_nmare.dkm",
        .ready = "ready",
        .away = "away",
        .fire = "shoot",
        .idle = .{ "amba", "ambb", "ambc" },
        .raise_ms = 750,
        .drop_ms = 500,
    },
    .audio = .{
        .fire = "e3/we_chant5.wav",
        .ready = "e3/we_nharreready.wav",
        .away = "e3/we_nharreaway.wav",
    },
};
pub const identity = .{ .classname = "weapon_nightmare", .label = "Nharre's Nightmare", .episode = 3, .interval = 90000 };

const shot_rules = @import("../../../mechanics/policy/weapons/shot.zig");
pub fn predictionShot(controller: anytype) shot_rules.Shot {
    var shot = shot_rules.standard(controller);
    shot.duration_ms = 90000;
    return shot;
}

pub const maximum_targets = 10;
pub const Phase = enum { casting, waiting, appearing, reaping, after };
pub const Ritual = struct {
    owner: u32,
    damage: f32,
    range: f32,
    born_ms: i64,
    next_ms: i64,
    phase_ms: i64,
    phase: Phase = .casting,
    targets: [maximum_targets]u32 = @splat(0),
    count: u8 = 0,
    cursor: u8 = 0,
    victim: ?u32 = null,
    previous_view_height: f32 = 22,
    pub fn mark(self: *Ritual, target: u32) bool {
        if (target == 0 or self.count == maximum_targets) return false;
        for (self.targets[0..self.count]) |previous| if (previous == target) return false;
        self.targets[self.count] = target;
        self.count += 1;
        return true;
    }
    pub fn advance(self: *Ritual, phase: Phase, now: i64, delay: i64) void {
        self.phase = phase;
        self.phase_ms = now;
        self.next_ms = now + delay;
    }
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Ritual, map: anytype) !void {
        try map.one(&self.owner);
        try map.many(&self.targets);
        try map.optional(&self.victim);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Ritual, clock: anytype) !void {
        try clock.shift(&self.born_ms);
        try clock.shift(&self.phase_ms);
        try clock.shift(&self.next_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Ritual, check: anytype) !void {
        if (self.count > maximum_targets or self.cursor > self.count or self.damage < 0 or self.damage > 1000000 or self.range <= 0 or self.range > 8192 or self.previous_view_height < -24 or self.previous_view_height > 64 or self.next_ms < self.phase_ms) return error.InvalidSavedNightmare;
        try check.require(.{"Binding"});
        if ((try check.get("Binding")).model != 0) return error.InvalidSavedNightmare;
        const owner = check.find(self.owner) orelse return error.InvalidSavedNightmare;
        try owner.require(.{ "Player", "Weapons", "Binding", "Health" });
        for (self.targets[0..self.count], 0..) |entity_id, index| {
            if (entity_id == 0 or @import("std").mem.indexOfScalar(u32, self.targets[0..index], entity_id) != null) return error.InvalidSavedNightmare;
            if (check.find(entity_id)) |target| try target.require(.{ "Health", "Body", "Binding" });
        }
        if ((self.phase == .appearing or self.phase == .reaping) != (self.victim != null)) return error.InvalidSavedNightmare;
        if (self.victim) |entity_id| {
            if (self.cursor == 0 or self.targets[self.cursor - 1] != entity_id) return error.InvalidSavedNightmare;
            const target = check.find(entity_id) orelse return error.InvalidSavedNightmare;
            try target.require(.{ "Body", "Velocity", "Health", "Binding" });
            if ((try target.get("Body")).motion_owner != try check.id()) return error.InvalidSavedNightmare;
            if (target.get("Player") catch null) |victim_player| if (victim_player.mode != .frozen and victim_player.mode != .dead) return error.InvalidSavedNightmare;
        }
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
    /// Whether this state legitimately owns the saved motion of entity `victim` (snapshot.zig).
    pub fn holdsSaved(self: *const Ritual, victim: u32) bool {
        return self.victim == victim;
    }
};
pub fn searchDelay(factor: f32) i64 {
    // Supplied shoot frames 119..183: wait for last-2, sampled every 100 ms, then search.
    return @as(i64, @intFromFloat(@ceil(3100 / factor / 100))) * 100 + 100;
}
pub const strike_ms: i64 = 4200; // Supplied reaper ataka 0..43 at 10 fps, damage at last-1.
pub const visual = .{ .pentagram = "models/e3/we_nnpent.dkm", .flame = "models/global/we_nharref.sp2" };
pub const sounds = .{ .appear = "e3/we_reaperappear2.wav", .wind = "e3/we_nharrewind.wav", .strike = "e3/we_reaperattack2.wav" };

pub fn update(controller: anytype) void {
    controller.automatic(@This());
}

test "Nightmare bounds the marked list and derives search and strike time from supplied frames" {
    const std = @import("std");
    var ritual: Ritual = .{ .owner = 1, .damage = 300, .range = 2000, .born_ms = 0, .next_ms = 3200, .phase_ms = 0 };
    for (2..12) |target| try std.testing.expect(ritual.mark(@intCast(target)));
    try std.testing.expect(!ritual.mark(12));
    try std.testing.expect(!ritual.mark(2));
    try std.testing.expectEqual(@as(i64, 3200), searchDelay(1));
    try std.testing.expectEqual(@as(i64, 1700), searchDelay(2));
    ritual.advance(.reaping, 1000, strike_ms);
    try std.testing.expectEqual(@as(i64, 5200), ritual.next_ms);
}
