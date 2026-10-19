// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: which pickup each authored item classname is, how it sits in the world and
//! when it returns. Data only; acquisition is items.zig.
const std = @import("std");
const catalog = @import("item_catalog");
const weapon_catalog = @import("weapon_catalog");
const character = @import("../../mechanics/domain/character.zig");
const Kind = @import("../../mechanics/domain/items.zig").Kind;
/// Default authored pickup rotation. Ammunition, health packs and quest parts
/// retain their placed orientation; world weapons rotate only in multiplayer.
pub fn rotates(kind: Kind, classname: []const u8, single_player: bool) bool {
    return switch (kind) {
        .weapon => !single_player,
        .armor => std.mem.endsWith(u8, classname, "_armor"),
        .soul, .save_gem, .invisibility => true,
        .key => std.mem.eql(u8, classname, "item_bottle"),
        else => false,
    };
}
pub fn canonicalName(name: []const u8) []const u8 {
    return if (std.mem.eql(u8, name, "item_vitality_boost")) "item_vita_boost" else name;
}
/// Health packs take the episode's own model: `models/eN/aN_hlth.dkm`, and the 50 pack the `2`
/// variant outside episode 2. Null for every other class.
pub fn episodeModel(name: []const u8, kind: Kind, episode: u8, buffer: []u8) !?[]const u8 {
    if (!std.mem.eql(u8, name, "item_health_25") and !std.mem.eql(u8, name, "item_health_50")) return null;
    return try std.fmt.bufPrint(buffer, "models/e{d}/a{d}_hlth{s}.dkm", .{ episode, episode, if (episode != 2 and kind.health == 50) @as([]const u8, "2") else "" });
}
/// The protective rings: the status bit each sets, and the boss class it wards off (its hits
/// land at a quarter).
pub const rings = [_]struct { name: []const u8, mask: u32, wards: []const u8 }{
    .{ .name = "item_ring_of_fire", .mask = 16, .wards = "monster_stavros" },
    .{ .name = "item_ring_of_lightning", .mask = 32, .wards = "monster_wyndrax" },
    .{ .name = "item_ring_of_undead", .mask = 64, .wards = "monster_nharre" },
};
pub fn classify(raw_name: []const u8) ?Kind {
    const name = canonicalName(raw_name);
    for (rings) |ring| if (std.mem.eql(u8, name, ring.name)) return .{ .ring = ring.mask };
    inline for (std.meta.fields(character.Attribute)) |field| if (std.mem.eql(u8, name, "item_" ++ field.name ++ "_boost")) return .{ .boost = @enumFromInt(field.value) };
    for ([_]struct { name: []const u8, kind: Kind }{
        .{ .name = "item_antidote", .kind = .antidote },      .{ .name = "item_invincibility", .kind = .invincibility },
        .{ .name = "item_wraithorb", .kind = .invisibility }, .{ .name = "item_envirosuit", .kind = .environment },
        .{ .name = "item_savegem", .kind = .save_gem },
    }) |entry| if (std.mem.eql(u8, name, entry.name)) return entry.kind;
    if (catalog.keyIndex(name)) |index| return .{ .key = index };
    for (weapon_catalog.entries) |entry| {
        if (weapon_catalog.named(entry.id, name)) return .{ .weapon = entry.id };
        if (entry.spec.ammo_class) |ammo| if (std.ascii.eqlIgnoreCase(name, ammo)) return .{ .ammunition = entry.id };
    }
    if (std.mem.eql(u8, name, "item_goldensoul")) return .soul;
    if (std.mem.startsWith(u8, name, "item_health_")) {
        const amount = std.fmt.parseInt(i32, name[12..], 10) catch return null;
        if (amount <= 0 or amount > 1000) return null;
        return .{ .health = amount };
    }
    for (armors) |armor| if (std.mem.eql(u8, name, armor.name)) return .{ .armor = .{ .capacity = armor.capacity, .absorption = armor.absorption } };
    return null;
}
const Armor = struct { name: []const u8, capacity: i32, absorption: i32 };
const armors = [_]Armor{
    .{ .name = "item_plasteel_armor", .capacity = 200, .absorption = 75 },
    .{ .name = "item_chromatic_armor", .capacity = 100, .absorption = 50 },
    .{ .name = "item_silver_armor", .capacity = 150, .absorption = 65 },
    .{ .name = "item_gold_armor", .capacity = 200, .absorption = 75 },
    .{ .name = "item_chainmail_armor", .capacity = 125, .absorption = 50 },
    .{ .name = "item_black_adamant_armor", .capacity = 250, .absorption = 80 },
    .{ .name = "item_kevlar_armor", .capacity = 100, .absorption = 40 },
    .{ .name = "item_ebonite_armor", .capacity = 200, .absorption = 75 },
    .{ .name = "item_megashield", .capacity = 400, .absorption = 75 },
};
/// The capacity of the armour worn, for an armour percentage: armour keeps only its amount and
/// absorption, so this is the smallest capacity of that absorption holding the amount.
pub fn armorCapacity(amount: i32, absorption: i32) i32 {
    var best: i32 = 0;
    var largest: i32 = 0;
    for (armors) |armor| if (armor.absorption == absorption) {
        largest = @max(largest, armor.capacity);
        if (armor.capacity >= amount and (best == 0 or armor.capacity < best)) best = armor.capacity;
    };
    return if (best > 0) best else if (largest > 0) largest else @max(amount, 100);
}
test "armour percentages measure against the worn armour's capacity" {
    try std.testing.expectEqual(@as(i32, 200), armorCapacity(150, 75));
    try std.testing.expectEqual(@as(i32, 400), armorCapacity(300, 75));
    try std.testing.expectEqual(@as(i32, 100), armorCapacity(80, 50));
    try std.testing.expectEqual(@as(i32, 125), armorCapacity(110, 50));
    try std.testing.expectEqual(@as(i32, 100), armorCapacity(0, 0));
}
pub fn respawnDelay(name: []const u8, single_player: bool) ?i64 {
    if (single_player or std.mem.eql(u8, name, "item_savegem")) return null;
    if (classify(name)) |kind| if (kind == .weapon) return weapon_catalog.find(kind.weapon).?.spec.pickup_respawn_ms;
    if (std.mem.eql(u8, name, "item_goldensoul") or std.mem.endsWith(u8, name, "_boost")) return 60000;
    if (std.mem.eql(u8, name, "item_megashield") or std.mem.eql(u8, name, "item_wraithorb") or std.mem.eql(u8, name, "item_invincibility")) return 300000;
    return 30000;
}
