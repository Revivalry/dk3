// SPDX-License-Identifier: GPL-2.0-or-later
//! Presentation transitions consume shared controller state and class-owned cues.
const std = @import("std");
const profiles = @import("profiles.zig");
const controller = @import("weapon_state.zig");
pub const Phase = enum { ready, away, fire, settle, reload, idle };
pub const Cue = struct { pose: [:0]const u8, sound: ?[:0]const u8 = null, phase: Phase, rate: u16 = 20, loop: bool = false };
pub const Input = struct { weapon: u5, state: i32, sequence: i32, reloading: bool, attack_factor: f32 = 1, now_ms: i64, fire_pose: ?[:0]const u8 = null, fire_rate: ?u16 = null, finish_ms: ?i64 = null, still: bool = true, has_ammo: bool = true };
pub const State = struct {
    incarnation: ?u16 = null,
    weapon: u5 = 0,
    state: i32 = controller.ready,
    phase: Phase = .ready,
    ended_ms: i64 = 0,
    fire_serial: ?u32 = null,
    fire_weapon: u5 = 0,
    fire_ms: i64 = -1000,
    pending_fire: bool = false,
    /// Gold playerHook.ambient_time: the earliest moment the next idle may start.
    ambient_ms: i64 = 0,
    random: u32 = 0x9e3779b9,
    pub fn synchronize(self: *State, incarnation: u16) void {
        if (self.incarnation != incarnation) self.* = .{ .incarnation = incarnation };
    }
    pub fn noteFire(self: *State, weapon: u5, serial: u32, now: i64) void {
        if (self.fire_serial) |prior| {
            // Player event sequences have a 16-bit wire representation. Both
            // predicted full counters and decoded echoes use this same order.
            const difference = @as(u16, @truncate(serial)) -% @as(u16, @truncate(prior));
            if (difference == 0 or difference >= 0x8000) return;
        }
        self.fire_serial = serial;
        self.fire_weapon = weapon;
        self.fire_ms = now;
        self.pending_fire = true;
    }
    pub fn update(self: *State, spec: profiles.Spec, input: Input) ?Cue {
        const changed_weapon = self.weapon != input.weapon;
        const changed_state = self.state != input.state;
        self.weapon = input.weapon;
        self.state = input.state;
        var cue: ?Cue = null;
        if (input.reloading and (changed_weapon or self.phase != .reload)) {
            if (spec.animation.reload) |name| cue = .{ .pose = name, .sound = spec.audio.reload, .phase = .reload };
        } else if ((self.pending_fire and self.fire_weapon == input.weapon) or (spec.animation.fire_loop and input.state == controller.firing and (changed_weapon or self.phase != .fire))) {
            var pose = spec.animation.fire;
            if (input.sequence >= 0 and input.sequence < spec.animation.fire_variants.len) if (spec.animation.fire_variants[@intCast(input.sequence)]) |name| {
                pose = name;
            };
            if (input.fire_pose) |name| pose = name;
            if (changed_weapon or self.phase != .fire or (!spec.animation.fire_loop and (!spec.animation.hold_fire or input.now_ms >= self.ended_ms))) {
                cue = .{ .pose = pose, .phase = .fire, .rate = @intFromFloat(std.math.clamp(@as(f32, @floatFromInt(input.fire_rate orelse spec.animation.rate)) * (if (spec.animation.scale_fire_rate) input.attack_factor else 1), 1, 240)), .loop = spec.animation.fire_loop };
            }
        } else if (changed_weapon or (changed_state and input.state == controller.raising)) {
            cue = .{ .pose = spec.animation.ready, .sound = spec.audio.ready, .phase = .ready };
            // Gold weapon selection: looping idles begin at once, others after a rest.
            self.ambient_ms = if (spec.animation.idle_loop) input.now_ms else input.now_ms + self.rest();
        } else if (changed_state and input.state == controller.dropping) {
            cue = .{ .pose = spec.animation.away, .sound = spec.audio.away, .phase = .away };
        } else if ((input.state == controller.ready or input.finish_ms != null) and self.phase == .fire and spec.animation.fire_end != null) {
            cue = .{ .pose = spec.animation.fire_end.?, .phase = .settle };
        } else if (input.state == controller.ready and input.now_ms >= self.ended_ms) {
            cue = self.ambient(spec, input);
        }
        self.pending_fire = false;
        if (cue) |value| self.phase = value.phase;
        return cue;
    }
    /// The view extends the rest after an idle cue by the sequence it resolved.
    pub fn started(self: *State, cue: Cue, duration_ms: i64) void {
        if (cue.phase == .idle and !cue.loop) self.ambient_ms += duration_ms;
    }
    /// Gold winfoGenericCommand "ambient", run by the client think once the
    /// previous animation has finished.
    fn ambient(self: *State, spec: profiles.Spec, input: Input) ?Cue {
        const poses = spec.animation.idle;
        if (spec.animation.idle_loop) {
            // Gold venomousCommand: each still cycle may hiss one of its ambient sounds.
            const sound = if (self.phase == .idle and input.still and self.next() % 100 >= 55) spec.audio.idle[self.next() % 3] else null;
            if (self.phase == .idle and !input.still) return null;
            return .{ .pose = poses[0] orelse return null, .sound = sound, .phase = .idle, .loop = true };
        }
        if (!input.still or input.now_ms < self.ambient_ms) return null;
        if (spec.animation.idle_needs_ammo and !input.has_ammo) {
            self.ambient_ms = input.now_ms + self.rest();
            return null;
        }
        // Gold counts variants by the highest populated slot and draws uniformly.
        var count: u32 = poses.len;
        while (count > 0 and poses[count - 1] == null) count -= 1;
        if (count == 0) {
            self.ambient_ms = std.math.maxInt(i64);
            return null;
        }
        const index = self.next() % count;
        self.ambient_ms = input.now_ms + self.rest();
        return .{ .pose = poses[index] orelse return null, .sound = spec.audio.idle[index], .phase = .idle };
    }
    fn rest(self: *State) i64 {
        return 2000 + self.next() % 6001;
    }
    fn next(self: *State) u32 {
        self.random ^= self.random << 13;
        self.random ^= self.random >> 17;
        self.random ^= self.random << 5;
        return self.random;
    }
};
test "predicted shots deduplicate server echoes and finite attacks rest before idling" {
    var state: State = .{};
    const spec: profiles.Spec = .{ .player_grip = .pistol, .animation = .{ .ready = "ready", .away = "away", .fire = "fire", .idle = .{ "idle", null, null }, .reload = "reload" } };
    var input: Input = .{ .weapon = 21, .state = controller.ready, .sequence = 0, .reloading = false, .now_ms = 0 };
    try std.testing.expectEqual(Phase.ready, state.update(spec, input).?.phase);
    state.noteFire(21, 1, 50);
    input.state = controller.firing;
    input.now_ms = 60;
    try std.testing.expectEqual(Phase.fire, state.update(spec, input).?.phase);
    state.ended_ms = 500;
    state.noteFire(21, 1, 100);
    try std.testing.expect(state.update(spec, input) == null);
    try std.testing.expectEqual(@as(i64, 50), state.fire_ms);
    input.state = controller.ready;
    input.now_ms = 499;
    try std.testing.expect(state.update(spec, input) == null);
    input.now_ms = 500;
    try std.testing.expect(state.update(spec, input) == null);
    input.now_ms = 8000;
    try std.testing.expectEqual(Phase.idle, state.update(spec, input).?.phase);
    input.reloading = true;
    input.state = controller.dropping;
    try std.testing.expectEqual(Phase.reload, state.update(spec, input).?.phase);
    try std.testing.expect(state.update(spec, input) == null);
}

test "burst shots retain their pose and rotary fire spins down after release" {
    var view: State = .{};
    var input: Input = .{ .weapon = 4, .state = controller.firing, .sequence = 0, .reloading = false, .now_ms = 100 };
    const spec: profiles.Spec = .{ .player_grip = .rifle, .animation = .{ .fire = "shoot", .hold_fire = true } };
    view.noteFire(4, 1, 100);
    try std.testing.expectEqual(Phase.fire, view.update(spec, input).?.phase);
    view.ended_ms = 1900;
    view.noteFire(4, 2, 370);
    input.now_ms = 370;
    try std.testing.expect(view.update(spec, input) == null);
    const rotary: profiles.Spec = .{ .player_grip = .rifle, .animation = .{ .fire = "shoota", .fire_loop = true, .fire_end = "spdn" } };
    input.weapon = 22;
    try std.testing.expect(view.update(rotary, input).?.loop);
    input.state = controller.ready;
    try std.testing.expectEqual(Phase.settle, view.update(rotary, input).?.phase);
}

test "respawn accepts the first shot and wire wrap deduplicates predicted echoes" {
    var state: State = .{};
    state.synchronize(1);
    state.noteFire(1, 500, 1000);
    state.synchronize(2);
    state.noteFire(1, 0, 2000);
    try std.testing.expectEqual(@as(i64, 2000), state.fire_ms);
    state.synchronize(2);
    state.noteFire(1, 0, 2010);
    try std.testing.expectEqual(@as(i64, 2000), state.fire_ms);
    state.synchronize(3);
    state.noteFire(1, 65535, 3000);
    state.noteFire(1, 65536, 3010);
    state.pending_fire = false;
    state.noteFire(1, 0, 3020);
    try std.testing.expect(!state.pending_fire);
    state.noteFire(1, 1, 3030);
    try std.testing.expectEqual(@as(i64, 3030), state.fire_ms);
}

test "idles alternate at random once at rest, hold between, and looping idles persist in motion" {
    const spec: profiles.Spec = .{ .player_grip = .pistol, .animation = .{ .ready = "ready", .idle = .{ "amba", "ambb", null } }, .audio = .{ .idle = .{ "a.wav", "b.wav", null } } };
    var state: State = .{};
    var input: Input = .{ .weapon = 2, .state = controller.ready, .sequence = 0, .reloading = false, .now_ms = 0 };
    _ = state.update(spec, input).?;
    state.ended_ms = 500;
    var seen: [2]bool = .{ false, false };
    var now: i64 = 500;
    for (0..32) |_| {
        input.now_ms = now;
        input.still = false;
        try std.testing.expect(state.update(spec, input) == null);
        input.still = true;
        const cue = state.update(spec, input) orelse {
            now += 250;
            continue;
        };
        try std.testing.expect(cue.phase == .idle and !cue.loop);
        const index: usize = if (std.mem.eql(u8, cue.pose, "amba")) 0 else 1;
        try std.testing.expectEqualStrings(spec.audio.idle[index].?, cue.sound.?);
        seen[index] = true;
        state.ended_ms = now + 400;
        state.started(cue, 400);
        try std.testing.expect(state.ambient_ms >= now + 2400 and state.ambient_ms <= now + 8400);
        input.now_ms = now + 400;
        try std.testing.expect(state.update(spec, input) == null);
        now = state.ambient_ms;
    }
    try std.testing.expect(seen[0] and seen[1]);
    const looping: profiles.Spec = .{ .player_grip = .rifle, .animation = .{ .ready = "ready", .idle = .{ "amba", null, null }, .idle_loop = true } };
    state = .{};
    input = .{ .weapon = 13, .state = controller.ready, .sequence = 0, .reloading = false, .now_ms = 0, .still = false };
    _ = state.update(looping, input).?;
    state.ended_ms = 600;
    input.now_ms = 600;
    try std.testing.expect(state.update(looping, input).?.loop);
    try std.testing.expect(state.update(looping, input) == null);
    const silent: profiles.Spec = .{ .player_grip = .rifle, .animation = .{ .ready = "ready" } };
    state = .{};
    input.still = true;
    _ = state.update(silent, input).?;
    input.now_ms = 20000;
    try std.testing.expect(state.update(silent, input) == null);
}
