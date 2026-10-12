// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: protopod. Proximity-triggered hatching; tuning and pose durations remain supplied data.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .protopod, .traits = .{ .senses = .{ .level = true, .all_round = true }, .remains = .{ .robotic = true, .no_blood = true, .always = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "pod";
/// Hatch distances (horizontal) and the far poll's chance.
pub const near_distance = 200;
pub const far_distance = 512;
pub const far_chance = 0.05;
pub const hatch_delay_ms = 100;
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { closed, waiting, opening, shell } = .closed,
    next_ms: i64 = 0,
    /// A visible enemy within 200 units (or, 5% of the polls, within 512) makes the pod hatch on
    /// its next think. The reference's 0.5-3.5 s random delay never takes effect: its task think
    /// replaces the delayed think 100 ms later.
    pub fn notice(self: *State, now: i64, visible: bool, distance: f32, chance: f32) void {
        if (self.phase != .closed or !visible) return;
        if (distance > near_distance and !(distance <= far_distance and chance < far_chance)) return;
        self.phase = .waiting;
        self.next_ms = now + hatch_delay_ms;
    }
    pub fn use(self: *State, now: i64) void {
        if (self.phase != .closed) return;
        self.phase = .waiting;
        self.next_ms = now;
    }
    pub fn tick(self: *State, now: i64, animation_ms: i64) bool {
        if (now < self.next_ms) return false;
        switch (self.phase) {
            .waiting => {
                self.phase = .opening;
                self.next_ms = now + animation_ms;
                return true;
            },
            .opening => self.phase = .shell,
            else => {},
        }
        return false;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.next_ms, delta);
    }
};
test "pod hatches once, on the think after it notices its enemy" {
    const t = @import("std").testing;
    var pod: State = .{};
    pod.notice(1000, false, 100, 0);
    try t.expectEqual(.closed, pod.phase);
    pod.notice(1000, true, 300, 0.1);
    try t.expectEqual(.closed, pod.phase);
    pod.notice(1000, true, 400, 0.01);
    try t.expectEqual(@as(i64, 1100), pod.next_ms);
    try t.expect(!pod.tick(1099, 600));
    try t.expect(pod.tick(1100, 600));
    try t.expect(!pod.tick(1700, 600));
    try t.expectEqual(.shell, pod.phase);
    pod.use(5000);
    try t.expect(!pod.tick(5000, 600));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_protopod", .kind = .protopod, .run = "amba", .death = "hatcha" },
};
