// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: fish. Aquatic wildlife and Dopefish own their goals; numeric tuning is supplied.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{ .{ .kind = .fish, .traits = .{ .ambient = true, .aquatic = true, .remains = .{ .always = true } } }, .{ .kind = .dopefish, .traits = .{ .attack = .ground, .aquatic = true, .remains = .{ .always = true } } } };
/// The actor field holding this class's `State` (its saved key).
pub const state_field = "fish";
/// Swimmers cruise at their walk speed.
pub fn parseTuning(_: anytype, _: class_traits.Kind, definition: anytype) !void {
    if (definition.walk_speed <= 0) return error.InvalidSwimmerSpeed;
}
pub const attacks = [_][]const u8{"atak"};
const saved = @import("../../../mechanics/policy/actors/saved_time.zig");
pub const State = struct {
    start: [3]f32 = @splat(0),
    destination: ?[3]f32 = null,
    wander_until_ms: ?i64 = null,
    motion_ms: ?i64 = null,
    owner: u32 = 0,
    aggressive: bool = false,
    /// Moves saved timestamps onto the restoring clock.
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.deadline(&self.wander_until_ms, delta);
        try saved.deadline(&self.motion_ms, delta);
    }
    /// Rejects restored values this class could never hold.
    pub fn validate(self: State, _: saved.Check) !void {
        if (!saved.point(self.start)) return error.InvalidSavedActor;
        if (self.destination) |destination| if (!saved.point(destination)) return error.InvalidSavedActor;
    }
    /// Maps saved persistent ids onto the restored world.
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.owner);
    }
};
pub fn aggression(previous: bool, distance: f32, roll: f32) bool {
    if (distance > 175) return false;
    if (distance < 150 and roll < 0.5) return true;
    return previous;
}
/// Sighted within its disengage distance (175), the dopefish engages at once.
pub fn firstSighting(distance: f32) bool {
    return distance <= 175;
}
pub fn turn(speed: f32) f32 {
    return if (speed == 0) 0.01 else speed * 0.0005;
}
pub fn surface(velocity: [3]f32, water: u2) [3]f32 {
    var result = velocity;
    if (water < 3 and result[2] > 0) result[2] = 0;
    return result;
}
test "Dopefish keeps its engagement hysteresis and strict random boundary" {
    const t = @import("std").testing;
    try t.expect(aggression(false, 149, 0.49));
    try t.expect(!aggression(false, 149, 0.5));
    try t.expect(!aggression(false, 150, 0));
    try t.expect(aggression(true, 175, 0.9));
    try t.expect(!aggression(true, 175.01, 0));
    try t.expectEqual([3]f32{ 10, 20, 0 }, surface(.{ 10, 20, 30 }, 2));
    try t.expectEqual([3]f32{ 10, 20, -30 }, surface(.{ 10, 20, -30 }, 2));
    try t.expectEqual([3]f32{ 10, 20, 30 }, surface(.{ 10, 20, 30 }, 3));
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "e_goldfish", .kind = .fish, .run = "swima" },
    .{ .classname = "e_greyfish", .kind = .fish, .run = "swima" },
    .{ .classname = "e_guppy", .kind = .fish, .run = "swima" },
    .{ .classname = "e_guppy2", .kind = .fish, .run = "swima" },
    .{ .classname = "e_dopefish", .kind = .dopefish, .idle = "swima", .run = "swima" },
};
