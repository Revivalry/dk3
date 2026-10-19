// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: chaingang. Chaingang owns its ground/hover transitions and overlapping gun callbacks.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .chaingang, .traits = .{ .attack = .sequence } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "chaingang";
/// Aidata `attack_speed` paces the strafes.
pub const ClassTuning = struct { attack_speed: f32 = 0 };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const speed = try row.number("attack_speed", 0);
    if (speed <= 0 or speed > 65536) return error.InvalidChaingangAttackSpeed;
    return .{ .attack_speed = speed };
}
pub const attacks = [_][]const u8{ "ataka", "atakf", "transd", "transb", "flyb", "flyc" };
pub const jet_tag = 10018;
pub const flash_model = "models/global/me_mflash.dkm";
/// Its chaingun: an opening shot, then four more, one per tick.
pub const burst_styles = [_]@import("../../../mechanics/policy/actors/bursts.zig").Style{.{ .kind = .chaingang, .opening_shot = true, .shots = 5, .flash_model = flash_model, .muzzle = .{ .tags = .{ .name = "hr_muzzle" } } }};
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
/// A body killed in flight falls at twice normal gravity.
pub const corpse_gravity = 1600;
/// Its jets start about 2.2 s after it spawns; it does nothing before.
pub const startup_ms = 2200;
pub const State = struct {
    phase: enum { chase, attack, dodge, approach_land, landing, settling, takeoff, rising, wander } = .chase,
    flying: bool = false,
    started_ms: i64 = 0,
    until_ms: i64 = 0,
    strafe_ms: i64 = 0,
    strafe: u3 = 0,
    swoop: bool = false,
    burst: u5 = 0,
    start_position: [3]f32 = @splat(0),
    destination: [3]f32 = @splat(0),
    /// Pain interrupts fighting; a takeoff or landing under way carries on once it passes.
    pub fn painInterrupts(self: State) bool {
        return switch (self.phase) {
            .takeoff, .rising, .landing, .settling => false,
            else => true,
        };
    }
    pub fn gunTick(self: *State) bool {
        const fire = self.burst % 3 != 0;
        self.burst = if (self.burst == 22) 0 else self.burst + 1;
        return fire;
    }
    pub fn reflectStrafe(self: *State) void {
        self.strafe = switch (self.strafe) {
            0 => 1,
            1 => 0,
            2 => 5,
            3 => 4,
            4 => 3,
            5 => 2,
            else => unreachable,
        };
    }
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.started_ms, delta);
        try saved.active(&self.until_ms, delta);
        try saved.active(&self.strafe_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (self.strafe > 5 or self.burst > 22) return error.InvalidSavedActor;
        if (!saved.point(self.destination) or !saved.point(self.start_position)) return error.InvalidSavedActor;
    }
};
test "chaingang burst retains its silent first tick and every-third-tick gaps" {
    const t = @import("std").testing;
    var state: State = .{};
    try t.expect(!state.gunTick());
    var fired: usize = 0;
    for (1..23) |_| if (state.gunTick()) {
        fired += 1;
    };
    try t.expectEqual(@as(usize, 15), fired);
    try t.expectEqual(@as(u5, 0), state.burst);
    var restored = state;
    try t.expect(!restored.gunTick());
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_chaingang", .kind = .chaingang, .run = "flya" },
};
