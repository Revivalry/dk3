// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: mikiko. Final hostile Mikiko; companion behavior is a separate controller.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .mikiko, .traits = .{ .attack = .sequence } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "mikiko";
pub const attacks = [_][]const u8{ "ataka", "atakb", "atakc" };
const std = @import("std");
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
/// Her swing sounds play at three-quarter volume.
pub const swing_volume: f32 = 0.75;
pub const State = struct {
    voice_pose: u2 = 0,
    awakened: bool = false,
    aura: bool = false,
    aura_started_ms: i64 = 0,
    light_red: f32 = 1,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.aura_started_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (self.voice_pose > 2 or !std.math.isFinite(self.light_red) or self.light_red < 1 or self.light_red > 2 or (self.aura and !self.awakened)) return error.InvalidSavedActor;
    }
};
pub fn sound(pose: u2, frame: u16) ?[]const u8 {
    return switch (pose) {
        0 => if (frame >= 40 and frame <= 41) "global/we_swordwhoosha.wav" else null,
        1 => if (frame >= 52 and frame <= 53) "mikiko/jump5.wav" else if (frame >= 58 and frame <= 59) "global/we_swordwhooshf.wav" else null,
        2 => if (frame >= 70 and frame <= 71) "mikiko/jump8.wav" else if (frame >= 73 and frame <= 74) "global/we_swordwhooshc.wav" else if (frame >= 83 and frame <= 84) "global/we_swordwhooshd.wav" else null,
        else => null,
    };
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_mikiko", .kind = .mikiko },
};
