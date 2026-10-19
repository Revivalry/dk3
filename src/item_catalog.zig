// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: the item classes, the authored key names and item models. Holds no
//! behaviour; the keys class is keys.zig.
pub const drugbox = @import("classes/items/drugbox/drugbox.zig");
pub const hosportal = @import("classes/items/hosportal/hosportal.zig");
pub const healthtree = @import("classes/items/healthtree/healthtree.zig");
pub const chest = @import("classes/items/chest/chest.zig");
const std = @import("std");
const Pair = struct { name: []const u8, value: []const u8 };
fn count(comptime bytes: []const u8) usize {
    @setEvalBranchQuota(100000);
    var n: usize = 0;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| if (std.mem.startsWith(u8, line, "DK_")) {
        n += 1;
    };
    return n;
}
fn read(comptime bytes: []const u8) [count(bytes)]Pair {
    @setEvalBranchQuota(100000);
    var result: [count(bytes)]Pair = undefined;
    var i: usize = 0;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "DK_")) continue;
        var fields = std.mem.splitScalar(u8, line, '"');
        _ = fields.next();
        const name = fields.next().?;
        _ = fields.next();
        result[i] = .{ .name = name, .value = fields.next().? };
        i += 1;
    }
    return result;
}
pub const keys = read(@embedFile("mechanics/policy/items/keys.def"));
pub const models = read(@embedFile("mechanics/policy/items/models.def"));
pub fn keyIndex(name: []const u8) ?u5 {
    // Keep historical bit positions for later rune/purifier keys. Containers
    // have no inventory identity and cannot satisfy a key lock.
    if (chest.kind(name) != null) return null;
    for (keys, 0..) |key, index| if (std.ascii.eqlIgnoreCase(key.name, name)) return @intCast(index);
    return null;
}
pub fn model(name: []const u8) ?[]const u8 {
    for (models) |entry| if (std.mem.eql(u8, entry.name, name)) return entry.value;
    return null;
}
pub const Keys = @import("classes/items/keys/keys.zig").Keys;
test "key identities, bomb consumption and complete purifier parts" {
    try std.testing.expect(keyIndex("item_wood_chest") == null and keyIndex("item_black_chest") == null);
    try std.testing.expectEqual(@as(usize, 32), keys.len);
    var inventory: Keys = .{};
    for ([_][]const u8{ "item_charcoal", "item_saltpeter", "item_sulphur" }) |name| try std.testing.expect(!inventory.collect(keyIndex(name).?));
    try std.testing.expect(inventory.collect(keyIndex("item_bottle").?));
    try std.testing.expect(inventory.has("item_bomb") and !inventory.has("item_bottle"));
    for (25..31) |index| {
        _ = inventory.collect(@intCast(index));
    }
    try std.testing.expect(inventory.has("item_purifier_shard2") and !inventory.has("item_purifier"));
    _ = inventory.collect(31);
    try std.testing.expect(inventory.has("item_purifier"));
}

test {
    _ = chest;
    _ = healthtree;
    _ = hosportal;
    _ = drugbox;
}
