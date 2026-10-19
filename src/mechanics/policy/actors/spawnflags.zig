// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the authored monster spawnflags, read the same way by every class
//! (reference AI_SetSpawnValue). A class decides which goals it supports; the bits mean the same
//! thing everywhere.
/// Roam the node graph while no enemy is known.
pub const wander: u32 = 0x1;
/// Follow the authored path named by `target`.
pub const path_follow: u32 = 0x2;
/// The reference treats node wander exactly like `wander`.
pub const node_wander: u32 = 0x4;
/// Random-direction wander. The reference goal dereferences a follower's owner, so it is only
/// defined for sidekicks; monsters do not honour it natively.
pub const random_wander: u32 = 0x8;
pub const ignore_player: u32 = 0x10;
pub const sniper: u32 = 0x20;
/// Never leave the spawn point: no chase, cover run, side-step or wander; turning still works.
pub const do_not_move: u32 = 0x80;
/// Classes that support it fight from hide nodes instead of chasing.
pub const take_cover: u32 = 0x200;
pub fn wanders(flags: u32) bool {
    return flags & (wander | node_wander) != 0;
}
pub fn moves(flags: u32) bool {
    return flags & do_not_move == 0;
}
test "node wander is plain wander; do-not-move pins the actor" {
    const t = @import("std").testing;
    try t.expect(wanders(node_wander) and wanders(wander) and !wanders(random_wander));
    try t.expect(moves(take_cover) and !moves(do_not_move | wander));
}
