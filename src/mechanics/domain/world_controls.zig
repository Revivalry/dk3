// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: authored world controls, each with its class-owned serializable state
//! (control_classes.zig).
/// One variant per world-control state a class declares (control_classes.zig).
pub const Action = blk: {
    @setEvalBranchQuota(100_000);
    const classes = @import("../../game/domain/control_classes.zig").classes;
    var count: usize = 0;
    for (classes) |Class| count += Class.controls.len;
    var names: [count][]const u8 = undefined;
    var types: [count]type = undefined;
    var values: [count]u8 = undefined;
    var at: usize = 0;
    for (classes) |Class| for (Class.controls) |control| {
        names[at] = control.tag;
        types[at] = control.State;
        values[at] = at;
        at += 1;
    };
    break :blk @Union(.auto, @Enum(u8, .exhaustive, &names, &values), &names, &types, &@splat(.{}));
};
pub const State = struct { action: Action, uses: u32 = 0, ready_ms: i64 = 0 };
