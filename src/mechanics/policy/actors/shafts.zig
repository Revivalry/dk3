// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: thrown and shot shafts (spears, bolts, knives). Each launching class declares
//! the styles of its shafts (`shaft_styles`); the variant saved with a shaft names its style.
/// The persistent attack payloads this mechanism launches, by saved tag (domain/actor_attack.zig).
pub const attack_payloads = .{.{ .tag = "shaft", .Payload = Shaft }};
/// Shaft variants, named for their launchers. Saved with each shaft: append only.
pub const Kind = enum { centurion, fletcher, thief, harpy };
/// What a shaft does when it touches something (the reference's shared touch handlers).
pub const Touch = enum {
    /// Sticks in the world with an armour clank; drops off what it hits; rests 5 s, then fades.
    knife,
    /// Like `knife`, but stuck it is pulled back 12 units and pitched over with a body-hit sound,
    /// and it vanishes in the sky.
    axe,
    /// A glowing bolt that flies 10 s and vanishes on contact (an impact sound on the world).
    magic,
};
/// How one shaft variant flies, looks and lands.
pub const Style = struct {
    kind: Kind,
    model: []const u8,
    /// The classname credited with its damage.
    attacker_class: []const u8,
    touch: Touch = .knife,
    /// End-over-end spin in flight, degrees of pitch per second.
    spin: f32 = 0,
};
pub const Shaft = struct {
    kind: Kind,
    damage: f32,
    phase: enum { flying, falling, resting } = .flying,
    contact_ms: ?i64 = null,
    pub fn rebase(self: *Shaft, delta: i64) !void {
        try @import("saved_time.zig").deadline(&self.contact_ms, delta);
    }
    /// A flying shaft expires after its flight time; a stuck one rests 5 s. Magic shafts never stick.
    pub fn validSaved(self: Shaft, born_ms: i64, stepped_ms: i64) bool {
        if (self.damage <= 0 or self.damage > 1000000 or (self.phase == .flying) != (self.contact_ms == null)) return false;
        const expiry = if (self.contact_ms) |at| at + 5000 else born_ms + flightTime(self.kind);
        if (stepped_ms > expiry) return false;
        if (self.contact_ms) |at| if (at < born_ms or at > stepped_ms or magic(self.kind)) return false;
        return true;
    }
};
pub const render_tag = 10009;
/// Every declared style, indexed by variant.
const styles: [@typeInfo(Kind).@"enum".fields.len]Style = blk: {
    var table: [@typeInfo(Kind).@"enum".fields.len]?Style = @splat(null);
    for (@import("../../../actor_catalog.zig").policies) |policy| if (@hasDecl(policy, "shaft_styles")) for (policy.shaft_styles) |entry| {
        if (table[@intFromEnum(entry.kind)] != null) @compileError("shaft variant styled twice: " ++ @tagName(entry.kind));
        table[@intFromEnum(entry.kind)] = entry;
    };
    var result: [table.len]Style = undefined;
    for (table, 0..) |entry, index| result[index] = entry orelse @compileError("shaft variant without a style: " ++ @tagName(@as(Kind, @enumFromInt(index))));
    break :blk result;
};
pub fn style(kind: Kind) Style {
    return styles[@intFromEnum(kind)];
}
pub fn magic(kind: Kind) bool {
    return style(kind).touch == .magic;
}
pub fn model(kind: Kind) []const u8 {
    return style(kind).model;
}
pub fn flightTime(kind: Kind) i64 {
    return if (magic(kind)) 10000 else 3000;
}
