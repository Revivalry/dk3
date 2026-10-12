// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: burst fire, a gun that keeps firing at its shooter's enemy once per reference
//! server tick. Each firing class declares the styles of its bursts (`burst_styles`); the variant
//! saved with a burst names its style.
/// The persistent attack payloads this mechanism launches, by saved tag (domain/actor_attack.zig).
/// The tag predates the mechanism: saves keep it.
pub const attack_payloads = .{.{ .tag = "gunner_burst", .Payload = Burst, .modelless = true }};
/// Burst variants, named for their guns. Saved with each burst: append only.
pub const Kind = enum { commando, uzi, shotgun, chaingang };
/// Where a burst's muzzle flash appears.
pub const Muzzle = union(enum) {
    /// At the shooter's model tag `name`, or at both of `pair` when it fires two-handed; the
    /// flash model is scaled by `scale`.
    tags: struct { name: [:0]const u8, pair: ?[2][:0]const u8 = null, scale: f32 = 1 },
    /// At this offset (forward, right, up), doubled in size, with a light, on every other shot.
    offset: [3]f32,
};
/// How one burst variant fires and flashes.
pub const Style = struct {
    kind: Kind,
    /// Fires once as it starts.
    opening_shot: bool = false,
    /// Fires nothing itself: the shooter's own volley; the flash lasts 200 ms.
    flash_only: bool = false,
    /// Shots before it ends (0: until the shooter's model passes `stop_frame`).
    shots: u16 = 0,
    stop_frame: u16 = 0,
    flash_model: []const u8,
    muzzle: Muzzle,
};
pub const Burst = struct {
    kind: Kind,
    tuning: @import("weapon.zig").Tuning,
    next_ms: i64,
    shots: u16 = 0,
    two_hands: bool = false,
    pub fn rebase(self: *Burst, delta: i64) !void {
        try @import("saved_time.zig").shift(&self.next_ms, delta);
    }
    /// Whether a restored burst is one its style could have fired at `stepped_ms`.
    pub fn validSaved(self: Burst, _: i64, stepped_ms: i64) bool {
        const t = self.tuning;
        if (self.next_ms <= stepped_ms or t.damage < 0 or t.damage > 1000000 or t.random_damage < 0 or t.random_damage > 1000000 or t.range <= 0 or t.range > 65536) return false;
        for (t.offset) |axis| if (!@import("std").math.isFinite(axis) or @abs(axis) > 1024) return false;
        for (t.spread) |axis| if (!@import("std").math.isFinite(axis) or axis < 0 or axis > 8192) return false;
        const burst_style = style(self.kind);
        if (burst_style.shots != 0 and self.shots >= burst_style.shots) return false;
        return self.next_ms - stepped_ms <= firstDelay(self.kind);
    }
};
pub const render_tag = 10013;
/// A burst names its shooter in `otherEntityNum` (linked_tag_classes.zig).
pub const linked_body_tags = [_]i32{render_tag};
/// These callbacks request .01 s but run once per reference 100 ms server frame.
pub const tick_ms: i64 = 100;
/// The delay before the burst's first tick (a flash-only burst ends then).
pub fn firstDelay(kind: Kind) i64 {
    return if (style(kind).flash_only) 200 else tick_ms;
}
/// Every declared style, indexed by variant.
const styles: [@typeInfo(Kind).@"enum".fields.len]Style = blk: {
    var table: [@typeInfo(Kind).@"enum".fields.len]?Style = @splat(null);
    for (@import("../../../actor_catalog.zig").policies) |policy| if (@hasDecl(policy, "burst_styles")) for (policy.burst_styles) |entry| {
        if (table[@intFromEnum(entry.kind)] != null) @compileError("burst variant styled twice: " ++ @tagName(entry.kind));
        table[@intFromEnum(entry.kind)] = entry;
    };
    var result: [table.len]Style = undefined;
    for (table, 0..) |entry, index| result[index] = entry orelse @compileError("burst variant without a style: " ++ @tagName(@as(Kind, @enumFromInt(index))));
    break :blk result;
};
pub fn style(kind: Kind) Style {
    return styles[@intFromEnum(kind)];
}
