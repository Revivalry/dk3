// SPDX-License-Identifier: GPL-2.0-or-later
//! item-class: keys. Keys, quest parts and their assemblies (the bomb, the purifier).
const std = @import("std");
const keyIndex = @import("../../../item_catalog.zig").keyIndex;
pub const Keys = struct {
    mask: u32 = 0,
    quest: u32 = 0,
    /// Bomb assembly consumes its four parts; all other keys remain reusable.
    pub fn collect(self: *Keys, index: u5) bool {
        self.mask |= @as(u32, 1) << index;
        const parts: u32 = 0x0003c000;
        if (self.mask & parts != parts) return false;
        self.mask &= ~parts;
        self.quest |= 1;
        return true;
    }
    pub fn has(self: Keys, name: []const u8) bool {
        if (std.mem.eql(u8, name, "item_bomb")) return self.quest & 1 != 0;
        if (std.mem.eql(u8, name, "item_purifier")) return self.mask & 0xfe000000 == 0xfe000000;
        if (std.mem.eql(u8, name, "item_purifier_shard2")) return self.mask & 0x7c000000 == 0x7c000000;
        const index = keyIndex(name) orelse return false;
        return self.mask & (@as(u32, 1) << index) != 0;
    }
};
