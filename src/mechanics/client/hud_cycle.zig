// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the HUD cycle keys. `hud_cycle` steps weapons, items (skipped without any),
//! then every class panel that takes part (skipped while absent), wrapping to weapons;
//! `hud_next`/`hud_prev`/`hud_use` act on the current mode, and drive the attribute picker while
//! skill points wait (reference Inventory_Open_f, Inventory_Next_f, Inventory_Prev_f,
//! Inventory_Use_f). Class panels join through client_classes `cycle_panels`.
const std = @import("std");
const presenters = @import("../../game/client/client_classes.zig").presenters;

pub const commands = [_][*:0]const u8{ "hud_cycle", "hud_next", "hud_prev", "hud_use" };

/// What the HUD does for a cycle key outside the class panels.
pub const Action = enum { none, weapon_next, weapon_prev, items_open, items_close, item_next, item_prev, attribute_next, attribute_prev, attribute_apply };
pub const Context = struct { has_items: bool, points_pending: bool };

const panel_count = count: {
    var total: usize = 0;
    for (presenters) |Class| {
        if (@hasDecl(Class, "cycle_panels")) total += Class.cycle_panels;
    }
    break :count total;
};
const first_panel = 2;

var mode: usize = 0;

pub fn reset() void {
    mode = 0;
}

/// Handles one cycle key; returns null for names that are not cycle keys.
pub fn console(name: []const u8, context: Context, now_ms: i64) ?Action {
    const index = for (commands, 0..) |command, i| {
        if (std.mem.eql(u8, std.mem.span(command), name)) break i;
    } else return null;
    return switch (index) {
        0 => cycle(context, now_ms),
        1, 2 => step(if (index == 1) 1 else -1, context, now_ms),
        3 => apply(context, now_ms),
        else => unreachable,
    };
}

fn cycle(context: Context, now_ms: i64) Action {
    const was_items = mode == 1;
    if (mode >= first_panel) _ = panel(mode - first_panel, .close, 0, now_ms);
    var next = mode;
    while (true) {
        next += 1;
        if (next == 1 and !context.has_items) continue;
        if (next >= first_panel + panel_count) {
            next = 0;
            break;
        }
        if (next < first_panel or panel(next - first_panel, .open, 0, now_ms)) break;
    }
    mode = next;
    if (mode == 1) return .items_open;
    return if (was_items) .items_close else .none;
}
fn step(direction: i32, context: Context, now_ms: i64) Action {
    if (context.points_pending) return if (direction > 0) .attribute_next else .attribute_prev;
    if (mode >= first_panel) {
        _ = panel(mode - first_panel, .step, direction, now_ms);
        return .none;
    }
    if (mode == 1) return if (direction > 0) .item_next else .item_prev;
    return if (direction > 0) .weapon_next else .weapon_prev;
}
fn apply(context: Context, now_ms: i64) Action {
    if (context.points_pending) return .attribute_apply;
    if (mode >= first_panel) _ = panel(mode - first_panel, .apply, 0, now_ms);
    return .none;
}

const Operation = enum { open, close, step, apply };
/// Runs an operation on the class panel at a flattened slot; `open` reports whether it opened.
fn panel(slot: usize, operation: Operation, direction: i32, now_ms: i64) bool {
    var base: usize = 0;
    inline for (presenters) |Class| if (@hasDecl(Class, "cycle_panels")) {
        if (slot < base + Class.cycle_panels) {
            const local = slot - base;
            switch (operation) {
                .open => return Class.cycleOpen(local, now_ms),
                .close => Class.cycleClose(local, now_ms),
                .step => Class.cycleStep(local, direction, now_ms),
                .apply => Class.cycleApply(local, now_ms),
            }
            return true;
        }
        base += Class.cycle_panels;
    };
    return false;
}

test "the cycle skips absent items and wraps; skill points take next, prev and use" {
    reset();
    const plain: Context = .{ .has_items = false, .points_pending = false };
    // Without items the first press goes past the items mode (to a panel or back to weapons).
    _ = cycle(plain, 0);
    try std.testing.expect(mode != 1);
    reset();
    try std.testing.expectEqual(Action.items_open, cycle(.{ .has_items = true, .points_pending = false }, 0));
    try std.testing.expectEqual(Action.item_next, step(1, plain, 0));
    try std.testing.expectEqual(Action.attribute_prev, step(-1, .{ .has_items = true, .points_pending = true }, 0));
    try std.testing.expectEqual(Action.attribute_apply, apply(.{ .has_items = true, .points_pending = true }, 0));
    reset();
    try std.testing.expectEqual(Action.weapon_prev, step(-1, plain, 0));
}
