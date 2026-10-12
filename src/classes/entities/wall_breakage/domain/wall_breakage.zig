// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: wall_breakage. Grouped destructible walls retain their scheduled fragment bursts in saves.
pub const Burst = struct { position: [3]f32 = @splat(0), due_ms: ?i64 = null };
pub const State = struct {
    models: [3][]const u8 = .{ "models/global/e_rock1.dkm", "models/global/e_rock2.dkm", "models/global/e_rock3.dkm" },
    bounds_min: [3]f32 = @splat(0),
    bounds_max: [3]f32 = @splat(0),
    bursts: [11]Burst = @splat(.{}),
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        for (&self.bursts) |*burst| try clock.deadline(&burst.due_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`); `broken` is its brush's.
    pub fn validateSaved(self: *const State, check: anytype, broken: bool) !void {
        try check.require(.{ "Binding", "MapObject", "Body", "Health", "Hurt", "Random" });
        if (!try check.trait("exploding_wall")) return error.InvalidSavedExplodingWall;
        for (self.models) |model| if (model.len == 0 or model.len >= 64) return error.InvalidSavedExplodingWall;
        for (self.bounds_min ++ self.bounds_max) |value| if (!@import("std").math.isFinite(value)) return error.InvalidSavedExplodingWall;
        for (self.bursts) |burst| {
            if (burst.due_ms != null and !broken) return error.InvalidSavedExplodingWall;
            for (burst.position) |value| if (!@import("std").math.isFinite(value)) return error.InvalidSavedExplodingWall;
        }
    }
};
