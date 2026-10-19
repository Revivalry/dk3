// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the seeded linear congruential stream entities carry (`Random`), saved with
//! them so a restored world draws the same numbers.
pub const Random = struct {
    state: u32,
    pub fn next(self: *Random) f32 {
        self.state = self.state *% 1664525 +% 1013904223;
        return @as(f32, @floatFromInt(self.state >> 8)) / 16777216;
    }
};
