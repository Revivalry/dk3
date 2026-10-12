// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: nharre. Pure nharre class policy: state, tuning and decisions.
/// The persistent attack payloads this class launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{.{ .tag = "nharre_reaper", .Payload = Reaper }};
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .nharre, .traits = .{ .sidekicks = .refuse_melee, .attack = .sequence } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "nharre";
pub const attacks = [_][]const u8{ "atakb", "atakc" };
pub const reaper_tag = 10027;
pub const reaper_model = "models/e3/we_nnreaper.dkm";
const std = @import("std");
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { combat, fading_out, fading_in, retreat } = .combat,
    alpha: f32 = 1,
    teleport_ready_ms: i64 = 0,
    summon_ready_ms: i64 = 0,
    destination: [3]f32 = @splat(0),
    retreat_until_ms: i64 = 0,
    teleports: [10][3]f32 = @splat(@splat(0)),
    teleport_count: u8 = 0,
    teleports_ready: bool = false,
    pub fn invulnerable(self: State) bool {
        return self.phase == .fading_out or self.phase == .fading_in;
    }
    pub fn fade(self: *State, clear: bool) enum { waiting, relocate, finished } {
        if (self.phase == .fading_out) {
            if (self.alpha > 0.1) self.alpha = @max(0, self.alpha - 0.1) else if (clear) {
                self.phase = .fading_in;
                return .relocate;
            }
        } else if (self.phase == .fading_in) {
            if (self.alpha >= 1) {
                self.phase = .combat;
                return .finished;
            }
            self.alpha = @min(1, self.alpha + 0.1);
        }
        return .waiting;
    }
    pub fn teleportIndex(self: State, roll: f32) ?usize {
        if (self.teleport_count == 0) return null;
        // The authored callback multiplies by count-1, excluding the final
        // destination when multiple points exist. Keep that selection contract.
        return @intFromFloat(@as(f32, @floatFromInt(self.teleport_count - 1)) * roll);
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.teleport_ready_ms, delta);
        try saved.active(&self.summon_ready_ms, delta);
        try saved.active(&self.retreat_until_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (!std.math.isFinite(self.alpha) or self.alpha < 0 or self.alpha > 1 or self.teleport_count > 10 or (!self.teleports_ready and self.teleport_count != 0)) return error.InvalidSavedActor;
        if (self.invulnerable() and self.teleport_count == 0) return error.InvalidSavedActor;
        if (!saved.point(self.destination)) return error.InvalidSavedActor;
        for (self.teleports) |teleport| if (!saved.point(teleport)) return error.InvalidSavedActor;
    }
};
pub const Reaper = struct {
    target: u32,
    next_ms: i64,
    appeared_ms: ?i64 = null,
    released: bool = false,
    struck: bool = false,
    previous_velocity: [3]f32 = @splat(0),
    previous_view_height: f32 = 22,
    previous_mask: u32 = 0,
    look_angles: [3]f32 = @splat(0),
    floor: [3]f32 = @splat(0),
    ceiling: [3]f32 = @splat(0),
    scorch: [3]f32 = @splat(0),
    normal: [3]f32 = @splat(0),
    flame_next_ms: i64 = 0,
    /// Components the restored reaper entity carries besides the shared attack body.
    pub const saved_components = [_][]const u8{"Random"};
    pub fn rebase(self: *Reaper, delta: i64) !void {
        try saved.shift(&self.next_ms, delta);
        try saved.deadline(&self.appeared_ms, delta);
        try saved.active(&self.flame_next_ms, delta);
    }
    pub fn remapIds(self: *Reaper, map: anytype) !void {
        try map.one(&self.target);
    }
    /// The reaper's own bounds; the held victim is checked by the class adapter.
    pub fn validSaved(self: Reaper, born_ms: i64, stepped_ms: i64) bool {
        if (self.target == 0 or self.next_ms <= stepped_ms or self.next_ms > stepped_ms + 500 or (self.struck and !self.released) or !std.math.isFinite(self.previous_view_height) or self.previous_view_height < -64 or self.previous_view_height > 128) return false;
        if (!saved.bounded(&(self.previous_velocity ++ self.look_angles ++ self.floor ++ self.ceiling ++ self.scorch ++ self.normal), 1048576)) return false;
        if (self.appeared_ms) |at| if (at < born_ms + 500 or at > stepped_ms) return false;
        return true;
    }
    /// Whether this state legitimately owns the saved motion of entity `victim` (snapshot.zig).
    pub fn holdsSaved(self: *const Reaper, victim: u32) bool {
        return !self.released and self.target == victim;
    }
};
test "Nharre teleport selection preserves the final-point exclusion without underflow" {
    const t = @import("std").testing;
    var state: State = .{};
    try t.expect(state.teleportIndex(0.5) == null);
    state.teleport_count = 1;
    try t.expectEqual(@as(?usize, 0), state.teleportIndex(0.999));
    state.teleport_count = 4;
    try t.expectEqual(@as(?usize, 2), state.teleportIndex(0.999));
    try t.expectEqual(@as(?usize, 1), state.teleportIndex(0.5));
}

test "Nharre waits on an occupied point and restores damage only after fading in" {
    const t = @import("std").testing;
    var state: State = .{ .phase = .fading_out };
    for (0..30) |_| try t.expect(state.fade(false) == .waiting);
    try t.expect(state.alpha <= 0.1 and state.invulnerable());
    const alpha = state.alpha;
    try t.expect(state.fade(true) == .relocate);
    try t.expectEqual(alpha, state.alpha);
    try t.expect(state.phase == .fading_in and state.invulnerable());
    for (0..9) |_| try t.expect(state.fade(true) == .waiting);
    while (state.alpha < 1) try t.expect(state.fade(true) == .waiting);
    try t.expect(state.invulnerable());
    try t.expect(state.fade(true) == .finished);
    try t.expect(!state.invulnerable());
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_nharre", .kind = .nharre },
};
