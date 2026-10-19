// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: monitor. A security monitor's saved view: its viewer, camera and target, and how
//! long the view holds.
const Vec3 = [3]f32;
pub const State = struct {
    duration_ms: i32 = 3000,
    viewer: ?u32 = null,
    until_ms: ?i64 = null,
    camera: u32 = 0,
    target: u32 = 0,
    origin: Vec3 = @splat(0),
    angles: Vec3 = @splat(0),
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.optional(&self.viewer);
        try map.fields(self, .{ "camera", "target" });
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.deadline(&self.until_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const State, check: anytype) !void {
        try check.require(.{ "MapObject", "Binding", "Body" });
        if (!try check.trait("monitor") or self.duration_ms < 750 or self.duration_ms > 3600000 or (self.viewer == null) != (self.until_ms == null)) return error.InvalidSavedMonitor;
        if (self.viewer) |viewer_id| {
            const viewer = check.find(viewer_id) orelse return error.InvalidSavedMonitor;
            try viewer.require(.{ "Player", "Body", "Health" });
            if ((try viewer.get("Body")).motion_owner != try check.id() or (try viewer.get("Player")).mode != .frozen) return error.InvalidSavedMonitor;
            if (check.find(self.camera) == null or check.find(self.target) == null) return error.InvalidSavedMonitor;
        }
    }
    /// Whether this state legitimately owns the saved motion of entity `victim` (snapshot.zig).
    pub fn holdsSaved(self: *const State, victim: u32) bool {
        return self.viewer == victim;
    }
};
