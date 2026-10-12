// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: civilians. Unarmed civilians: skinny and fat workers and the plain prisoners.
//! Each classname has a role (docs/class-porting/civilians.md). Worker fear lives in workers.zig;
//! authored work loops come from `default_aiscript`.
const traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]traits.Class{.{ .kind = .civilian, .traits = .{ .bystander = true } }};
/// Worker fear: poses, retreat deadline, voices (the worker role's rules).
pub const workers = @import("workers.zig");
/// Workers carry their fear state.
pub const State = workers.State;
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "worker";
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "monster_skinnyworker", .companion_choices = .{ 0, 0, 0 }, .kind = .civilian, .witness_range = worker_alert_radius },
    .{ .classname = "monster_fatworker", .companion_choices = .{ 0, 0, 0 }, .kind = .civilian, .witness_range = worker_alert_radius },
    .{ .classname = "monster_prisoner", .kind = .civilian, .witness_range = prisoner_alert_radius },
    .{ .classname = "monster_prisonerb", .kind = .civilian, .witness_range = prisoner_alert_radius },
};
/// The reference alert ("speak") radius: active distance × 0.15. Workers: 1000; prisoners: 2000.
pub const worker_alert_radius = 150;
pub const prisoner_alert_radius = 300;
/// How a civilian classname reacts.
pub const Role = struct {
    /// A worker: hides from a player it sees (unless working or ignoring him), then cowers.
    worker: bool = false,
    /// Runs away from whoever hurts it; otherwise a hurt worker is only alerted and hides once
    /// it sees the attacker.
    flees_pain: bool = false,
    /// Cowers with its own clips (`gamba`/`gambc`); a worker without them wanders through its
    /// cower instead.
    cower_clips: bool = false,
    /// Its hide voice uses the thin worker's lines.
    thin_voice: bool = false,
    /// Always bursts when killed.
    always_gibs: bool = false,
};
const roles = [_]struct { classname: []const u8, role: Role }{
    .{ .classname = "monster_skinnyworker", .role = .{ .worker = true, .flees_pain = true, .cower_clips = true, .thin_voice = true } },
    .{ .classname = "monster_fatworker", .role = .{ .worker = true, .always_gibs = true } },
};
/// A classname's role; the plain prisoners never fear: alerted, they wander.
pub fn roleOf(classname: []const u8) Role {
    for (roles) |entry| if (@import("std").mem.eql(u8, entry.classname, classname)) return entry.role;
    return .{};
}
test "civilian roles follow the reference classes" {
    const t = @import("std").testing;
    try t.expect(roleOf("monster_skinnyworker").flees_pain and roleOf("monster_skinnyworker").cower_clips);
    try t.expect(roleOf("monster_fatworker").worker and !roleOf("monster_fatworker").flees_pain and roleOf("monster_fatworker").always_gibs);
    try t.expect(!roleOf("monster_prisoner").worker and !roleOf("monster_prisonerb").worker);
}
