// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: dragon. Pure dragon class policy: state, tuning and decisions.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .dragon, .traits = .{ .sidekicks = .refuse_melee, .attack = .sequence, .remains = .{ .always = true } } }};
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "dragon";
/// Aidata: the fireball is weapon 1.
pub const ClassTuning = struct { fireball: @import("../../../mechanics/policy/actors/weapon.zig").Tuning = .{} };
pub fn parseTuning(row: anytype, _: class_traits.Kind, _: anytype) !ClassTuning {
    const fireball = try @import("../../../mechanics/policy/actors/weapon.zig").Tuning.parse(row, "weapon1_");
    if (fireball.speed <= 0) return error.InvalidDragonFireball;
    return .{ .fireball = fireball };
}
pub const attacks = [_][]const u8{ "ataka", "hover" };
/// Its fireball leaves from 96 above its mouth, aimed at the target, and burns.
pub const fireball_styles = [_]@import("../../../mechanics/policy/actors/fireballs.zig").Style{.{ .kind = .dragon, .raised = 96, .burning = true }};
pub const breath_tag = 10016;
/// Its call as it starts to hover carries 2048 units at full volume; its patrol calls 900–1024.
pub const hover_call = [2]f32{ 2048, 2049 };
pub const patrol_call = [2]f32{ 900, 1024 };
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    phase: enum { choose, hover, attack } = .choose,
    until_ms: i64 = 0,
    ambient_ms: i64 = 0,
    breath_emitted: bool = false,
    breath_until_ms: ?i64 = null,
    breath_direction: [3]f32 = @splat(0),
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.active(&self.until_ms, delta);
        try saved.active(&self.ambient_ms, delta);
        try saved.deadline(&self.breath_until_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (!saved.bounded(&self.breath_direction, 1.001)) return error.InvalidSavedActor;
    }
};
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_dragon", .kind = .dragon, .idle = "hover", .run = "flya" },
};
