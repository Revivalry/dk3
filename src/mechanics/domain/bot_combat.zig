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
fn available(loadout: weapons.State, table: *const weapons.Table, entry: catalog.Entry) bool {
    const tuning = table.entries[entry.id];
    return entry.spec.auto_select and tuning.damage > 0 and
        loadout.dk3Inventory & (@as(i32, 1) << entry.id) != 0 and
        (loadout.ammo[entry.id] >= tuning.ammoCost or entry.spec.bot_contact_melee_range != null);
}
/// A requested weapon is a preference, never an inventory grant.
pub fn preferred(loadout: weapons.State, table: *const weapons.Table, wanted: u5) ?u5 {
    const entry = catalog.find(wanted) orelse return null;
    return if (available(loadout, table, entry.*)) wanted else null;
}
/// An authored preference cannot bypass the pilot's current safety admission.
pub fn permittedPreference(loadout: weapons.State, table: *const weapons.Table, wanted: u5, excluded: i32) ?u5 {
    if (excluded & (@as(i32, 1) << wanted) != 0) return null;
    return preferred(loadout, table, wanted);
}
/// Whether the gun can pull its trigger at this range: within its reach, and a
/// blast round with room to burst. The firing step applies the same test, so a
/// weapon taken up here is never one the shot is refused for afterwards.
fn firesAt(entry: catalog.Entry, reach: f32, distance: f32) bool {
    if (distance > reach) return false;
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
        const empty = loadout.ammo[entry.id] < tuning.ammoCost;
        if (!available(loadout, table, entry)) continue;
        if (situation.excluded & (@as(i32, 1) << entry.id) != 0) continue;
        if (situation.wet and dischargesInWater(entry.id)) continue;
        if (situation.advancing and entry.spec.placed) continue;
        const reach = reachFor(loadout, table, entry.id);
        if (keep_range and reach <= 128) continue;
        if (firing_only) if (distance) |range| {
            if (!firesAt(entry, reach, range)) continue;
        } else continue;
        var score = tuning.damage;
        if (distance) |range| {
            if (range > reach) score *= 0.01;
            // A splash weapon is taken up only with room to spare (an enemy
            // closes in while it is raised) and put away inside its radius.
            const margin: f32 = if (entry.id == loadout.weapon) 1 else 1.6;
            if (entry.spec.splash_hazard and range < entry.spec.projectile.splash_radius * margin) score *= 0.01;
            // A projectile leaves the muzzle ahead of the player: point blank
            // it starts beyond (or inside) the target and misses. Hitscan and
            // melee weapons strike there.
            if (range < 96 and tuning.speed > 0 and !empty) score *= 0.05;
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
/// A usable melee weapon still answers an aggressor after ammunition is lost.
pub fn armedFor(loadout: weapons.State, table: *const weapons.Table, situation: Situation) bool {
    return selectBest(loadout, table, null, situation, false, false) != null;
}
/// A recoverable round in flight must not immediately abandon the fight.
/// A successful return resets the window; a lost round still times out.
pub fn ammunition(armed: bool, now: i64, empty_since: *?i64, grace: u16) enum { ready, waiting, empty } {
    if (armed) {
        empty_since.* = null;
        return .ready;
    }
    if (empty_since.* == null) empty_since.* = now;
    return if (now - empty_since.*.? < grace) .waiting else .empty;
}
pub fn rearmDelay(loadout: weapons.State) u16 {
    var delay: u16 = 0;
    for (catalog.entries) |entry| {
        if (loadout.dk3Inventory & (@as(i32, 1) << entry.id) != 0) delay = @max(delay, entry.spec.bot_rearm_ms);
    }
    return delay;
}
pub fn reserveLow(loadout: weapons.State, table: *const weapons.Table, weapon: u5) bool {
    const entry = catalog.find(weapon) orelse return false;
    return table.entries[weapon].ammoCost > 0 and entry.spec.bot_ammo_reserve > 0 and loadout.ammo[weapon] <= entry.spec.bot_ammo_reserve;
}
test "ammunition conservation never suppresses an ammo-free weapon or a recoverable sole round" {
    const loadout: weapons.State = .{};
    var table: weapons.Table = .{};
    table.entries[catalog.classes.hammer.id].ammoCost = 0;
    table.entries[catalog.classes.sidewinder.id].ammoCost = 1;
    table.entries[catalog.classes.discus.id].ammoCost = 1;
    try std.testing.expect(!reserveLow(loadout, &table, catalog.classes.hammer.id));
    try std.testing.expect(reserveLow(loadout, &table, catalog.classes.sidewinder.id));
    try std.testing.expect(!reserveLow(loadout, &table, catalog.classes.discus.id));
}
test "recoverable ammunition holds a fight only through its bounded return window" {
    var empty_since: ?i64 = null;
    try std.testing.expect(ammunition(false, 100, &empty_since, 3000) == .waiting);
    try std.testing.expect(ammunition(false, 3099, &empty_since, 3000) == .waiting);
    try std.testing.expect(ammunition(false, 3100, &empty_since, 3000) == .empty);
    try std.testing.expect(ammunition(true, 3200, &empty_since, 3000) == .ready);
    try std.testing.expect(empty_since == null);
    try std.testing.expect(ammunition(false, 3300, &empty_since, 3000) == .waiting);
    try std.testing.expect(ammunition(false, 3300, &empty_since, 0) == .empty);
}
test "an ammo-free melee weapon remains usable and respects target exclusions" {
    const id = catalog.classes.daikatana.id;
    var table: weapons.Table = .{};
    table.entries[id] = .{ .damage = 52, .range = 80, .ammoCost = 0 };
    var loadout: weapons.State = .{ .weapon = id, .dk3Inventory = @as(i32, 1) << id };
    try std.testing.expect(armedFor(loadout, &table, .{}));
    try std.testing.expect(!rangedFor(loadout, &table, .{}));
    try std.testing.expect(!armedFor(loadout, &table, .{ .excluded = @as(i32, 1) << id }));
    try std.testing.expect(standOff(&table, id) < 56);
    loadout.dk3Inventory = 0;
    try std.testing.expect(!armedFor(loadout, &table, .{}));
}
test "an emptied weapon retains only its class-declared close strike" {
    const id = catalog.classes.discus.id;
    var table: weapons.Table = .{};
    table.entries[id] = .{ .damage = 35, .range = 2000, .ammoCost = 1 };
    const loadout: weapons.State = .{ .weapon = id, .dk3Inventory = @as(i32, 1) << id };
    try std.testing.expect(armedFor(loadout, &table, .{}));
    try std.testing.expect(!rangedFor(loadout, &table, .{}));
    try std.testing.expect(attack(loadout, &table, 90));
    try std.testing.expect(!attack(loadout, &table, 120));
    try std.testing.expect(!armedFor(loadout, &table, .{ .excluded = @as(i32, 1) << id }));
    try std.testing.expect(standOffFor(loadout, &table, id) < 96);
    try std.testing.expectEqual(@as(i32, 0), loadout.ammo[id]);
}
/// Whether a weapon the situation allows can still shoot beyond close quarters.
pub fn rangedFor(loadout: weapons.State, table: *const weapons.Table, situation: Situation) bool {
    return beyondClose(loadout, table, null, situation);
}
/// Whether putting away the weapon in hand leaves a ranged option that
/// this situation and target actually admit.
pub fn rangedAlternative(loadout: weapons.State, table: *const weapons.Table, situation: Situation) bool {
    var others = loadout;
    others.dk3Inventory &= ~(@as(i32, 1) << @intCast(loadout.weapon));
    return rangedFor(others, table, situation);
}
test "an immune target does not turn ammunition into an alternative to its only usable weapon" {
    const hammer = catalog.classes.hammer.id;
    const discus = catalog.classes.discus.id;
    var table: weapons.Table = .{};
    table.entries[hammer] = .{ .damage = 120, .range = 256, .ammoCost = 0 };
    table.entries[discus] = .{ .damage = 35, .range = 2000, .ammoCost = 1 };
    var loadout: weapons.State = .{ .weapon = hammer, .dk3Inventory = (@as(i32, 1) << hammer) | (@as(i32, 1) << discus) };
    loadout.ammo[discus] = 1;
    try std.testing.expect(rangedAlternative(loadout, &table, .{ .advancing = true }));
    const immunity = ~(@as(i32, 1) << hammer);
    try std.testing.expect(!rangedAlternative(loadout, &table, .{ .advancing = true, .excluded = immunity }));
    try std.testing.expect(armedFor(loadout, &table, .{ .excluded = immunity }));
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
                if (firesAt(entry, entry.spec.bot_range orelse tuning.range, range)) return true;
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
pub fn reachFor(loadout: weapons.State, table: *const weapons.Table, weapon: u5) f32 {
    const entry = catalog.find(weapon) orelse return 0;
    if (loadout.ammo[weapon] < table.entries[weapon].ammoCost) if (entry.spec.bot_contact_melee_range) |reach| return reach;
    return entry.spec.bot_range orelse table.entries[weapon].range;
}
pub fn standOffFor(loadout: weapons.State, table: *const weapons.Table, weapon: u5) f32 {
    return standOffReach(reachFor(loadout, table, weapon));
}
pub fn standOff(table: *const weapons.Table, weapon: u5) f32 {
    const entry = catalog.find(weapon) orelse return 96;
    const reach = entry.spec.bot_range orelse table.entries[weapon].range;
    return standOffReach(reach);
}
fn standOffReach(reach: f32) f32 {
    if (reach <= 128) return reach * 0.8;
    return @min(@min(@as(f32, 900), @max(@as(f32, 96), reach * 0.6)), reach * 0.9);
}
/// Once started, finish the declared charge across transient aim/range loss.
pub fn maintainCharge(loadout: weapons.State) bool {
    const entry = catalog.find(@intCast(loadout.weapon)) orelse return false;
    return entry.spec.bot_charge_ms > 0 and loadout.dk3AttackHeld != 0 and
        loadout.dk3Charge < entry.spec.bot_charge_ms and loadout.weaponstate != 1 and loadout.weaponstate != 2;
}
pub fn attack(loadout: weapons.State, table: *const weapons.Table, distance: f32) bool {
    const entry = catalog.find(@intCast(loadout.weapon)) orelse return false;
    if (!entry.spec.auto_select or loadout.weaponstate == 1 or loadout.weaponstate == 2) return false;
    const tuning = table.entries[entry.id];
    if (tuning.damage <= 0 or distance > reachFor(loadout, table, entry.id)) return false;
    if (entry.spec.splash_hazard and distance < entry.spec.projectile.splash_radius) return false;
    if (entry.spec.bot_charge_ms > 0 and loadout.dk3AttackHeld != 0 and loadout.dk3Charge >= entry.spec.bot_charge_ms) return false;
    return loadout.ammo[entry.id] >= tuning.ammoCost or entry.spec.bot_contact_melee_range != null;
}
test "stored ammunition does not make an unowned requested weapon available" {
    const id = catalog.classes.sidewinder.id;
    var table: weapons.Table = .{};
    table.entries[id] = .{ .damage = 120, .ammoCost = 1 };
    var loadout: weapons.State = .{};
    loadout.ammo[id] = 72;
    try std.testing.expectEqual(@as(?u5, null), preferred(loadout, &table, id));
    loadout.dk3Inventory |= @as(i32, 1) << id;
    try std.testing.expectEqual(@as(?u5, id), preferred(loadout, &table, id));
    try std.testing.expectEqual(@as(?u5, null), permittedPreference(loadout, &table, id, @as(i32, 1) << id));
    loadout.ammo[id] = 0;
    try std.testing.expectEqual(@as(?u5, null), preferred(loadout, &table, id));
}
test "a charged weapon releases once and can start its next attack with the previous charge value" {
    const id = catalog.classes.hammer.id;
    var table: weapons.Table = .{};
    table.entries[id] = .{ .damage = 120, .range = 256, .ammoCost = 0 };
    var loadout: weapons.State = .{ .weapon = id, .dk3Charge = 900, .dk3AttackHeld = 1 };
    try std.testing.expect(attack(loadout, &table, 64));
    try std.testing.expect(!attack(loadout, &table, 512));
    try std.testing.expect(maintainCharge(loadout));
    loadout.dk3Charge = 1800;
    try std.testing.expect(!attack(loadout, &table, 64));
    try std.testing.expect(!maintainCharge(loadout));
    loadout.dk3AttackHeld = 0;
    try std.testing.expect(attack(loadout, &table, 64));
    try std.testing.expect(!maintainCharge(loadout));
}
test "a hunt stands no farther out than the gun in hand can hit" {
    var table: weapons.Table = .{};
    table.entries[catalog.classes.disruptor.id] = .{ .damage = 60, .range = 80 };
    table.entries[catalog.classes.shotcycler.id] = .{ .damage = 55, .range = 1000 };
    // A short shot is stood off inside its own reach, not a stride beyond it.
    try std.testing.expect(standOff(&table, catalog.classes.disruptor.id) <= 80);
    // The class's effective spread distance overrides its maximum trace.
    try std.testing.expect(standOff(&table, catalog.classes.shotcycler.id) <= catalog.classes.shotcycler.spec.bot_range.?);
}
test "a distant target gets a ranged weapon instead of an ineffective spread burst" {
    const ion = catalog.classes.ion.id;
    const spread = catalog.classes.shotcycler.id;
    var loadout: weapons.State = .{ .weapon = spread, .dk3Inventory = (@as(i32, 1) << ion) | (@as(i32, 1) << spread) };
    var table: weapons.Table = .{};
    table.entries[ion] = .{ .damage = 24, .range = 2000, .ammoCost = 1 };
    table.entries[spread] = .{ .damage = 70, .range = 1000, .ammoCost = 1 };
    loadout.ammo[ion] = 100;
    loadout.ammo[spread] = 36;
    try std.testing.expectEqual(ion, selectFor(loadout, &table, 620, .{}));
    try std.testing.expectEqual(spread, selectFor(loadout, &table, 192, .{}));
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
    loadout.dk3Charge = 1800;
    loadout.dk3AttackHeld = 1;
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
