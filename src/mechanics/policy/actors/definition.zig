// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: what each actor classname declares: its kind, idle/run/death clips and
//! classname-level choices. Each policy lists its classnames' definitions in `definitions`.
const Kind = @import("kinds.zig").Kind;
pub const Definition = struct {
    kind: Kind,
    classname: []const u8,
    idle: []const u8 = "amba",
    run: []const u8 = "runa",
    death: []const u8 = "diea",
    nitro_immune: bool = false,
    companion_choices: [3]u2 = .{ 0, 1, 2 },
    witness_range: f32 = 512,
    panic_ms: i64 = 6000,
};
