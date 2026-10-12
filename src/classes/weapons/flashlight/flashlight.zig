// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: flashlight. Weapon description: data, hooks and class rules for flashlight.
const profiles = @import("../../../mechanics/policy/weapons/profiles.zig");
pub const id: u5 = 28;
/// Retail's internal flashlight row is empty; the reviewed class battery stands in.
pub fn parseValues(values: *@import("../../../mechanics/policy/weapons/values.zig").Values, _: anytype) !void {
    if (values.ammoMax != 0) return;
    values.ammoMax = 1000;
    values.ammoCost = 1;
}
pub const spec: profiles.Spec = .{
    .player_grip = .pistol,
    .combat = .owned,
    .auto_select = false,
    .droppable = false, // flashlight
    .animation = .{ .view_model = "models/e2/w_sflare.dkm", .ready = "ready", .away = "away", .fire = "shoota", .idle = .{ "amba", null, null } },
};
pub const identity = .{ .classname = "weapon_flashlight", .label = "Flashlight", .episode = 0, .interval = 300 };

const shot_rules = @import("../../../mechanics/policy/weapons/shot.zig");
pub const Light = struct {
    owner: u32,
    expires_ms: i64,
    strength: f32,
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *Light, map: anytype) !void {
        try map.one(&self.owner);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *Light, clock: anytype) !void {
        try clock.shift(&self.expires_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const Light, check: anytype) !void {
        if (self.strength < 0 or self.strength > 1 or (try check.get("Binding")).model != 0) return error.InvalidSavedLight;
        const owner = check.find(self.owner) orelse return error.InvalidSavedLight;
        try owner.require(.{ "Player", "Weapons", "Health", "Binding" });
    }
    /// It publishes its own projection: a saved entity of it needs no Body.
    pub const saved_bodiless = true;
};
pub const rays = [_][2]f32{ .{ 0, 0 }, .{ -4, 0 }, .{ 4, 0 }, .{ 0, -4 }, .{ 0, 4 } };
pub fn power(ammunition: i32) f32 {
    const remaining = @as(f32, @floatFromInt(@divTrunc(@max(0, ammunition), 10))) / 50;
    return if (remaining <= 0) 0 else if (remaining >= 1) 1 else 0.5 + remaining * 0.5;
}
pub fn radius(distance: f32, strength: f32) f32 {
    return @max(75, (75 + distance * 0.15) * strength);
}
pub fn brightness(distance: f32, strength: f32) f32 {
    return strength * (if (distance > 0) @min(1, 200000 / (distance * distance)) else @as(f32, 1));
}
pub fn predictionShot(controller: anytype) shot_rules.Shot {
    var result = shot_rules.standard(controller);
    result.duration_ms = 100;
    return result;
}

pub fn update(controller: anytype) void {
    controller.automatic(@This());
}
test "flashlight battery has the reference display threshold and softened dimming" {
    const std = @import("std");
    try std.testing.expectEqual(@as(f32, 0), power(9));
    try std.testing.expectApproxEqAbs(@as(f32, 0.51), power(10), 0.001);
    try std.testing.expectEqual(@as(f32, 1), power(500));
    try std.testing.expectEqual(@as(f32, 0.2), brightness(1000, 1));
}
