// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the picture a save shows in the Load menu. After writing a save the server
//! sends `dk3_saveshot <name> <clean|hud>`; the client takes a screenshot under that name
//! (`screenshots/<name>.jpg`) and, for a save the player asked for, leaves the HUD out of it.
const std = @import("std");
const engine = @import("../../engine/client.zig");
const c = @import("../../engine/abi.zig").c;

/// The picture asked for.
var pending: [64]u8 = @splat(0);
var pending_clean = false;
/// A clean picture hides the HUD for three drawn frames before the screenshot is asked for and four
/// after: the renderer captures a finished frame next to the one the command runs in.
var before: u8 = 0;
var after: u8 = 0;

pub fn command() void {
    var token: [32]u8 = @splat(0);
    _ = engine.gateway.call(c.CG_ARGV, .{ @as(isize, 0), &token, @as(isize, token.len) });
    if (!std.mem.eql(u8, std.mem.sliceTo(&token, 0), "dk3_saveshot")) return;
    var name: [64]u8 = @splat(0);
    var mode: [16]u8 = @splat(0);
    _ = engine.gateway.call(c.CG_ARGV, .{ @as(isize, 1), &name, @as(isize, name.len) });
    _ = engine.gateway.call(c.CG_ARGV, .{ @as(isize, 2), &mode, @as(isize, mode.len) });
    const shot = std.mem.sliceTo(&name, 0);
    if (shot.len == 0) return;
    for (shot) |char| if (!std.ascii.isAlphanumeric(char) and char != '-' and char != '_') return;
    pending = name;
    pending_clean = std.mem.eql(u8, std.mem.sliceTo(&mode, 0), "clean");
}
/// Called once per drawn frame, before the HUD: takes an asked-for picture.
pub fn update() void {
    if (after > 0) after -= 1;
    const shot = std.mem.sliceTo(&pending, 0);
    if (shot.len == 0) return;
    if (pending_clean and before == 0) {
        before = 3;
        return;
    }
    if (before > 1) {
        before -= 1;
        return;
    }
    before = 0;
    var text: [96]u8 = undefined;
    const line = std.fmt.bufPrintZ(&text, "screenshotJPEG {s}\n", .{shot}) catch return;
    _ = engine.gateway.call(c.CG_SENDCONSOLECOMMAND, .{line.ptr});
    if (pending_clean) after = 4;
    pending = @splat(0);
}
/// Whether this frame leaves the HUD out (a clean save picture is being taken).
pub fn hidesHud() bool {
    return before > 0 or after > 0;
}
