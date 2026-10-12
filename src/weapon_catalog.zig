// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Read-only concrete weapon descriptions, shared without linking legacy behavior.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
/// The weapon descriptions (classes.zig), in weapon-table order.
pub const weapons = classes.all;
pub const classes = @import("game/weapons/classes.zig");
pub const PlayerGrip = @import("mechanics/policy/weapons/profiles.zig").PlayerGrip;
pub const Spec = @import("mechanics/policy/weapons/profiles.zig").Spec;
pub const ballistics = @import("mechanics/policy/weapons/ballistics.zig");
pub const melee = @import("mechanics/policy/weapons/melee.zig");
pub const affliction = @import("mechanics/policy/weapons/affliction.zig");
pub fn flightScale(id: u5, flags: i32) f32 {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "flightScale")) return W.flightScale(flags);
        return W.spec.visual.projectile_scale;
    };
    return 1;
}
pub fn combatFor(id: u5, sequence: i32) @import("mechanics/policy/weapons/profiles.zig").Combat {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "combatFor")) return W.combatFor(sequence);
        return W.spec.combat;
    };
    return .pending;
}
pub fn meleePlan(id: u5, sequence: i32, experience: i32) !melee.Plan {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "meleePlan")) return W.meleePlan(sequence, experience);
    };
    return error.MissingMeleePolicy;
}
pub fn meleeDamage(id: u5, hit: melee.Hit) melee.Damage {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "meleeDamage")) return W.meleeDamage(hit);
    };
    return .{ .amount = hit.damage };
}
pub fn swordExperience(id: u5, health: i32) i32 {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "swordExperience")) return W.swordExperience(health);
    };
    return 0;
}
/// Whether kills with weapon `id` train the sword (`swordExperience`) instead of the character.
pub fn trainsSword(id: u5) bool {
    inline for (weapons) |W| if (id == W.id) return @hasDecl(W, "swordExperience");
    return false;
}
pub fn fireSound(id: u5, sequence: i32, serial: u32) ?[:0]const u8 {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "fireSound")) return W.fireSound(sequence, serial);
        return W.spec.audio.fire;
    };
    return null;
}
pub fn attackAnimation(id: u5, sequence: i32, experience: i32) @import("mechanics/policy/weapons/profiles.zig").AttackAnimation {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "attackAnimation")) return W.attackAnimation(sequence, experience);
        const pose = if (sequence >= 0 and sequence < W.spec.animation.fire_variants.len) W.spec.animation.fire_variants[@intCast(sequence)] orelse W.spec.animation.fire else W.spec.animation.fire;
        return .{ .pose = pose, .rate = W.spec.animation.rate };
    };
    return .{ .pose = "", .rate = 20 };
}
pub fn flightState(id: u5) !ballistics.State {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "flight_tag")) return @unionInit(ballistics.State, W.flight_tag, if (W.BallisticState == void) {} else .{});
    };
    return error.MissingProjectilePolicy;
}
pub fn flightMotion(id: u5, state: *ballistics.State, frame: ballistics.Frame) !ballistics.Motion {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "flightMotion")) {
            if (state.* != @field(@import("std").meta.Tag(ballistics.State), W.flight_tag)) return error.InvalidProjectileState;
            return W.flightMotion(&@field(state, W.flight_tag), frame);
        }
    };
    return error.MissingProjectilePolicy;
}
pub fn flightContact(id: u5, contact: ballistics.Contact) !ballistics.Response {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "flightContact")) return W.flightContact(contact);
    };
    return error.MissingProjectilePolicy;
}
pub fn flightDamage(id: u5, hit: ballistics.Hit) ballistics.Damage {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "flightDamage")) return W.flightDamage(hit);
        return .{ .amount = hit.damage * W.spec.projectile.direct_scale };
    };
    return .{ .amount = 0 };
}
pub fn flightLaunch(id: u5, tuning: values.Values, sequence: i32, attack: u8) ballistics.Launch {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "flightLaunch")) return W.flightLaunch(tuning, sequence, attack);
    };
    return .{ .muzzle = tuning.muzzle };
}
pub const impact_rules = @import("mechanics/policy/weapons/impact.zig");
pub fn impact(id: u5, context: impact_rules.Context) impact_rules.Cue {
    inline for (weapons) |W| if (id == W.id) {
        if (@hasDecl(W, "impact")) return W.impact(context);
        return impact_rules.standard(W.spec.impact, context);
    };
    return .{};
}
pub const Entry = struct { id: u5, classname: [:0]const u8, label: [:0]const u8, episode: u8, interval: i32, spec: Spec };
pub const entries = blk: {
    var result: [weapons.len]Entry = undefined;
    for (weapons, 0..) |W, i| {
        if (W.spec.combat == .projectile and (!@hasDecl(W, "flight_tag") or !@hasDecl(W, "flightMotion") or !@hasDecl(W, "flightContact"))) @compileError("projectile class must own its flight/contact contract");
        if (W.spec.combat == .flown and (!@hasDecl(W, "flight_tag") or !@hasDecl(W, "flightMotion"))) @compileError("flown projectile class must own its flight contract");
        if (W.spec.combat == .melee and !@hasDecl(W, "meleePlan")) @compileError("melee class must own its strike plan");
        result[i] = .{ .id = W.id, .classname = W.identity.classname, .label = W.identity.label, .episode = W.identity.episode, .interval = W.identity.interval, .spec = W.spec };
    }
    break :blk result;
};
pub fn find(id: u5) ?*const Entry {
    for (&entries) |*entry| if (entry.id == id) return entry;
    return null;
}
pub fn starting(episode: u8) u5 {
    for (entries) |entry| if (entry.spec.start_episode == episode) return entry.id;
    return 1;
}

pub fn update(controller: anytype) void {
    inline for (weapons) |W| if (controller.ps.weapon == W.id) {
        W.update(controller);
        return;
    };
}
pub fn isReloading(ps: anytype) bool {
    inline for (weapons) |W| if (ps.weapon == W.id) {
        if (@hasDecl(W, "isReloading")) return W.isReloading(ps);
        return false;
    };
    return false;
}
pub const presentation = @import("mechanics/policy/weapons/presentation.zig");

pub const transitions = @import("mechanics/policy/weapons/controller.zig");
pub const Shot = @import("mechanics/policy/weapons/shot.zig").Shot;

pub const values = @import("mechanics/policy/weapons/values.zig");

/// Number of weapons; ids run from 1 to `count`.
pub const count: u5 = weapons.len;
/// The weapon held on a timer (`timer`): picking it up extends its lifetime, holding it runs
/// the lifetime down, and its expiry takes it away.
pub const timed = blk: {
    var found: ?type = null;
    for (weapons) |W| if (@hasDecl(W, "timer")) {
        if (found != null) @compileError("only one weapon may be timed: the player state holds one timer");
        found = W;
    };
    break :blk found orelse @compileError("no timed weapon");
};
/// The weapon picking up `id` also grants (`grants`), if any.
pub fn grants(id: u5) ?u5 {
    inline for (weapons) |W| if (id == W.id) return if (@hasDecl(W, "grants")) W.grants else null;
    return null;
}
/// Whether an authored item name spawns weapon `id`: its classname or one of its `aliases`.
pub fn named(id: u5, name: []const u8) bool {
    inline for (weapons) |W| if (id == W.id) {
        if (@import("std").ascii.eqlIgnoreCase(name, W.identity.classname)) return true;
        if (@hasDecl(W, "aliases")) for (W.aliases) |alias| if (@import("std").ascii.eqlIgnoreCase(name, alias)) return true;
        return false;
    };
    return false;
}
/// Supplied tuning for weapon `id`: the shared columns, the class's default muzzle
/// (`default_muzzle`) and its own columns (`parseValues`).
pub fn parseValues(id: u5, row: anytype) !values.Values {
    inline for (weapons) |W| if (id == W.id) {
        var result = try values.parse(row, if (@hasDecl(W, "default_muzzle")) W.default_muzzle else null);
        if (@hasDecl(W, "parseValues")) try W.parseValues(&result, row);
        return result;
    };
    return values.parse(row, null);
}

pub const character = @import("mechanics/policy/weapons/character_rules.zig");
test {
    _ = presentation;
    _ = transitions;
    _ = character;
    _ = values;
    _ = @import("classes/weapons/sword/sword_rules.zig");
    inline for (weapons) |W| _ = W;
}

test "projectile classes retain water/acceleration state and grenade damping is time invariant" {
    const std = @import("std");
    var rocket = try flightState(5);
    var frame: ballistics.Frame = .{ .age_ms = 0, .delta_ms = 0, .distance = 0, .wet = true, .was_wet = false, .velocity = .{ 900, 0, 0 } };
    try std.testing.expectEqual(@as(f32, 300), (try flightMotion(5, &rocket, frame)).velocity[0]);
    frame.age_ms = 600;
    frame.distance = 600;
    frame.velocity[0] = 300;
    frame.wet = false;
    try std.testing.expectEqual(@as(f32, 300), (try flightMotion(5, &rocket, frame)).velocity[0]);
    var dry = try flightState(5);
    frame.velocity[0] = 900;
    try std.testing.expectEqual(@as(f32, 1800), (try flightMotion(5, &dry, frame)).velocity[0]);
    frame.velocity[0] = 1800;
    try std.testing.expectEqual(@as(f32, 1800), (try flightMotion(5, &dry, frame)).velocity[0]);
    var grenade = try flightState(27);
    frame = .{ .age_ms = 400, .delta_ms = 100, .distance = 100, .wet = true, .was_wet = true, .velocity = .{ 400, 400, 40 } };
    const whole = try flightMotion(27, &grenade, frame);
    frame.delta_ms = 20;
    for (0..5) |_| frame.velocity = (try flightMotion(27, &grenade, frame)).velocity;
    try std.testing.expectApproxEqAbs(whole.velocity[0], frame.velocity[0], 0.001);
    try std.testing.expectEqual(@as(f32, 40), frame.velocity[2]);
    try std.testing.expectEqual(@as(f32, 800), whole.gravity);
    try std.testing.expectError(error.InvalidProjectileState, flightMotion(16, &rocket, frame));
    try std.testing.expectEqual(ballistics.Response.direct, try flightContact(16, .{ .damageable = true, .living = true, .brush = false }));
    try std.testing.expectEqual(ballistics.Response.remove, try flightContact(16, .{ .damageable = false, .living = false, .brush = true }));
}

test "melee classes own delayed windows, directional defense, immunities and sword rewards" {
    const std = @import("std");
    const claw = try meleePlan(15, 2, 0);
    try std.testing.expectEqual(@as(u16, 250), claw.delays_ms[0]);
    try std.testing.expect(claw.sound_on_strike and !claw.require_selected);
    const sword = try meleePlan(8, 9, 0);
    try std.testing.expectEqualSlices(u16, &.{ 252, 648 }, &sword.delays_ms);
    try std.testing.expectEqualSlices(u16, &.{ 140, 360 }, &(try meleePlan(8, 9, 3000)).delays_ms);
    try std.testing.expectError(error.InvalidSwordSwing, meleePlan(8, 3, 0));
    var hit: melee.Hit = .{ .damage = 40, .experience = 750, .victim_class = "monster_mishimaguard", .forward = .{ 1, 0, 0 }, .facing = .{ 1, 0, 0 }, .defending = false, .serial = 0 };
    try std.testing.expectEqual(@as(f32, 120), meleeDamage(8, hit).amount);
    hit.facing = .{ -1, 0, 0 };
    try std.testing.expectEqual(@as(f32, 60), meleeDamage(8, hit).amount);
    hit.defending = true;
    const parry = meleeDamage(8, hit);
    try std.testing.expectEqual(@as(f32, 30), parry.amount);
    try std.testing.expect(parry.sound != null);
    hit.victim_class = "monster_medusa";
    try std.testing.expectEqual(@as(f32, 0), meleeDamage(8, hit).amount);
    try std.testing.expectEqual(@as(i32, 5), swordExperience(8, 100));
    try std.testing.expectEqual(@as(i32, 0), swordExperience(15, 100));
}

test "Venomous owns alternate muzzles and bite poison; Kineticore ages and recovers speed" {
    const std = @import("std");
    const tuning: values.Values = .{ .muzzle = .{ -6, 30, 12 }, .alternate_muzzle = .{ 7, 30, 14 } };
    try std.testing.expectEqual([3]f32{ -6, 40, 12 }, flightLaunch(11, tuning, 0, 0).muzzle);
    try std.testing.expectEqual([3]f32{ 7, 40, 14 }, flightLaunch(11, tuning, 1, 0).muzzle);
    try std.testing.expect(combatFor(11, 128) == .melee);
    try std.testing.expect(combatFor(11, 0) == .projectile);
    const poison = flightDamage(11, .{ .damage = 30, .age_ms = 10, .lifetime_ms = 10000 });
    try std.testing.expectEqual(@as(u32, 5000), poison.effect.poison.duration_ms);
    try std.testing.expectEqual(@as(f32, 3), poison.effect.poison.damage);
    try std.testing.expectEqual(@as(f32, 14), flightDamage(24, .{ .damage = 12, .age_ms = 0, .lifetime_ms = 1500 }).amount);
    try std.testing.expectEqual(@as(f32, 8), flightDamage(24, .{ .damage = 12, .age_ms = 750, .lifetime_ms = 1500 }).amount);
    try std.testing.expectEqual(@as(f32, 5), flightDamage(24, .{ .damage = 12, .age_ms = 750, .lifetime_ms = 1500, .self_hit = true }).amount);
    var core = try flightState(24);
    var frame: ballistics.Frame = .{ .age_ms = 100, .delta_ms = 20, .distance = 10, .wet = false, .was_wet = false, .velocity = .{ 100, 0, 0 }, .speed = 300 };
    frame.velocity = (try flightMotion(24, &core, frame)).velocity;
    try std.testing.expectEqual(@as(f32, 200), frame.velocity[0]);
    try std.testing.expectEqual(@as(f32, 200), (try flightMotion(24, &core, frame)).velocity[0]);
    frame.age_ms = 200;
    try std.testing.expectEqual(@as(f32, 300), (try flightMotion(24, &core, frame)).velocity[0]);
    frame.age_ms = 2000000000;
    try std.testing.expectEqual(@as(f32, 300), (try flightMotion(24, &core, frame)).velocity[0]);
    var venom = try flightState(11);
    frame.wet = true;
    try std.testing.expect((try flightMotion(11, &venom, frame)).remove);
}
