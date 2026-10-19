// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: rocket flight. Each launching class declares the styles of its rockets
//! (`rocket_styles`); the variant saved with a rocket names its style.
/// The persistent attack payloads this class launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{.{ .tag = "rocket", .Payload = Rocket }};
const std = @import("std");
/// Rocket variants, named for their launchers. Saved with each rocket: append only.
pub const Kind = enum { vermin, battleboar, rocketdude, mp_left, mp_right };
pub const Rocket = struct {
    kind: Kind,
    damage: f32,
    speed: f32,
    divisor: u3 = 7,
    next_ms: i64,
    frame: u2 = 0,
    pub fn rebase(self: *Rocket, delta: i64) !void {
        try @import("saved_time.zig").shift(&self.next_ms, delta);
    }
    pub fn validSaved(self: Rocket, born_ms: i64, stepped_ms: i64) bool {
        return validSaved_(self, born_ms, stepped_ms);
    }
};
pub const render_tag = 10007;
/// Where a rocket leaves its launcher.
pub const Origin = union(enum) {
    /// The aimed muzzle, raised by this many units.
    raised: f32,
    /// A muzzle offset (right, forward, up) along the launcher's facing.
    muzzle: [3]f32,
    /// Ahead of the launcher along its view to the target turned by these angles.
    turned: struct { pitch: f32, yaw: f32, distance: f32 },
    /// Beside the launcher: this far right and this far up.
    beside: struct { right: f32, up: f32 },
};
/// How one rocket variant flies and looks.
pub const Style = struct {
    kind: Kind,
    model: []const u8 = "models/e4/me_missile.dkm",
    model_scale: f32 = 1,
    glow: []const u8 = "models/global/e_sflorange.sp2",
    glow_scale: f32 = 1.45,
    light_radius: f32 = 145,
    light_green: f32 = 0.45,
    sound: []const u8 = "e4/m_rockgangataka.wav",
    origin: Origin = .{ .raised = 0 },
    /// Launched along the launcher's facing instead of its aim.
    faces_launcher: bool = false,
    /// Launch speed is the aidata speed divided by this; it speeds up while `accelerates`.
    divisor: u3 = 7,
    accelerates: bool = true,
    lifetime_ms: i64 = 4000,
};
/// Every declared style, indexed by variant.
const styles: [@typeInfo(Kind).@"enum".fields.len]Style = blk: {
    var table: [@typeInfo(Kind).@"enum".fields.len]?Style = @splat(null);
    for (@import("../../../actor_catalog.zig").policies) |policy| if (@hasDecl(policy, "rocket_styles")) for (policy.rocket_styles) |entry| {
        if (table[@intFromEnum(entry.kind)] != null) @compileError("rocket variant styled twice: " ++ @tagName(entry.kind));
        table[@intFromEnum(entry.kind)] = entry;
    };
    var result: [table.len]Style = undefined;
    for (table, 0..) |entry, index| result[index] = entry orelse @compileError("rocket variant without a style: " ++ @tagName(@as(Kind, @enumFromInt(index))));
    break :blk result;
};
pub fn style(kind: Kind) Style {
    return styles[@intFromEnum(kind)];
}
/// Whether a restored rocket is one this mechanism could have produced.
fn validSaved_(rocket: Rocket, born_ms: i64, stepped_ms: i64) bool {
    const rocket_style = style(rocket.kind);
    const next_bound: i64 = if (rocket_style.accelerates) 100 else rocket_style.lifetime_ms;
    return rocket.damage > 0 and rocket.damage <= 1000000 and rocket.speed > 0 and rocket.speed <= 65536 and rocket.divisor != 0 and rocket.frame <= 2 and stepped_ms <= born_ms + rocket_style.lifetime_ms and rocket.next_ms > stepped_ms and rocket.next_ms <= stepped_ms + next_bound;
}
pub fn accelerate(rocket: *Rocket) void {
    if (!style(rocket.kind).accelerates) return;
    if (rocket.divisor > 1) rocket.divisor -= 1;
    rocket.frame = @intCast((@as(u3, rocket.frame) + 1) % 3);
    rocket.next_ms += 100;
}
test "a non-accelerating rocket keeps its speed; accelerating rockets speed up" {
    const t = std.testing;
    var rocket: Rocket = .{ .kind = .vermin, .damage = 10, .speed = 450, .next_ms = 10 };
    for (0..6) |_| accelerate(&rocket);
    try t.expectEqual(@as(u3, 1), rocket.divisor);
    try t.expectEqual(@as(i64, 610), rocket.next_ms);
    try t.expectEqual(@as(u2, 0), rocket.frame);
    try t.expectEqual(@as(i64, 5000), style(.battleboar).lifetime_ms);
    try t.expectEqual(@as(i64, 4000), style(.rocketdude).lifetime_ms);
    var boar: Rocket = .{ .kind = .battleboar, .damage = 10, .speed = 450, .divisor = 1, .next_ms = 10 };
    accelerate(&boar);
    try t.expectEqual(@as(i64, 10), boar.next_ms);
}
