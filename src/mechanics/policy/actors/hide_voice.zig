// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the voice an actor of the reference's worker family plays as it starts to
//! hide. Classes choose the thin or the stout table; this module names no class.
/// Half the time silent; otherwise a sniff, a death cry or (thin voices) a second death cry.
pub fn choose(thin: bool, chance: f32, choice: f32) ?[]const u8 {
    if (chance <= 0.5) return null;
    return if (choice > 0.75) "e1/Man_snifs.wav" else if (choice > 0.45) "e1/skinnydeath.wav" else if (thin) "e1/skinnydeath2.wav" else "e1/Man_snifs.wav";
}
test "hide voices keep the thin and stout tables" {
    const t = @import("std").testing;
    try t.expect(choose(true, 0.5, 0.8) == null);
    try t.expectEqualStrings("e1/skinnydeath2.wav", choose(true, 0.9, 0.4).?);
    try t.expectEqualStrings("e1/Man_snifs.wav", choose(false, 0.9, 0.4).?);
    try t.expectEqualStrings("e1/skinnydeath.wav", choose(false, 0.9, 0.5).?);
}
