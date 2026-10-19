// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the reference's range test for a fighter that strikes up close and throws or
//! shoots further out. Re-rolled on every call, so chasing and attacking alternate at random in the
//! band between the two reaches.
/// Always within melee reach; within the ranged reach on a 60% roll; otherwise only between 100
/// and 250 units on a second 60% roll.
pub fn inRange(distance: f32, melee_range: f32, ranged_range: f32, ranged_roll: f32, chase_roll: f32) bool {
    return distance < melee_range or (distance < ranged_range and ranged_roll < 0.6) or (distance > 100 and distance < 250 and chase_roll < 0.6);
}
test "melee reach always, ranged reach and the near band on their rolls" {
    const t = @import("std").testing;
    try t.expect(inRange(119, 120, 800, 1, 1));
    try t.expect(!inRange(800, 120, 800, 0, 0));
    try t.expect(inRange(249, 120, 800, 1, 0.59));
    try t.expect(!inRange(300, 80, 600, 0.6, 0));
}
