// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: venom spit, a straight poisoning glob (5 s life). Each launching class declares
//! the styles of its spit (`spit_styles`); the variant saved with a glob names its style.
/// The persistent attack payloads this mechanism launches, by saved tag (domain/actor_attack.zig).
/// The tag predates the mechanism: saves keep it.
pub const attack_payloads = .{.{ .tag = "rotworm_spit", .Payload = Spit }};
/// Spit variants, named for their launchers. Saved with each glob: append only.
pub const Kind = enum { rotworm, medusa };
pub const Spit = struct {
    damage: f32,
    kind: Kind = .rotworm,
    pub fn validSaved(self: Spit, born_ms: i64, stepped_ms: i64) bool {
        return self.damage > 0 and self.damage <= 1000000 and stepped_ms <= born_ms + 5000;
    }
};
/// How one spit variant looks and sounds.
pub const Style = struct {
    kind: Kind,
    model: []const u8,
    scale: f32,
    /// The classname credited with its damage.
    attacker_class: []const u8,
    /// Played at the launcher as it spits.
    sound: []const u8 = "",
    /// Leaves a green particle trail.
    trail: bool = false,
};
pub const render_tag = 10008;
/// Every declared style, indexed by variant.
const styles: [@typeInfo(Kind).@"enum".fields.len]Style = blk: {
    var table: [@typeInfo(Kind).@"enum".fields.len]?Style = @splat(null);
    for (@import("../../../actor_catalog.zig").policies) |policy| if (@hasDecl(policy, "spit_styles")) for (policy.spit_styles) |entry| {
        if (table[@intFromEnum(entry.kind)] != null) @compileError("spit variant styled twice: " ++ @tagName(entry.kind));
        table[@intFromEnum(entry.kind)] = entry;
    };
    var result: [table.len]Style = undefined;
    for (table, 0..) |entry, index| result[index] = entry orelse @compileError("spit variant without a style: " ++ @tagName(@as(Kind, @enumFromInt(index))));
    break :blk result;
};
pub fn style(kind: Kind) Style {
    return styles[@intFromEnum(kind)];
}
