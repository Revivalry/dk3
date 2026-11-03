// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Inventory-based bot decisions; attacks still run through ordinary player input.
const std = @import("std");
const catalog = @import("weapon_catalog");
const weapons = @import("weapons.zig");
pub fn select(loadout: weapons.State, table: *const weapons.Table, distance: ?f32) u5 {
    return selectFor(loadout, table, distance, .{});
}
pub const Situation = struct {
    /// The shot would meet water close to the shooter, where an ion bolt
    /// discharges into everything nearby, the shooter included.
    wet: bool = false,
    /// The shooter moves on along a route: proximity charges (C4) left for
    /// prey that never arrives would go off under the shooter later.
    advancing: bool = false,
    /// Keep to a ranged weapon while one can shoot: flyers dart in and out of
    /// melee reach, and every swap to the glove and back costs the fire of a
    /// raise and a drop.
    ranged_first: bool = false,
    /// Weapons (bit per id) this shooter must not use here: a companion's
    /// splash weapons with its leader beside the target, for instance.
    excluded: i32 = 0,
};
/// Whether the gun can pull its trigger at this range: within its reach, and a
/// blast round with room to burst. The firing step applies the same test, so a
/// weapon taken up here is never one the shot is refused for afterwards.
fn firesAt(entry: catalog.Entry, tuning: catalog.values.Values, distance: f32) bool {
    if (distance > (entry.spec.bot_range orelse tuning.range)) return false;
    if (entry.spec.splash_hazard and distance < entry.spec.projectile.splash_radius) return false;
    return true;
}
/// The best-scoring gun the situation allows, its own ordering kept: reach and
/// the burst's keep-out are penalties, so a gun able to work at the range is
/// still weighed against one merely listed as reaching it. With `firing_only`,
/// only a gun able to fire at `distance` (which must be in hand) is offered.
fn selectBest(loadout: weapons.State, table: *const weapons.Table, distance: ?f32, situation: Situation, keep_range: bool, firing_only: bool) ?u5 {
    var selected: ?u5 = null;
    var best: f32 = -1;
    for (catalog.entries) |entry| {
        const tuning = table.entries[entry.id];
        if (!entry.spec.auto_select or tuning.damage <= 0 or loadout.dk3Inventory & (@as(i32, 1) << entry.id) == 0 or loadout.ammo[entry.id] < tuning.ammoCost) continue;
        if (situation.excluded & (@as(i32, 1) << entry.id) != 0) continue;
        if (situation.wet and dischargesInWater(entry.id)) continue;
        if (situation.advancing and entry.spec.placed) continue;
        if (keep_range and (entry.spec.bot_range orelse tuning.range) <= 128) continue;
        if (firing_only) if (distance) |range| {
            if (!firesAt(entry, tuning, range)) continue;
        } else continue;
        var score = tuning.damage;
        if (distance) |range| {
            const reach = entry.spec.bot_range orelse tuning.range;
            if (range > reach) score *= 0.01;
            // A splash weapon is taken up only with room to spare (an enemy
            // closes in while it is raised) and put away inside its radius.
            const margin: f32 = if (entry.id == loadout.weapon) 1 else 1.6;
            if (entry.spec.splash_hazard and range < entry.spec.projectile.splash_radius * margin) score *= 0.01;
            // A projectile leaves the muzzle ahead of the player: point blank
            // it starts beyond (or inside) the target and misses. Hitscan and
            // melee weapons strike there.
            if (range < 96 and tuning.speed > 0) score *= 0.05;
        }
        // Avoid switching between equivalent choices every command.
        if (entry.id == loadout.weapon) score *= 1.25;
        if (score > best) {
            best = score;
            selected = entry.id;
        }
    }
    return selected;
}
pub fn selectFor(loadout: weapons.State, table: *const weapons.Table, distance: ?f32, situation: Situation) u5 {
    const keep_range = situation.ranged_first and beyondClose(loadout, table, distance, situation);
    // A gun able to answer at the range in hand goes up ahead of one that
    // cannot fire there at all. A blast weapon held nearer than its own burst
    // radius refuses its own rounds, and one kept out only because its list
    // range is long leaves the shooter standing under fire with a working shot
    // in its pocket (guards at ninety units, e1m7a's gallery). With nothing
    // able to fire, the scoring alone is the guide, as ever.
    return selectBest(loadout, table, distance, situation, keep_range, distance != null) orelse
        selectBest(loadout, table, distance, situation, keep_range, false) orelse @intCast(loadout.weapon);
}
pub fn dischargesInWater(weapon: i32) bool {
    const entry = catalog.find(@intCast(weapon)) orelse return false;
    return entry.spec.combat == .bolt;
}
pub fn ranged(loadout: weapons.State, table: *const weapons.Table) bool {
    return rangedFor(loadout, table, .{});
}
/// Whether a weapon the situation allows can still shoot beyond close quarters.
pub fn rangedFor(loadout: weapons.State, table: *const weapons.Table, situation: Situation) bool {
    return beyondClose(loadout, table, null, situation);
}
/// The same question at a range in hand asks the gun to fire there, not merely
/// to be listed as reaching that far: a blast weapon inside its keep-out has
/// nothing to answer with, and does not hold the lane against a shorter shot
/// that does.
fn beyondClose(loadout: weapons.State, table: *const weapons.Table, distance: ?f32, situation: Situation) bool {
    for (catalog.entries) |entry| {
        const tuning = table.entries[entry.id];
        if (!entry.spec.auto_select or tuning.damage <= 0 or loadout.dk3Inventory & (@as(i32, 1) << entry.id) == 0 or loadout.ammo[entry.id] < tuning.ammoCost) continue;
        if (situation.excluded & (@as(i32, 1) << entry.id) != 0) continue;
        if (situation.wet and dischargesInWater(entry.id)) continue;
        if (situation.advancing and entry.spec.placed) continue;
        if ((entry.spec.bot_range orelse tuning.range) > 128) {
            if (distance) |range| {
                if (firesAt(entry, tuning, range)) return true;
                continue;
            }
            return true;
        }
    }
    return false;
}
/// The distance a hunt asks the body to hold its prey at: the gun's own reach,
/// and never beyond what that gun can actually hit with. Standing distance was
/// always a fraction of the listed reach and never less than ninety-six, which
/// left a short weapon refused at the range it was held — the disruptor's bolt
/// lands at eighty and the body was kept at ninety-six, aiming under fire and
/// never firing (e1m7a's west decks, twenty-three lives).
pub fn standOff(table: *const weapons.Table, weapon: u5) f32 {
    const entry = catalog.find(weapon) orelse return 96;
    const reach = entry.spec.bot_range orelse table.entries[weapon].range;
    return @min(@min(@as(f32, 900), @max(@as(f32, 96), reach * 0.6)), reach * 0.9);
}
pub fn attack(loadout: weapons.State, table: *const weapons.Table, distance: f32) bool {
    const entry = catalog.find(@intCast(loadout.weapon)) orelse return false;
    if (!entry.spec.auto_select or loadout.weaponstate == 1 or loadout.weaponstate == 2) return false;
    const tuning = table.entries[entry.id];
    if (tuning.damage <= 0 or distance > (entry.spec.bot_range orelse tuning.range)) return false;
    if (entry.spec.splash_hazard and distance < entry.spec.projectile.splash_radius) return false;
    if (entry.spec.bot_charge_ms > 0 and loadout.dk3Charge >= entry.spec.bot_charge_ms) return false;
    return loadout.ammo[entry.id] >= tuning.ammoCost;
}
test "a hunt stands no farther out than the gun in hand can hit" {
    var table: weapons.Table = .{};
    table.entries[catalog.classes.disruptor.id] = .{ .damage = 60, .range = 80 };
    table.entries[catalog.classes.shotcycler.id] = .{ .damage = 55, .range = 1000 };
    // A short shot is stood off inside its own reach, not a stride beyond it.
    try std.testing.expect(standOff(&table, catalog.classes.disruptor.id) <= 80);
    // A long shot keeps the standing distance it has always kept.
    try std.testing.expectEqual(@as(f32, 600), standOff(&table, catalog.classes.shotcycler.id));
}
test "bots reject unavailable ammunition and flashlight and release a charged Hammer" {
    var loadout: weapons.State = .{ .weapon = 1, .dk3Inventory = (1 << 1) | (1 << 2) | (1 << 28) };
    var table: weapons.Table = .{};
    table.entries[1] = .{ .damage = 15, .range = 128 };
    table.entries[2] = .{ .damage = 30, .range = 1000, .ammoCost = 2 };
    table.entries[28] = .{ .damage = 100, .range = 2000, .ammoCost = 1 };
    loadout.ammo[2] = 1;
    loadout.ammo[28] = 100;
    try std.testing.expectEqual(@as(u5, 1), select(loadout, &table, 500));
    loadout.ammo[2] = 2;
    try std.testing.expectEqual(@as(u5, 2), select(loadout, &table, 500));
    loadout.weapon = catalog.classes.hammer.id;
    table.entries[@intCast(loadout.weapon)] = .{ .damage = 50, .range = 128 };
    try std.testing.expect(attack(loadout, &table, 80));
    loadout.dk3Charge = 900;
    try std.testing.expect(!attack(loadout, &table, 80));
}
test "bots keep the ion blaster out of water and take up C4 only with room to spare" {
    const ion = catalog.classes.ion.id;
    const c4 = catalog.classes.c4.id;
    var loadout: weapons.State = .{ .weapon = ion, .dk3Inventory = (@as(i32, 1) << ion) | (@as(i32, 1) << c4) };
    var table: weapons.Table = .{};
    table.entries[ion] = .{ .damage = 20, .range = 2000 };
    table.entries[c4] = .{ .damage = 100, .range = 2000 };
    loadout.ammo[ion] = 50;
    loadout.ammo[c4] = 5;
    try std.testing.expectEqual(@as(u5, ion), select(loadout, &table, 400));
    try std.testing.expectEqual(@as(u5, c4), select(loadout, &table, 600));
    loadout.weapon = c4;
    try std.testing.expectEqual(@as(u5, c4), select(loadout, &table, 400));
    try std.testing.expectEqual(@as(u5, ion), select(loadout, &table, 200));
    loadout.weapon = ion;
    try std.testing.expect(dischargesInWater(ion));
    try std.testing.expect(selectFor(loadout, &table, 600, .{ .wet = true }) != ion);
    try std.testing.expectEqual(@as(u5, ion), selectFor(loadout, &table, 600, .{ .advancing = true }));
    const glove = catalog.weapons[0].id;
    loadout.dk3Inventory |= @as(i32, 1) << glove;
    table.entries[glove] = .{ .damage = 60, .range = 64 };
    try std.testing.expectEqual(@as(u5, glove), selectFor(loadout, &table, 40, .{ .advancing = true }));
    try std.testing.expectEqual(@as(u5, ion), selectFor(loadout, &table, 40, .{ .advancing = true, .ranged_first = true }));
}
test "bots never select or count an excluded weapon" {
    const ion = catalog.classes.ion.id;
    const c4 = catalog.classes.c4.id;
    var loadout: weapons.State = .{ .weapon = ion, .dk3Inventory = (@as(i32, 1) << ion) | (@as(i32, 1) << c4) };
    var table: weapons.Table = .{};
    table.entries[ion] = .{ .damage = 20, .range = 2000 };
    table.entries[c4] = .{ .damage = 100, .range = 2000 };
    loadout.ammo[ion] = 50;
    loadout.ammo[c4] = 5;
    try std.testing.expectEqual(@as(u5, c4), select(loadout, &table, 600));
    try std.testing.expectEqual(@as(u5, ion), selectFor(loadout, &table, 600, .{ .excluded = @as(i32, 1) << c4 }));
    try std.testing.expect(!rangedFor(loadout, &table, .{ .excluded = (@as(i32, 1) << c4) | (@as(i32, 1) << ion) }));
}
test "a blast gun inside its keep-out hands the shot to one that can fire" {
    const disruptor = catalog.classes.disruptor.id;
    const rocket = catalog.classes.sidewinder.id;
    var loadout: weapons.State = .{ .weapon = rocket, .dk3Inventory = (@as(i32, 1) << disruptor) | (@as(i32, 1) << rocket) };
    var table: weapons.Table = .{};
    table.entries[disruptor] = .{ .damage = 60, .range = 80 };
    table.entries[rocket] = .{ .damage = 70, .range = 2000 };
    loadout.ammo[rocket] = 6;
    // Inside the round's own burst the rocket shoots itself in the face and
    // says nothing; the short shot answers, though the rocket outclasses it.
    try std.testing.expectEqual(@as(u5, disruptor), selectFor(loadout, &table, 70, .{ .ranged_first = true, .advancing = true }));
    // Past the keep-out the rocket is back on its own, nothing altered.
    try std.testing.expectEqual(@as(u5, rocket), selectFor(loadout, &table, 300, .{ .ranged_first = true, .advancing = true }));
    // With neither able to fire, the choice stays put instead of hunting.
    try std.testing.expectEqual(@as(u5, rocket), selectFor(loadout, &table, 110, .{ .ranged_first = true, .advancing = true }));
}
