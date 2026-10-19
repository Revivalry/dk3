// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Body poses retain each character's supplied grip and carrying sequences.
const animation = @import("../../../../core/domain/animation.zig");
const std = @import("std");
const catalog = @import("weapon_catalog");
pub const Playback = animation.Playback;
/// Gold sidekicks walk inside their run-follow distance and run beyond it
/// (AI_SelectWalkingAnimation / AI_SelectRunningAnimation, 200 and 400 u/s).
pub const Gait = enum { still, walk, run };
/// The motor's friction tail settles below `still_speed`; motion resumes
/// above `moving_speed`.
pub const still_speed: f32 = 16;
pub const moving_speed: f32 = 28;
/// Stop-and-go steering spikes must not flip the cycle every frame.
pub const switch_hold_ms: i64 = 250;
pub fn gait(horizontal_speed: f32, walk_speed: f32, run_speed: f32) Gait {
    if (horizontal_speed < still_speed) return .still;
    return if (horizontal_speed > runThreshold(walk_speed, run_speed)) .run else .walk;
}
fn runThreshold(walk_speed: f32, run_speed: f32) f32 {
    return if (walk_speed > 0 and walk_speed < run_speed) (walk_speed + run_speed) / 2 else run_speed * 0.75;
}
/// Speed bands with hysteresis; a walk/run change must also persist briefly.
pub const GaitFilter = struct {
    current: Gait = .still,
    candidate: Gait = .still,
    since_ms: i64 = 0,
    pub fn update(self: *GaitFilter, horizontal_speed: f32, walk_speed: f32, run_speed: f32, now: i64) Gait {
        const threshold = runThreshold(walk_speed, run_speed);
        const band = (run_speed - walk_speed) * 0.2;
        const wanted: Gait = switch (self.current) {
            .still => if (horizontal_speed <= moving_speed) .still else if (horizontal_speed > threshold) .run else .walk,
            .walk => if (horizontal_speed < still_speed) .still else if (horizontal_speed > threshold + band) .run else .walk,
            .run => if (horizontal_speed < still_speed) .still else if (horizontal_speed < threshold - band) .walk else .run,
        };
        if (wanted == self.current or wanted == .still or self.current == .still) {
            self.current = wanted;
            self.candidate = wanted;
            return wanted;
        }
        if (wanted != self.candidate) {
            self.candidate = wanted;
            self.since_ms = now;
        }
        if (now - self.since_ms >= switch_hold_ms) self.current = wanted;
        return self.current;
    }
};

test "companion cues share the published shot and jump clocks without restarting movement" {
    const poses: Set = .{
        .idle = @splat(.{ .first = 0, .last = 9 }),
        .run = @splat(.{ .first = 10, .last = 19 }),
        .walk = @splat(.{ .first = 80, .last = 89 }),
        .jump = @splat(.{ .first = 20, .last = 29 }),
        .attack = @splat(.{ .first = 30, .last = 39 }),
        .crouch = @splat(.{ .first = 40, .last = 49 }),
        .crouch_walk = @splat(.{ .first = 50, .last = 59 }),
        .crouch_attack = @splat(.{ .first = 60, .last = 69 }),
        .swim = .{ .first = 70, .last = 79 },
    };
    const firing = poses.select(0, .still, false, false, false, 500, 1000, 0, 1200);
    try std.testing.expectEqual(@as(u16, 32), firing.frame(1200));
    try std.testing.expectEqual(@as(i64, 1000), firing.started);
    try std.testing.expect(!firing.looping);
    const second = poses.select(0, .still, false, true, false, 500, 1500, 0, 1700);
    try std.testing.expectEqual(@as(u16, 62), second.frame(1700));
    try std.testing.expectEqual(@as(i64, 1500), second.started);
    const running = poses.select(0, .run, false, false, false, 500, 1000, 0, 1200);
    try std.testing.expectEqual(@as(u16, 12), running.frame(1200));
    try std.testing.expect(running.looping);
    const jumping = poses.select(0, .still, true, false, false, 500, 1000, 0, 1200);
    try std.testing.expectEqual(@as(u16, 27), jumping.frame(1200));
    try std.testing.expect(!jumping.looping);
    try std.testing.expectEqual(@as(u16, 82), poses.select(0, .walk, false, false, false, 500, null, 1000, 1200).frame(1200));
}

test "slow companion motion walks, fast motion runs and the friction tail idles" {
    try std.testing.expectEqual(Gait.still, gait(12, 200, 400));
    var filter: GaitFilter = .{};
    try std.testing.expectEqual(Gait.still, filter.update(22, 100, 300, 0));
    try std.testing.expectEqual(Gait.walk, filter.update(32, 100, 300, 50));
    try std.testing.expectEqual(Gait.walk, filter.update(19, 100, 300, 100));
    try std.testing.expectEqual(Gait.walk, filter.update(253, 100, 300, 150));
    try std.testing.expectEqual(Gait.walk, filter.update(110, 100, 300, 250));
    try std.testing.expectEqual(Gait.walk, filter.update(260, 100, 300, 300));
    try std.testing.expectEqual(Gait.run, filter.update(270, 100, 300, 560));
    try std.testing.expectEqual(Gait.still, filter.update(10, 100, 300, 600));
    try std.testing.expectEqual(Gait.walk, gait(120, 200, 400));
    try std.testing.expectEqual(Gait.walk, gait(290, 200, 400));
    try std.testing.expectEqual(Gait.run, gait(320, 200, 400));
    try std.testing.expectEqual(Gait.walk, gait(250, 0, 400));
}
pub const Set = struct {
    idle: [3]animation.Sequence,
    run: [3]animation.Sequence,
    walk: [3]animation.Sequence,
    jump: [3]animation.Sequence,
    attack: [3]animation.Sequence,
    crouch: [3]animation.Sequence,
    crouch_walk: [3]animation.Sequence,
    crouch_attack: [3]animation.Sequence,
    swim: ?animation.Sequence,
    pain: [3]?animation.Sequence = @splat(null),
    pub fn read(bytes: []const u8, carrying: bool) !Set {
        var result: Set = undefined;
        result.swim = if (carrying) null else try animation.find(bytes, "swim") orelse return error.MissingCompanionSwim;
        for (0..3) |grip| {
            var buffer: [32]u8 = undefined;
            const suffix = if (grip == 0) "" else if (grip == 1) "a" else "b";
            result.pain[grip] = try animation.find(bytes, if (grip == 2) "hitb" else "hita");
            result.idle[grip] = try animation.find(bytes, if (carrying) "amba" else try std.fmt.bufPrint(&buffer, "aamb{s}", .{suffix})) orelse return error.MissingCompanionIdle;
            result.run[grip] = try animation.find(bytes, if (carrying) "runa" else try std.fmt.bufPrint(&buffer, "run{s}", .{suffix})) orelse return error.MissingCompanionRun;
            result.walk[grip] = try animation.find(bytes, if (carrying) "walka" else try std.fmt.bufPrint(&buffer, "walk{s}", .{suffix})) orelse return error.MissingCompanionWalk;
            result.jump[grip] = try animation.find(bytes, if (carrying) "jumpa" else try std.fmt.bufPrint(&buffer, "ajump{s}", .{suffix})) orelse return error.MissingCompanionJump;
            result.crouch[grip] = try animation.find(bytes, if (carrying) "camb" else try std.fmt.bufPrint(&buffer, "camb{s}", .{suffix})) orelse return error.MissingCompanionCrouch;
            result.crouch_walk[grip] = try animation.find(bytes, if (carrying) "cwalk" else try std.fmt.bufPrint(&buffer, "cwalk{s}", .{suffix})) orelse return error.MissingCompanionCrouchWalk;
            result.crouch_attack[grip] = if (carrying) result.crouch[grip] else try animation.find(bytes, try std.fmt.bufPrint(&buffer, "catak{s}", .{suffix})) orelse return error.MissingCompanionCrouchAttack;
            result.attack[grip] = if (carrying) result.idle[grip] else try animation.find(bytes, try std.fmt.bufPrint(&buffer, "atak{s}", .{suffix})) orelse return error.MissingCompanionAttack;
        }
        return result;
    }
    pub fn select(self: Set, weapon: i32, motion: Gait, jumping: bool, ducked: bool, swimming: bool, jump_started: i64, last_fire: ?i64, changed: i64, now: i64) Playback {
        const grip = weaponGrip(weapon);
        if (swimming) if (self.swim) |sequence| return .{ .sequence = sequence, .started = changed };
        if (ducked) {
            if (motion != .still) return .{ .sequence = self.crouch_walk[grip], .started = changed };
            if (last_fire) |at| if (now >= at and now - at < self.crouch_attack[grip].duration()) return .{ .sequence = self.crouch_attack[grip], .started = at, .looping = false };
            return .{ .sequence = self.crouch[grip], .started = changed };
        }
        if (jumping) return .{ .sequence = self.jump[grip], .started = jump_started, .looping = false };
        if (motion != .still) return .{ .sequence = if (motion == .run) self.run[grip] else self.walk[grip], .started = changed };
        if (last_fire) |at| if (now >= at and now - at < self.attack[grip].duration()) return .{ .sequence = self.attack[grip], .started = at, .looping = false };
        return .{ .sequence = self.idle[grip], .started = changed };
    }
};
pub fn weaponGrip(weapon: i32) usize {
    const entry = if (weapon > 0 and weapon < 32) catalog.find(@intCast(weapon)) else null;
    return if (entry) |item| switch (item.spec.player_grip) {
        .glove => 0,
        .pistol => 1,
        .rifle, .shoulder => 2,
    } else 0;
}
