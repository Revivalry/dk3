// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: glowing sprite particles that wander about the emitter that released them,
//! fading and shifting colour. A collectable swarm's particles carry its extension.
/// Plain particles' render tag (swarm particles use the swarm's).
pub const render_tag = 10004;
pub const State = struct {
    /// Swarm particles render as such; the others as plain glowing sprites.
    pub fn renderTag(self: State) i32 {
        return if (self.wisp != null) @import("energy_swarm.zig").render_tag else render_tag;
    }
    source: u32,
    /// The collectable-swarm extension (the saved key predates the mechanism).
    wisp: ?@import("energy_swarm.zig").Particle = null,
    shape: u3,
    distance: f32 = 75,
    speed: f32 = 55,
    scale: f32 = 0.5,
    color: [3]f32 = @splat(1),
    color2: [3]f32 = @splat(0),
    displayed_color: [3]f32 = @splat(1),
    alpha: f32 = 0.75,
    maximum_alpha: f32 = 0.75,
    delta_alpha: f32 = 0,
    personality: f32,
    next_ms: i64,
    direction: [3]f32 = @splat(0),
    previous: [3]f32,
    outward: bool = false,
    phase: u4 = 0,
    alpha_up: bool = false,
    alpha_count: u3 = 0,
    color_forward: bool = false,
    color_fraction: f32 = 0.1,
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.source);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try clock.shift(&self.next_ms);
        if (self.wisp) |*wisp| {
            try clock.active(&wisp.respawn_ms);
            try clock.active(&wisp.collected_ms);
        }
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const State, check: anytype) !void {
        try check.require(.{ "Binding", "Body", "Transform", "Velocity", "Random" });
        if (self.source == 0 or self.distance < 20 or self.distance > 200 or self.speed < 1 or self.speed > 500 or self.personality < 0.25 or self.personality > 1 or self.phase >= 12 or self.scale <= 0 or self.scale > 10000 or self.maximum_alpha < 0 or self.maximum_alpha > 1 or self.delta_alpha < 0 or self.delta_alpha > 1 or self.color_fraction < 0 or self.color_fraction > 1.25) return error.InvalidSavedFirefly;
        if (check.find(self.source)) |source| {
            // A particle is a swarm's exactly when its source carries a swarm.
            const owned = source.get("WispSwarm") catch null;
            if ((owned != null) != (self.wisp != null)) return error.InvalidSavedFirefly;
            if (self.wisp) |wisp| {
                const swarm = owned.?;
                if (swarm.count > 10 or @import("std").mem.indexOfScalar(u32, swarm.children[0..swarm.count], try check.id()) == null or wisp.blend_after > 5) return error.InvalidSavedWisp;
                for (wisp.goal ++ wisp.collected_at) |axis| if (!@import("std").math.isFinite(axis)) return error.InvalidSavedWisp;
            }
        }
    }
};
