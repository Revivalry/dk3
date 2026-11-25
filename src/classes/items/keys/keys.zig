// SPDX-License-Identifier: GPL-2.0-or-later
//! item-class: keys. Keys, quest parts and their assemblies (the bomb, the purifier).
const std = @import("std");
const keyIndex = @import("../../../item_catalog.zig").keyIndex;
pub const rotating_names = [_][]const u8{"item_bottle"};
pub const Bounds = struct { mins: [3]f32, maxs: [3]f32 };
/// Control cards use an authored touch volume independent of their thin model.
pub fn pickupBounds(name: []const u8) ?Bounds {
    for ([_][]const u8{ "item_control_card_red", "item_control_card_blue", "item_control_card_yellow", "item_control_card_green" }) |card| {
        if (std.mem.eql(u8, name, card)) return .{ .mins = .{ -10, -10, 0 }, .maxs = .{ 10, 10, 16 } };
    }
    return null;
}
pub const Keys = struct {
    mask: u32 = 0,
    quest: u32 = 0,
    history: u32 = 0,
    // Older saves did not retain key flags. The four control-card families
    // are use-once in the campaign; observed pickup flags replace this default.
    use_once: u32 = 0xf,
    unlocks: u32 = 0,
    known_flags: u32 = 0,
    /// Ordinary keys mean current possession; assembled ingredients retain
    /// their acquisition evidence after assembly and use of the bomb.
    pub fn acquired(self: Keys, index: u5) bool {
        return (self.mask | (self.history & 0x0003c000)) & (@as(u32, 1) << index) != 0 or
            (index >= 14 and index <= 17 and self.quest & 1 != 0);
    }
    /// Assembly consumes the four parts; lock use follows the pickup's flags.
    pub fn collect(self: *Keys, index: u5) bool {
        self.mask |= @as(u32, 1) << index;
        self.history |= @as(u32, 1) << index;
        const parts: u32 = 0x0003c000;
        if (self.mask & parts != parts) return false;
        self.mask &= ~parts;
        self.quest |= 1;
        return true;
    }
    pub fn noteFlags(self: *Keys, index: u5, flags: u32) void {
        const bit = @as(u32, 1) << index;
        self.known_flags |= bit;
        self.use_once = (self.use_once & ~bit) | (if (flags & 1 != 0) bit else 0);
        self.unlocks = (self.unlocks & ~bit) | (if (flags & 2 != 0) bit else 0);
    }
    pub const LockEffect = struct { consume: bool = false, unlock_targets: bool = false };
    pub fn lockEffect(self: Keys, name: []const u8) ?LockEffect {
        if (!self.has(name)) return null;
        if (std.mem.eql(u8, name, "item_bomb")) return .{ .consume = true };
        const index = keyIndex(name) orelse return .{};
        const bit = @as(u32, 1) << index;
        return .{ .consume = self.use_once & bit != 0, .unlock_targets = self.unlocks & bit != 0 };
    }
    pub fn consume(self: *Keys, name: []const u8) void {
        if (std.mem.eql(u8, name, "item_bomb")) {
            if (self.quest & 1 != 0) self.history |= 0x0003c000;
            self.quest &= ~@as(u32, 1);
        } else if (keyIndex(name)) |index| {
            const bit = @as(u32, 1) << index;
            self.history |= self.mask & bit;
            self.mask &= ~bit;
        }
    }
    pub fn has(self: Keys, name: []const u8) bool {
        if (std.mem.eql(u8, name, "item_bomb")) return self.quest & 1 != 0;
        if (std.mem.eql(u8, name, "item_purifier")) return self.mask & 0xfe000000 == 0xfe000000;
        if (std.mem.eql(u8, name, "item_purifier_shard2")) return self.mask & 0x7c000000 == 0x7c000000;
        const index = keyIndex(name) orelse return false;
        return self.mask & (@as(u32, 1) << index) != 0;
    }
};
test "one-use flags preserve current possession and bomb ingredient history" {
    var keys: Keys = .{};
    const green = keyIndex("item_control_card_green").?;
    _ = keys.collect(green);
    keys.noteFlags(green, 1);
    try std.testing.expect(keys.lockEffect("item_control_card_green").?.consume);
    keys.consume("item_control_card_green");
    try std.testing.expect(!keys.has("item_control_card_green") and !keys.acquired(green));
    _ = keys.collect(green);
    keys.noteFlags(green, 0);
    try std.testing.expect(!keys.lockEffect("item_control_card_green").?.consume);
    for (14..18) |index| _ = keys.collect(@intCast(index));
    keys.consume("item_bomb");
    try std.testing.expect(!keys.has("item_bomb"));
    for (14..18) |index| try std.testing.expect(keys.acquired(@intCast(index)));
}
