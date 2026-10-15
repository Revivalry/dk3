// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: UI controls.
const std = @import("std");
const engine = @import("../../engine/ui.zig");
const c = engine.c;
pub const Entry = struct { label: []const u8, command: [:0]const u8 };
pub const entries = [_]Entry{
    .{ .label = "Forward", .command = "+forward" },                  .{ .label = "Back", .command = "+back" },
    .{ .label = "Left", .command = "+moveleft" },                    .{ .label = "Right", .command = "+moveright" },
    .{ .label = "Jump / climb", .command = "+moveup" },              .{ .label = "Crouch", .command = "+movedown" },
    .{ .label = "Attack", .command = "+attack" },                    .{ .label = "Walk", .command = "+speed" },
    .{ .label = "Next weapon", .command = "weapnext" },              .{ .label = "Previous weapon", .command = "weapprev" },
    .{ .label = "Use", .command = "use" },                           .{ .label = "Inventory", .command = "inventory" },
    .{ .label = "Next inventory item", .command = "invnext" },       .{ .label = "Previous inventory item", .command = "invprev" },
    .{ .label = "Next attribute", .command = "attribute_next" },     .{ .label = "Increase attribute", .command = "attribute_increase" },
    .{ .label = "HUD cycle", .command = "hud_cycle" },               .{ .label = "HUD use", .command = "hud_use" },
    .{ .label = "HUD next", .command = "hud_next" },                 .{ .label = "HUD previous", .command = "hud_prev" },
    .{ .label = "Quicksave", .command = "save quick" },              .{ .label = "Quickload", .command = "load quick" },
    .{ .label = "Sidekicks follow", .command = "companion follow" }, .{ .label = "Sidekicks stay", .command = "companion stay" },
    .{ .label = "Sidekicks attack", .command = "companion attack" }, .{ .label = "Sidekicks get item", .command = "companion get" },
    .{ .label = "Sidekick commands", .command = "sidekick_next" },   .{ .label = "Give sidekick order", .command = "sidekick_apply" },
    .{ .label = "Switch sidekick", .command = "sidekick_swap" },
};
/// Default binds the game added after a profile was saved, in versions. `upgrade` brings a saved
/// profile forward once: renamed commands keep their keys, a key still holding its old default takes
/// the new one, and a new command unbound everywhere takes its default key while that key is free.
pub const binds_version = 2;
const Rename = struct { old: []const u8, new: [:0]const u8 };
const renames = [_]Rename{ .{ .old = "companion wait", .new = "companion stay" }, .{ .old = "companion pickup", .new = "companion get" } };
const Replace = struct { key: i32, old: []const u8, new: [:0]const u8 };
/// The reference's HUD cycle key (default.cfg `o hud_cycle`) replaces the old attribute default.
const replacements = [_]Replace{.{ .key = 'o', .old = "attribute_increase", .new = "hud_cycle" }};
const Default = struct { key: i32, command: [:0]const u8 };
const added = [_]Default{
    .{ .key = 'o', .command = "hud_cycle" },      .{ .key = 'k', .command = "hud_prev" },           .{ .key = 'l', .command = "hud_next" },
    .{ .key = ';', .command = "hud_use" },        .{ .key = 'u', .command = "attribute_increase" }, .{ .key = 'z', .command = "sidekick_next" },
    .{ .key = 'x', .command = "sidekick_apply" }, .{ .key = 'v', .command = "sidekick_swap" },
};
pub fn upgrade() void {
    var buffer: [256]u8 = undefined;
    if (engine.number("dk3_binds") >= binds_version) return;
    for (1..c.MAX_KEYS) |key_value| {
        const code: i32 = @intCast(key_value);
        const command = engine.binding(code, &buffer);
        for (renames) |rename| if (std.ascii.eqlIgnoreCase(command, rename.old)) engine.bind(code, rename.new);
    }
    for (replacements) |replacement| if (std.ascii.eqlIgnoreCase(engine.binding(replacement.key, &buffer), replacement.old)) engine.bind(replacement.key, replacement.new);
    for (added) |default| {
        if (boundTo(default.command) == null and engine.binding(default.key, &buffer).len == 0) engine.bind(default.key, default.command);
    }
    engine.register("dk3_binds", "0");
    engine.setNumber("dk3_binds", binds_version);
}
fn boundTo(command: []const u8) ?i32 {
    var buffer: [256]u8 = undefined;
    for (1..c.MAX_KEYS) |key_value| if (std.ascii.eqlIgnoreCase(engine.binding(@intCast(key_value), &buffer), command)) return @intCast(key_value);
    return null;
}
pub const Capture = struct {
    action: ?usize = null,
    conflict: ?i32 = null,
    pub fn key(self: *Capture, key_code: i32) bool {
        const action = self.action orelse return false;
        if (key_code == c.K_ESCAPE) {
            self.* = .{};
            return true;
        }
        if (key_code <= 0 or key_code >= c.MAX_KEYS or key_code == '`' or key_code == '~') return true;
        if (self.conflict) |conflict| {
            if (key_code == c.K_ENTER) {
                assign(action, conflict);
                self.* = .{};
            }
            return true;
        }
        var prior: [256]u8 = undefined;
        const command = engine.binding(key_code, &prior);
        if (command.len > 0 and !std.ascii.eqlIgnoreCase(command, entries[action].command)) {
            self.conflict = key_code;
        } else {
            assign(action, key_code);
            self.* = .{};
        }
        return true;
    }
};
fn assign(action: usize, key_code: i32) void {
    var buffer: [256]u8 = undefined;
    for (1..c.MAX_KEYS) |key_value| {
        const code: i32 = @intCast(key_value);
        if (std.ascii.eqlIgnoreCase(engine.binding(code, &buffer), entries[action].command)) engine.bind(code, "");
    }
    engine.bind(key_code, entries[action].command);
}
pub fn bound(action: usize) ?i32 {
    return boundTo(entries[action].command);
}
