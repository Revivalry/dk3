// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: a collectable swarm, an emitter whose glowing particles wander about it until
//! a consumer collects them one by one; each collected particle is delivered, then respawns.
pub const model = "models/global/e_sflblue.sp2";
pub const render_tag = 10020;
pub const Swarm = struct {
    children: [10]u32 = @splat(0),
    count: u4 = 3,
    next_ms: i64,
    sound_ms: i64,
    consumer: u32 = 0,
    sending: ?u4 = null,
    goal: [3]f32 = @splat(0),
    delivered: u16 = 0,
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Swarm, map: anytype) !void {
        try map.many(&self.children);
        try map.one(&self.consumer);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Swarm, clock: anytype) !void {
        try clock.shift(&self.next_ms);
        try clock.shift(&self.sound_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Swarm, check: anytype) !void {
        try check.require(.{ "MapObject", "Transform", "Random" });
        if (self.count < 1 or self.count > 10) return error.InvalidSavedWisp;
        if (self.sending) |index| if (index >= self.count) return error.InvalidSavedWisp;
        for (self.goal) |axis| if (!@import("std").math.isFinite(axis)) return error.InvalidSavedWisp;
        for (self.children[0..self.count], 0..) |id, i| {
            if (id == 0 or @import("std").mem.indexOfScalar(u32, self.children[0..i], id) != null) return error.InvalidSavedWisp;
            const child = check.find(id) orelse return error.InvalidSavedWisp;
            const fly = child.get("Firefly") catch return error.InvalidSavedWisp;
            if (fly.source != try check.id() or fly.wisp == null) return error.InvalidSavedWisp;
        }
        for (self.children[self.count..]) |id| if (id != 0) return error.InvalidSavedWisp;
    }
};
pub const Particle = struct {
    mode: enum { wander, collect, dormant } = .wander,
    new_goal: bool = false,
    goal: [3]f32,
    respawn_ms: i64 = 0,
    collected_ms: i64 = 0,
    collected_at: [3]f32 = @splat(0),
    blocked: u32 = 0,
    alpha_count: u32 = 0,
    blend_after: u8 = 0,
};
