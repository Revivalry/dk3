// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Native UI ABI boundary. Typed menu state and rendering live in ui/.
const std = @import("std");
const abi = @import("engine/abi.zig");
const engine = @import("engine/ui.zig");
const c = abi.c;
var menu: @import("mechanics/ui/menu.zig").Menu = .{};
export fn dllEntry(callback: abi.Syscall) callconv(.c) void {
    engine.gateway.bind(callback);
}
fn init() !void {
    _ = engine.gateway.call(c.UI_CVAR_REGISTER, .{ @as(?*c.vmCvar_t, null), @as([*:0]const u8, "dk3_runtime_build"), @as([*:0]const u8, @import("mechanics/player_state.zig").version), @as(isize, c.CVAR_USERINFO | c.CVAR_ROM) });
    engine.set("dk3_runtime_build", @import("mechanics/player_state.zig").version);
    try menu.init();
    engine.print("dk3 zig: native menus initialized\n");
}
fn failure(err: anyerror) void {
    var buffer: [192]u8 = undefined;
    _ = engine.gateway.call(c.UI_ERROR, .{(std.fmt.bufPrintZ(&buffer, "Zig UI: {s}", .{@errorName(err)}) catch unreachable).ptr});
}
export fn vmMain(command: c_int, arg0: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize, arg5: isize, arg6: isize, arg7: isize, arg8: isize, arg9: isize, arg10: isize, arg11: isize) callconv(.c) isize {
    _ = .{ arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 };
    switch (command) {
        c.UI_GETAPIVERSION => return c.UI_API_VERSION,
        c.UI_INIT => init() catch |err| failure(err),
        c.UI_SHUTDOWN => menu.close(),
        c.UI_SET_ACTIVE_MENU => if (arg0 == c.UIMENU_NONE) {
            menu.close();
        } else {
            menu.open();
        },
        // Native VM varargs carry C int payloads in pointer-sized slots. Negative
        // mouse deltas may have zero upper bits: decode the low signed 32 bits.
        c.UI_KEY_EVENT => menu.key(@truncate(arg0), @as(i32, @truncate(arg1)) != 0) catch |err| failure(err),
        c.UI_MOUSE_EVENT => menu.mouse(@truncate(arg0), @truncate(arg1)),
        c.UI_REFRESH => menu.render(@truncate(arg0)) catch |err| failure(err),
        c.UI_IS_FULLSCREEN => return @intFromBool(menu.active),
        c.UI_DRAW_CONNECT_SCREEN => menu.connect(),
        c.UI_CONSOLE_COMMAND => {
            // `dk3_menu_page <n>` opens the menu on a page (diagnostics and probes).
            var name: [32]u8 = @splat(0);
            var page: [8]u8 = @splat(0);
            _ = engine.gateway.call(c.UI_ARGV, .{ @as(isize, 0), &name, @as(isize, name.len) });
            if (!std.mem.eql(u8, std.mem.sliceTo(&name, 0), "dk3_menu_page")) return 0;
            _ = engine.gateway.call(c.UI_ARGV, .{ @as(isize, 1), &page, @as(isize, page.len) });
            menu.openPage(std.fmt.parseInt(usize, std.mem.sliceTo(&page, 0), 10) catch return 1);
            return 1;
        },
        else => return 0,
    }
    return 0;
}
