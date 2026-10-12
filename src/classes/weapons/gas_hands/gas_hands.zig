// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: gas_hands. Weapon description: data, hooks and class rules for gas hands.
const profiles = @import("../../../mechanics/policy/weapons/profiles.zig");
pub const id: u5 = 7;
/// Held on a timer: a pickup extends its lifetime and holding it runs the lifetime down.
pub const timer = @import("gas_rules.zig");
pub const spec: profiles.Spec = .{
    .player_grip = .glove,
    .combat = .melee,
    .equipped = false,
    .droppable = false,
    .world_model = "models/e1/a_gashand.dkm",
    .animation = .{
        .view_model = "models/e1/w_gashand.dkm",
        .ready = "ready",
        .away = "away",
        .fire = "shootb",
        .fire_variants = .{ "shootb", "shootc", null, null },
        .idle = .{ "amba", null, null },
        .alternate = "shootc",
        .raise_ms = 1550,
        .drop_ms = 1050,
    },
    .audio = .{
        .fire = "e1/we_gasloop.wav",
        .ready = "e1/we_gasstart.wav",
        .away = "e1/we_gasstopa.wav",
    },
};
pub const identity = .{ .classname = "weapon_gashands", .label = "Gas hands", .episode = 1, .interval = 900 };

pub fn meleePlan(_: i32, _: i32) !@import("../../../mechanics/policy/weapons/melee.zig").Plan {
    return .{ .delays_ms = .{ 400, 0 }, .height = 16, .crouching_height = -9, .require_selected = false, .inertial = true, .scale_timing = true };
}
pub fn impact(_: @import("../../../mechanics/policy/weapons/impact.zig").Context) @import("../../../mechanics/policy/weapons/impact.zig").Cue {
    return .{ .sound = "e1/we_gasclangc.wav", .particles = 5, .color = .{ 0.7, 0.7, 1 }, .light_radius = 350 };
}

const shot_rules = @import("../../../mechanics/policy/weapons/shot.zig");
const state = @import("../../../mechanics/policy/weapons/weapon_state.zig");
const sword = @import("../sword/sword_rules.zig");
pub fn predictionShot(controller: anytype) shot_rules.Shot {
    var shot = shot_rules.standard(controller);
    const seed: u32 = @bitCast(controller.now());
    shot.sequence = @intCast(((seed *% 1103515245 +% 12345) >> 16) & 1);
    return shot;
}

pub fn update(controller: anytype) void {
    controller.automatic(@This());
}
