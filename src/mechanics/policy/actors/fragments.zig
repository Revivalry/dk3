// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: actor death material and authored gib eligibility, independent of difficulty
//! scaling. Each class declares its material in its traits (`remains`).
pub const Policy = struct {
    /// How much a death must exceed to burst, as fractions of base health: the killing hit
    /// (`gib_damage`) or the health below zero (`gib_overkill`). The reference bursts at 0.30 and
    /// 0.50, which takes nearly every rifle and blaster kill; the remaster defaults to 1 so its
    /// physical deaths keep their bodies and explosions and heavy blows still burst them.
    pub const Thresholds = struct {
        hit: f32 = 1,
        overkill: f32 = 1,
        pub const reference: Thresholds = .{ .hit = 0.3, .overkill = 0.5 };
    };
    robotic: bool = false,
    no_blood: bool = false,
    bone: bool = false,
    always: bool = false,
    never: bool = false,
    pub fn eligible(self: Policy, flags: u32, damage: i32, remaining: i32, base_health: f32, limits: Thresholds) bool {
        // A thousandth of a point of slack: the fractions are stored as f32 (0.3 is 0.30000001).
        return !self.never and (self.always or flags & 0x400 != 0 or @as(f64, @floatFromInt(damage)) >= @as(f64, base_health) * limits.hit - 0.001 or @as(f32, @floatFromInt(remaining)) < -base_health * limits.overkill);
    }
};
test "fragment thresholds retain no-gib overrides and mechanical materials" {
    const t = @import("std").testing;
    const traitsOf = @import("../../../actor_catalog.zig").traitsOf;
    const gold = Policy.Thresholds.reference;
    try t.expect(traitsOf(.skeeter).remains.eligible(0, 1, 0, 100, gold));
    try t.expect(traitsOf(.skeeter).remains.no_blood);
    try t.expect(!traitsOf(.crox).remains.eligible(0, 29, -50, 100, gold));
    try t.expect(traitsOf(.crox).remains.eligible(0, 30, 0, 100, gold));
    try t.expect(traitsOf(.crox).remains.eligible(0, 1, -51, 100, gold));
    try t.expect(!traitsOf(.garroth).remains.eligible(0x400, 1000, -1000, 100, gold));
    try t.expect(traitsOf(.mishima_guard).remains.eligible(0x400, 1, 0, 100, gold));
}
test "the remaster keeps a guard's body after blaster kills and bursts it under explosives" {
    const t = @import("std").testing;
    const guard = @import("../../../actor_catalog.zig").traitsOf(.mishima_guard).remains;
    // 37 health on easy: the reference bursts on any 30-damage ion bolt.
    try t.expect(guard.eligible(0, 30, -23, 37, Policy.Thresholds.reference));
    try t.expect(!guard.eligible(0, 30, -23, 37, .{}));
    try t.expect(guard.eligible(0, 75, -38, 37, .{}));
    try t.expect(guard.eligible(0, 10, -38, 37, .{}));
}
