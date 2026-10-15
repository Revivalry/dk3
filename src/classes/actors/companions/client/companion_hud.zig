// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. The owner's sidekick HUD: a flap for each party member in view (face by
//! health, health and armour bars, ammunition gauge) and the command window that orders them.
//! Reference behaviour: cl_scrn.cpp (flaps, bars, command window), cl_selector.cpp and
//! cl_sidekick.cpp (docs/class-porting/companions.md).
const std = @import("std");
const engine = @import("../../../../engine/client.zig");
const c = @import("../../../../engine/abi.zig").c;
const canvas = @import("../../../../engine/canvas.zig");
const policy = @import("actor_catalog").companions;
const draw: canvas.Canvas(.client) = .{ .gateway = &engine.gateway };

/// Flap opacity and its fade (the reference's statusbar_alpha 0.6 and 0.04 a frame at 30 Hz).
const flap_alpha: f32 = 0.6;
const flap_rate: f32 = 1.2;
/// Bars, gauge icons and labels draw at a fixed opacity while their panel shows (INFO_ALPHA).
const info_alpha: f32 = 0.7;
/// The command window fades in at twice the flap rate, holds after the last key, then fades out.
const window_alpha: f32 = 0.75;
const window_rate: f32 = 2.4;
const window_hold_ms: i64 = 5250;

pub const console_commands = [_][*:0]const u8{ "sidekick_next", "sidekick_prev", "sidekick_apply", "sidekick_swap" };

const Flap = struct { alpha: f32 = 0 };
var flaps: [2]Flap = .{ .{}, .{} };
var window: f32 = 0;
var window_until: i64 = 0;
var selected: usize = 0;
var commanding: ?policy.Identity = null;
var statuses: [2]policy.Status = .{ .{}, .{} };
var last_ms: i64 = 0;
var art: ?Art = null;

const Art = struct {
    faces: [2][5]c.qhandle_t,
    ammo_border: c.qhandle_t,
    ammo: [4]c.qhandle_t,
    window: c.qhandle_t,
    select: c.qhandle_t,
    portraits: [2]c.qhandle_t,
    white: c.qhandle_t,
    font: canvas.Font,
    fn load() !Art {
        var result: Art = undefined;
        for ([_][]const u8{ "mikiko", "superfly" }, 0..) |name, who| for (0..5) |frame| {
            result.faces[who][frame] = try picture("{s}{c}", .{ name, @as(u8, 'a') + @as(u8, @intCast(frame)) });
        };
        result.ammo_border = try picture("ammo", .{});
        // ammo4 .. ammo1: empty, low, good, plenty.
        for (&result.ammo, 0..) |*handle, level| handle.* = try picture("ammo{d}", .{4 - level});
        result.window = try picture("command_window", .{});
        result.select = try picture("command_select", .{});
        result.portraits = .{ try picture("command_mikiko", .{}), try picture("command_superfly", .{}) };
        result.white = draw.shader("white");
        result.font = try draw.font("statbar_font");
        return result;
    }
};
fn picture(comptime format: []const u8, arguments: anytype) !c.qhandle_t {
    var name: [64]u8 = undefined;
    return draw.shader(try std.fmt.bufPrintZ(&name, "pics/statusbar/" ++ format ++ ".tga", arguments));
}

pub fn reset() void {
    flaps = .{ .{}, .{} };
    window = 0;
    window_until = 0;
    selected = 0;
    commanding = null;
    statuses = .{ .{}, .{} };
    last_ms = 0;
    art = null;
}

/// The face frame for a health share: a (unhurt) to e (the reference's calc_faceframe_index).
pub fn faceFrame(health_pct: u7) usize {
    return (100 - @as(usize, std.math.clamp(health_pct, 1, 100))) / 20;
}
/// Who the window orders: the chosen sidekick while it lives, else Mikiko, else Superfly.
pub fn commanded(chosen: ?policy.Identity, status: [2]policy.Status) ?policy.Identity {
    const alive = struct {
        fn f(value: policy.Status) bool {
            return value.exists and value.health_pct > 0;
        }
    }.f;
    if (chosen) |who| if (alive(status[@intFromEnum(who)])) return who;
    if (alive(status[0])) return .mikiko;
    if (alive(status[1])) return .superfly;
    return null;
}

/// Local console commands: open the window and step its selection, give the selected order, or
/// switch which sidekick the window orders (reference CL_ParseSelectorCommand, sidekick_swap).
pub fn console(name: []const u8, now_ms: i64) bool {
    const index = for (console_commands, 0..) |command, i| {
        if (std.mem.eql(u8, std.mem.span(command), name)) break i;
    } else return false;
    const who = commanded(commanding, statuses) orelse return true;
    switch (index) {
        0, 1 => stepSelection(if (index == 0) 1 else -1),
        2 => giveOrder(who),
        3 => {
            const other: policy.Identity = if (who == .mikiko) .superfly else .mikiko;
            commanding = commanded(other, statuses) orelse who;
            sound("global/skill_selector.wav");
        },
        else => unreachable,
    }
    if (commanding == null) commanding = who;
    show(now_ms);
    return true;
}
fn stepSelection(direction: i32) void {
    const open = window > 0;
    if (open) selected = (selected + (if (direction > 0) @as(usize, 1) else policy.command_labels.len - 1)) % policy.command_labels.len;
    sound(if (open) "global/skill_selector.wav" else "global/skill_start.wav");
}
fn giveOrder(who: policy.Identity) void {
    if (window <= 0) return sound("global/skill_start.wav");
    var buffer: [64]u8 = undefined;
    const command: policy.Command = @enumFromInt(selected);
    const text = std.fmt.bufPrintZ(&buffer, "sidekick_{s} {s}", .{ @tagName(command), @tagName(who) }) catch return;
    _ = engine.gateway.call(c.CG_SENDCLIENTCOMMAND, .{text.ptr});
    sound("global/skill_increase.wav");
}
fn show(now_ms: i64) void {
    window = @max(window, 0.01);
    window_until = now_ms + window_hold_ms;
}

/// HUD cycle modes (hud_cycle): Superfly's command mode, then Mikiko's (reference INV_MODE_SIDEKICK1/2).
pub const cycle_panels = 2;
fn cycleIdentity(slot: usize) policy.Identity {
    return if (slot == 0) .superfly else .mikiko;
}
fn living(who: policy.Identity) bool {
    const status = statuses[@intFromEnum(who)];
    return status.exists and status.health_pct > 0;
}
pub fn cycleOpen(slot: usize, now_ms: i64) bool {
    const who = cycleIdentity(slot);
    if (!living(who)) return false;
    commanding = who;
    sound("global/skill_start.wav");
    show(now_ms);
    return true;
}
pub fn cycleClose(slot: usize, now_ms: i64) void {
    _ = slot;
    window_until = @min(window_until, now_ms);
}
pub fn cycleStep(slot: usize, direction: i32, now_ms: i64) void {
    const who = cycleIdentity(slot);
    if (!living(who)) return;
    commanding = who;
    stepSelection(direction);
    show(now_ms);
}
pub fn cycleApply(slot: usize, now_ms: i64) void {
    const who = cycleIdentity(slot);
    if (!living(who)) return;
    commanding = who;
    giveOrder(who);
    show(now_ms);
}
fn sound(name: []const u8) void {
    const handle = engine.registerSound(name) catch return;
    _ = engine.gateway.call(c.CG_S_STARTLOCALSOUND, .{ @as(isize, handle), @as(isize, c.CHAN_AUTO) });
}

/// Whether the command window holds the inventory column (the weapon list yields it).
pub fn holdsInventoryColumn() bool {
    return window > 0;
}

/// Draws over the HUD from the party status the server reports in the player's stats.
pub fn hud(state: *const c.playerState_t, now_ms: i64, display: c.glconfig_t) void {
    const elapsed: f32 = if (last_ms == 0) 0 else @as(f32, @floatFromInt(std.math.clamp(now_ms - last_ms, 0, 250))) / 1000;
    last_ms = now_ms;
    for (&statuses, [_]policy.Identity{ .mikiko, .superfly }) |*status, who| {
        const index = policy.statIndex(who);
        status.* = policy.Status.unpack(.{ state.stats[index], state.stats[index + 1] });
    }
    for (&flaps, statuses) |*flap, status| {
        flap.alpha = std.math.clamp(flap.alpha + (if (status.visible) flap_rate else -flap_rate) * elapsed, 0, flap_alpha);
    }
    const who = commanded(commanding, statuses);
    if (who == null or now_ms >= window_until) {
        window = @max(0, window - window_rate * elapsed);
    } else if (window > 0) window = @min(window_alpha, window + window_rate * elapsed);
    if (flaps[0].alpha <= 0 and flaps[1].alpha <= 0 and window <= 0) return;
    if (art == null) art = Art.load() catch return;
    const pictures = &art.?;
    const width: f32 = @floatFromInt(display.vidWidth);
    const height: f32 = @floatFromInt(display.vidHeight);
    const scale = @min(width / 640, height / 480 * std.math.clamp(engine.number("cg_hudScale", 1), 0.75, 1.5));
    // Mikiko's flap at the bottom left, Superfly's at the bottom right (gauge mirrored).
    for (flaps, statuses, 0..) |flap, status, i| {
        if (flap.alpha <= 0) continue;
        const right = i == 1;
        const x = if (right) width - 124 * scale else 0;
        draw.rect(x, height - 87 * scale, 128 * scale, 128 * scale, pictures.faces[i][faceFrame(status.health_pct)], .{ 1, 1, 1, flap.alpha });
        if (status.ammo != .none) {
            const border_x = if (right) width - 135 * scale else 69 * scale;
            draw.color(&.{ 1, 1, 1, flap.alpha });
            draw.image(border_x, height - (if (right) @as(f32, 73) else 72) * scale, 64 * scale, 64 * scale, if (right) .{ 1, 0, 0, 1 } else .{ 0, 0, 1, 1 }, pictures.ammo_border);
            draw.color(null);
            const icon_x = if (right) width - 110 * scale else 75 * scale;
            draw.rect(icon_x, height - (if (right) @as(f32, 64) else 63) * scale, 32 * scale, 32 * scale, pictures.ammo[@intFromEnum(status.ammo) - 1], .{ 1, 1, 1, info_alpha });
        }
        // Health (red) and armour (yellow): 3 wide, up to 100/2.8 tall, 15 apart.
        const bars_x = if (right) width - 97 * scale else 78 * scale;
        for ([_]u7{ status.health_pct, status.armor_pct }, [_]canvas.Color{ .{ 1, 0, 0, info_alpha }, .{ 1, 1, 0, info_alpha } }, 0..) |value, tint, bar| {
            const full: f32 = 100.0 / 2.8;
            const tall = @as(f32, @floatFromInt(value)) / 2.8;
            draw.rect(bars_x + @as(f32, @floatFromInt(bar)) * 15 * scale, height - (43 - (full - tall)) * scale, 3 * scale, tall * scale, pictures.white, tint);
        }
    }
    if (window <= 0 or who == null) return;
    // The command window: the ordered sidekick's portrait above five orders, the selected one lit.
    const left = width - 128 * scale;
    draw.rect(left, height - 386 * scale, 128 * scale, 128 * scale, pictures.portraits[@intFromEnum(who.?)], .{ 1, 1, 1, window });
    draw.rect(left, height - 256 * scale, 128 * scale, 256 * scale, pictures.window, .{ 1, 1, 1, window });
    const rows = [_]f32{ 248, 212, 187, 152, 127 };
    draw.rect(left, height - (rows[selected] + 3) * scale, 128 * scale, 32 * scale, pictures.select, .{ 1, 1, 1, window });
    for (policy.command_labels, rows) |label, row| {
        const text_x = width - 48 * scale - pictures.font.metrics.width(label, scale) * 0.5;
        draw.text(pictures.font, text_x, height - row * scale, scale, label, .{ 1, 1, 1, @min(info_alpha, window) });
    }
}

test "faces darken in fifths of health and the window orders a living sidekick" {
    try std.testing.expectEqual(@as(usize, 0), faceFrame(100));
    try std.testing.expectEqual(@as(usize, 1), faceFrame(79));
    try std.testing.expectEqual(@as(usize, 4), faceFrame(0));
    const both = [2]policy.Status{ .{ .exists = true, .health_pct = 50 }, .{ .exists = true, .health_pct = 80 } };
    try std.testing.expectEqual(policy.Identity.mikiko, commanded(null, both).?);
    try std.testing.expectEqual(policy.Identity.superfly, commanded(.superfly, both).?);
    const fallen = [2]policy.Status{ .{ .exists = true, .health_pct = 0 }, .{ .exists = true, .health_pct = 80 } };
    try std.testing.expectEqual(policy.Identity.superfly, commanded(.mikiko, fallen).?);
    try std.testing.expect(commanded(null, .{ .{}, .{} }) == null);
}
