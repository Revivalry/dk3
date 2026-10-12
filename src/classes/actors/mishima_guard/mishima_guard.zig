// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: mishima_guard. Guard-owned eight-round pistol cycle. Times are simulation milliseconds.
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .mishima_guard, .traits = .{ .pain_clips = true } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "guard";
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc" };
pub const reload_animation = "reload";
/// Wandering walks; every other move runs.
pub const walk_animation = "walka";
pub const reload_sound = "global/i_scammo.wav";
pub const reload_sound_frame: u16 = 15;
/// mishimaguard_pain: ai_generic_pain_handler with AI_InitMonster's default
/// chance; only a hit of `pain_limit` or more plays "hita".
pub const pain_chance: u8 = 75;
/// The neural guard was sculpted without his pistol: the client draws a pistol model in his right
/// hand (`tag_weapon`, a frame +X forward and +Z up); the original model carries its own gun.
pub const render_tag = 10045;
pub const pistol_model = "models/e4/a_glock.dkm";
/// The model's axes in the hand frame: barrel forward, handle down, flat side left.
pub const pistol_axes = [3][3]f32{ .{ 0.961, 0, -0.280 }, .{ -0.280, 0, -0.961 }, .{ 0, 1, 0 } };
/// Where the hand closes on the handle, in the model's own coordinates.
pub const pistol_grip = [3]f32{ -1.0, 1.5, 2.2 };
pub const pain_limit: i32 = 35;
pub const Phase = enum { ready, firing, reloading, recovering };
/// How the guard shoots. `cycle`: the eight-round pistol cycle (mishimaguard attack). `cover`: from
/// cover (AI_MishimaguardTakeCoverAttack), one `ataka` shot per `cover_cooldown_ms`, using no
/// rounds.
pub const Style = enum { cycle, cover };
pub const cover_cooldown_ms: i64 = 2000;
pub const Timing = struct { attack_ms: [3]i64, strike_ms: [3]i64, reload_ms: i64, reload_sound_ms: i64 };
/// `blocked`: the fire frame came without a clear shot; the guard side-steps.
pub const Events = struct { fire: bool = false, reload_sound: bool = false, blocked: bool = false };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: Phase = .ready,
    rounds: u8 = 8,
    pose: u8 = 0,
    started_ms: i64 = 0,
    ready_ms: i64 = 0,
    fired: bool = false,
    sounded_reload: bool = false,
    random: u32 = 1,
    pub fn fraction(self: *State) f32 {
        self.random = self.random *% 1664525 +% 1013904223;
        return @as(f32, @floatFromInt(self.random >> 8)) / 16777216;
    }
    pub fn tick(self: *State, now: i64, clear_shot: bool, timing: Timing, style: Style) Events {
        var events: Events = .{};
        switch (self.phase) {
            .firing => {
                if (!self.fired and now >= self.started_ms + timing.strike_ms[self.pose]) {
                    self.fired = true;
                    if (clear_shot and (style == .cover or self.rounds > 0)) {
                        if (style == .cycle) self.rounds -= 1;
                        events.fire = true;
                    } else events.blocked = !clear_shot;
                }
                if (now >= self.started_ms + timing.attack_ms[self.pose]) self.phase = .ready;
            },
            .reloading => {
                if (!self.sounded_reload and now >= self.started_ms + timing.reload_sound_ms) {
                    self.sounded_reload = true;
                    events.reload_sound = true;
                }
                if (now >= self.started_ms + timing.reload_ms) {
                    self.rounds = 8;
                    self.ready_ms = now + 500 + @as(i64, @intFromFloat(self.fraction() * 1000));
                    self.phase = .recovering;
                }
            },
            .recovering => if (now >= self.ready_ms) {
                self.phase = .ready;
            },
            .ready => {
                if (style == .cover) {
                    if (clear_shot and now >= self.ready_ms) {
                        self.pose = 0;
                        self.started_ms = now;
                        self.ready_ms = now + cover_cooldown_ms;
                        self.phase = .firing;
                        self.fired = false;
                    }
                } else if (self.rounds == 0) {
                    self.phase = .reloading;
                    self.started_ms = now;
                    self.sounded_reload = false;
                } else if (clear_shot and now >= self.ready_ms) {
                    self.pose = if (self.rounds % 4 == 0) @intFromFloat(self.fraction() * 3) else 0;
                    self.started_ms = now;
                    self.ready_ms = now + 200 + @as(i64, @intFromFloat(self.fraction() * 1000));
                    self.phase = .firing;
                    self.fired = false;
                }
            },
        }
        return events;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.started_ms, delta);
        try saved.active(&self.ready_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (self.pose >= 3 or self.rounds > 8) return error.InvalidSavedActor;
    }
};
test "guard fires eight rounds, reloads once, and cannot fire through a blocked shot" {
    const timing: Timing = .{ .attack_ms = .{ 600, 600, 700 }, .strike_ms = .{ 100, 100, 100 }, .reload_ms = 2400, .reload_sound_ms = 1500 };
    var state: State = .{};
    var fired: usize = 0;
    var reloads: usize = 0;
    var now: i64 = 0;
    while (now < 20000 and fired < 9) : (now += 50) {
        const events = state.tick(now, true, timing, .cycle);
        fired += @intFromBool(events.fire);
        reloads += @intFromBool(events.reload_sound);
        if (events.reload_sound) try std.testing.expectEqual(@as(usize, 8), fired);
    }
    try std.testing.expectEqual(@as(usize, 9), fired);
    try std.testing.expectEqual(@as(usize, 1), reloads);
    state = .{};
    _ = state.tick(0, true, timing, .cycle);
    const blocked = state.tick(100, false, timing, .cycle);
    try std.testing.expect(!blocked.fire and blocked.blocked);
    try std.testing.expectEqual(@as(u8, 8), state.rounds);
}
test "from cover the guard fires ataka once per two seconds and spends no rounds" {
    const timing: Timing = .{ .attack_ms = .{ 600, 600, 700 }, .strike_ms = .{ 100, 100, 100 }, .reload_ms = 2400, .reload_sound_ms = 1500 };
    var state: State = .{ .rounds = 1 };
    var shots: [4]i64 = undefined;
    var fired: usize = 0;
    var now: i64 = 0;
    while (now <= 6100) : (now += 50) {
        if (state.tick(now, true, timing, .cover).fire) {
            shots[fired] = now;
            fired += 1;
        }
        try std.testing.expectEqual(@as(u8, 0), state.pose);
    }
    try std.testing.expectEqual(@as(usize, 4), fired);
    try std.testing.expectEqual(@as(i64, 2000), shots[1] - shots[0]);
    try std.testing.expectEqual(@as(u8, 1), state.rounds);
    try std.testing.expect(state.phase != .reloading);
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_mishimaguard", .kind = .mishima_guard },
};
