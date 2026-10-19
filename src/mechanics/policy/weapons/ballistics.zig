// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Pure flight/contact contracts. Each concrete weapon owns its extra state.
const v = @import("vector.zig");
/// A projectile's flight state: one variant per description that declares `flight_tag` (the saved
/// tag) and `BallisticState`. Exactly one description's state is `void`: the stateless flight,
/// which new projectiles start with.
pub const State = blk: {
    const all = @import("../../../game/weapons/classes.zig").all;
    var count: usize = 0;
    for (all) |W| {
        if (@hasDecl(W, "flight_tag")) count += 1;
    }
    var names: [count][]const u8 = undefined;
    var types: [count]type = undefined;
    var values: [count]u8 = undefined;
    var at: usize = 0;
    for (all) |W| if (@hasDecl(W, "flight_tag")) {
        names[at] = W.flight_tag;
        types[at] = W.BallisticState;
        values[at] = at;
        at += 1;
    };
    break :blk @Union(.auto, @Enum(u8, .exhaustive, &names, &values), &names, &types, &@splat(.{}));
};
/// The stateless flight variant.
pub const stateless: State = blk: {
    var found: ?State = null;
    for (@typeInfo(State).@"union".fields) |field| if (field.type == void) {
        if (found != null) @compileError("two stateless flight variants");
        found = @unionInit(State, field.name, {});
    };
    break :blk found orelse @compileError("no stateless flight variant");
};
pub fn isStateless(state: State) bool {
    return @import("std").meta.activeTag(state) == @import("std").meta.activeTag(stateless);
}
pub const Launch = struct { muzzle: v.Vec, pitch: f32 = 0, roll: f32 = 0 };
pub const Frame = struct { age_ms: i64, delta_ms: u32, distance: f32, wet: bool, was_wet: bool, velocity: v.Vec, speed: f32 = 0 };
pub const Motion = struct { velocity: v.Vec, gravity: f32 = 0, remove: bool = false };
pub const Contact = struct { damageable: bool, living: bool, brush: bool };
pub const Response = union(enum) { remove, direct, stick: u16, bounce: f32, explode };
pub const Hit = struct { damage: f32, age_ms: i64, lifetime_ms: i64, self_hit: bool = false, victim_class: []const u8 = "" };
pub const Damage = struct { amount: f32, effect: @import("affliction.zig").Effect = .none };
/// Close crosshair contact may be behind the offset muzzle. Preserve that aim;
/// forcing the view direction sends the bolt below/alongside a nearby target.
pub fn aimDirection(muzzle: v.Vec, crosshair: v.Vec) v.Vec {
    return v.normal(v.sub(crosshair, muzzle));
}

test "a bolt converges on close crosshair contact even behind the muzzle" {
    const std = @import("std");
    // Captured ordinary e1m1a skeet encounter: the old forward-only guard missed.
    const start: v.Vec = .{ -691.340, -1397.472, 516.076 };
    const hit: v.Vec = .{ -690.139, -1401.486, 523.946 };
    const forward: v.Vec = .{ -0.995, 0.012, 0.104 };
    const direction = aimDirection(start, hit);
    try std.testing.expect(v.dot(direction, forward) < 0);
    try std.testing.expectApproxEqAbs(@as(f32, 1), v.length(direction), 0.0001);
    try std.testing.expect(v.distance(hit, v.madd(start, v.distance(start, hit), direction)) < 0.001);
    try std.testing.expectEqual(v.Vec{ 1, 0, 0 }, aimDirection(.{ 20, 4, 16 }, .{ 2000, 4, 16 }));
    try std.testing.expectEqual(v.zero, aimDirection(start, start));
}
