// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Public engine ABI only. No game/client private headers enter domain code.
const std = @import("std");
/// Engine map coordinate limit (ioquake3 qcommon/qfiles.h MAX_WORLD_COORD).
pub const world_coordinate_limit: f32 = 128 * 1024;
pub const c = @cImport({
    @cDefine("DK3_GAME", "1");
    @cInclude("q_shared.h");
    @cInclude("g_public.h");
    @cInclude("cg_public.h");
    @cInclude("tr_types.h");
    @cInclude("ui_public.h");
    @cInclude("keycodes.h");
    @cInclude("bg_public.h");
    @cInclude("botlib.h");
    @cInclude("be_aas.h");
});
pub const Syscall = *const fn (isize, ...) callconv(.c) isize;
/// Native presentation ownership, using two otherwise unused upstream game
/// bits inside the existing 19-bit entity eFlags transport.
pub const Presentation = struct {
    pub const gameplay_body: i32 = c.EF_KAMIKAZE;
    pub const cinematic_body: i32 = c.EF_MOVER_STOP;
};
pub const Gateway = struct {
    callback: ?Syscall = null,
    owner: ?std.Thread.Id = null,
    pub fn bind(self: *Gateway, callback: Syscall) void {
        self.callback = callback;
        self.owner = std.Thread.getCurrentId();
    }
    pub fn call(self: *const Gateway, operation: c_int, args: anytype) isize {
        std.debug.assert(self.owner != null and self.owner.? == std.Thread.getCurrentId());
        return @call(.auto, self.callback.?, .{@as(isize, operation)} ++ args);
    }
};
pub const EntityProjection = extern struct { state: c.entityState_t, shared: c.entityShared_t };
comptime {
    if (@sizeOf(EntityProjection) != @sizeOf(c.sharedEntity_t) or @alignOf(EntityProjection) != @alignOf(c.sharedEntity_t) or
        @offsetOf(EntityProjection, "state") != @offsetOf(c.sharedEntity_t, "s") or
        @offsetOf(EntityProjection, "shared") != @offsetOf(c.sharedEntity_t, "r")) @compileError("engine entity projection ABI mismatch");
}
