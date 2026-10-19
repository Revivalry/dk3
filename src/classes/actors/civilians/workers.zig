// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: civilians. Worker fear (civilians with the worker role): its poses, retreat
//! deadline (the hide voice is the shared `hide_voice`).
const std = @import("std");
pub const retreat_ms = 10000;
pub const cower_ms = 10000;
pub const retry_distance = 300;
pub const cower_poses = [_][]const u8{ "gamba", "gambc" };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { calm, retreat, cower } = .calm,
    started_ms: i64 = 0,
    retry_ms: i64 = 0,
    voice_pending: bool = false,
    variant: u1 = 0,
    pub fn start(self: *State, now: i64) void {
        self.phase = .retreat;
        self.started_ms = now;
        self.voice_pending = true;
    }
    pub fn stop(self: *State, now: i64) void {
        self.phase = .cower;
        self.started_ms = now;
        self.retry_ms = now + cower_ms;
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.started_ms, delta);
        try saved.active(&self.retry_ms, delta);
    }
};
test "worker retreat ends in cowering" {
    var state: State = .{};
    state.start(100);
    state.stop(200);
    try std.testing.expect(state.phase == .cower);
    try std.testing.expectEqual(@as(i64, 10200), state.retry_ms);
}
