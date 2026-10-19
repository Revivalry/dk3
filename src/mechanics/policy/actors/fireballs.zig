// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the authored fireball. Each launching class declares the styles of its
//! fireballs (`fireball_styles`); the variant saved with a fireball names its style.
/// The persistent attack payloads this mechanism launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{.{ .tag = "fireball", .Payload = State }};
/// Fireball variants, named for their launchers. Saved with each fireball: append only.
pub const Kind = enum { knight, doombat, dragon };
/// How one fireball variant launches, looks and bursts.
pub const Style = struct {
    kind: Kind,
    scale: f32 = 1,
    /// Four more blasts 40 units out (each 30% of the damage) with the large explosion sounds.
    secondary_blasts: bool = true,
    /// Launched from this far above its muzzle, aimed straight at the target.
    raised: f32 = 0,
    /// Carries an orange light.
    lit: bool = false,
    /// Burns: tinted, with a flame trail.
    burning: bool = false,
};
const saved = @import("saved_time.zig");
const std = @import("std");
pub const State = struct {
    kind: Kind,
    damage: f32,
    drift_ms: i64,
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.drift_ms, delta);
    }
    pub fn validSaved(self: State, born_ms: i64, stepped_ms: i64) bool {
        return self.damage > 0 and self.damage <= 1000000 and stepped_ms <= born_ms + 5000 and self.drift_ms > stepped_ms and self.drift_ms <= stepped_ms + 100;
    }
};
pub const model = "models/e3/we_fball.dkm";
pub const render_tag = 10015;
/// Every declared style, indexed by variant.
const styles: [@typeInfo(Kind).@"enum".fields.len]Style = blk: {
    var table: [@typeInfo(Kind).@"enum".fields.len]?Style = @splat(null);
    for (@import("../../../actor_catalog.zig").policies) |policy| if (@hasDecl(policy, "fireball_styles")) for (policy.fireball_styles) |entry| {
        if (table[@intFromEnum(entry.kind)] != null) @compileError("fireball variant styled twice: " ++ @tagName(entry.kind));
        table[@intFromEnum(entry.kind)] = entry;
    };
    var result: [table.len]Style = undefined;
    for (table, 0..) |entry, index| result[index] = entry orelse @compileError("fireball variant without a style: " ++ @tagName(@as(Kind, @enumFromInt(index))));
    break :blk result;
};
pub fn style(kind: Kind) Style {
    return styles[@intFromEnum(kind)];
}
