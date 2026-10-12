// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: cambot. Surveillance actor: acquisition/alarm and following, with no damage weapon.
const std = @import("std");
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .cambot, .traits = .{ .remains = .{ .robotic = true, .no_blood = true, .always = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "cambot";
pub const alarm = "e1/m_cambotalarm.wav";
pub const idle_light = "models/e1/me_cambotf.sp2";
pub const alert_light = "models/global/e_sflred.sp2";
pub const idle_tag: i32 = 0x43414d;
pub const alert_tag: i32 = idle_tag + 1;
pub const searchlight = .{ .reach = 600, .radius = 2, .pitch = 45, .sweep_rate = 0.08, .sweep_span = 109, .idle_color = [3]f32{ 0.6, 0.6, 0.1 }, .alert_color = [3]f32{ 0.8, 0.1, 0.1 } };
// Presentation enhancement: a small emitter and a soft, range-attenuated
// surface pool replace the large omnidirectional glow at the camera body.
pub const lighting = .{ .emitter_radius = 40, .emitter_gain = 0.2, .surface_offset = 6, .minimum_radius = 24, .maximum_radius = 128, .falloff_distance = 300, .surface_gain = 1, .beam_alpha = 24, .flare_scale = 1.5, .flare_alpha = 160 };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    seen: bool = false,
    alarmed: u32 = 0,
    wave: u4 = 0,
    back_direction: i8 = 0,
    evade: ?[3]f32 = null,
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (self.wave >= 12 or self.back_direction < -1 or self.back_direction > 1) return error.InvalidSavedActor;
    }
    /// Maps saved persistent ids onto the restored world.
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.alarmed);
    }
};
pub const Movement = enum { back_away, hover, follow };
pub fn movement(horizontal_distance: f32) Movement {
    return if (horizontal_distance < 72) .back_away else if (horizontal_distance > 192) .follow else .hover;
}
pub fn sees(yaw_delta: f32) bool {
    return @abs(@mod(yaw_delta + 180, 360) - 180) < 75;
}
/// The camera spots only a player on roughly its level (64 units) within 1024 horizontally.
pub fn inRange(offset: [3]f32) bool {
    return @abs(offset[2]) <= 64 and offset[0] * offset[0] + offset[1] * offset[1] <= 1024 * 1024;
}
test "camera spots only on its level and within its horizontal reach" {
    try std.testing.expect(inRange(.{ 1000, 0, 64 }));
    try std.testing.expect(!inRange(.{ 0, 0, 65 }));
    try std.testing.expect(!inRange(.{ 800, 800, 0 }));
}
test "camera follows outside the authored band and requires its facing cone" {
    try std.testing.expectEqual(Movement.back_away, movement(71));
    try std.testing.expectEqual(Movement.hover, movement(72));
    try std.testing.expectEqual(Movement.hover, movement(192));
    try std.testing.expectEqual(Movement.follow, movement(193));
    try std.testing.expect(sees(359));
    try std.testing.expect(sees(-74));
    try std.testing.expect(!sees(75));
    try std.testing.expect(!sees(180));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_cambot", .companion_choices = .{ 1, 1, 2 }, .kind = .cambot, .run = "flya" },
};
