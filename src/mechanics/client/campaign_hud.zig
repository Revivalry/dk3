// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: HUD-themed tactical compass and authoritative campaign journal.
const std = @import("std");
const c = @import("../../engine/abi.zig").c;
const engine = @import("../../engine/client.zig");
const canvas = @import("../../engine/canvas.zig");
const rules = @import("../domain/campaign_objectives.zig");
const v = @import("../../core/domain/vector.zig");
const Hud = @import("hud.zig").Hud;
const draw: canvas.Canvas(.client) = .{ .gateway = &engine.gateway };
const gold: canvas.Color = .{ 0.85, 0.73, 0.40, 1 };
const green: canvas.Color = .{ 0.48, 0.76, 0.38, 1 };
const muted: canvas.Color = .{ 0.48, 0.51, 0.41, 1 };
const range: f32 = 768;
fn text(hud: *const Hud, x: f32, y: f32, scale: f32, value: []const u8, color: canvas.Color) void {
    // The supplied status font's readable alphabet is uppercase. Lowercase slots
    // contain tiny alternate artwork, rather than ordinary lowercase glyphs.
    var buffer: [256]u8 = undefined;
    const length = @min(buffer.len, value.len);
    for (value[0..length], buffer[0..length]) |letter, *upper| upper.* = std.ascii.toUpper(letter);
    draw.text(hud.font, x, y, scale, buffer[0..length], color);
}
var walls: [48]?v.Vec3 = @splat(null);
var sampled_at: i64 = -1000;
var sampled_map: [32]u8 = @splat(0);

pub fn init() void {
    walls = @splat(null);
    sampled_at = -1000;
    sampled_map = @splat(0);
    inline for (.{ .{ "cg_minimap", "1" }, .{ "cg_objectives", "0" } }) |entry| {
        _ = engine.gateway.call(c.CG_CVAR_REGISTER, .{ @as(?*c.vmCvar_t, null), @as([*:0]const u8, entry[0]), @as([*:0]const u8, entry[1]), @as(isize, c.CVAR_ARCHIVE) });
    }
}
pub fn command(name: []const u8) bool {
    const variable: [:0]const u8 = if (std.mem.eql(u8, name, "minimap")) "cg_minimap" else if (std.mem.eql(u8, name, "objectives")) "cg_objectives" else return false;
    const value: [*:0]const u8 = if (engine.number(variable, 0) > 0) "0" else "1";
    _ = engine.gateway.call(c.CG_CVAR_SET, .{ variable.ptr, value });
    return true;
}
fn line(hud: *const Hud, from: [2]f32, to: [2]f32, thickness: f32, color: canvas.Color) void {
    const dx = to[0] - from[0];
    const dy = to[1] - from[1];
    const count: usize = @intFromFloat(@max(1, @ceil(@max(@abs(dx), @abs(dy)) / @max(1, thickness))));
    for (0..@min(count, 1024)) |i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(count));
        draw.rect(from[0] + dx * t, from[1] + dy * t, thickness, thickness, hud.white, color);
    }
}
fn panel(hud: *const Hud, x: f32, y: f32, w: f32, h: f32, scale: f32) void {
    draw.rect(x, y, w, h, hud.white, .{ 0.025, 0.035, 0.018, 0.90 });
    // Supplied weapon-window metal remains visible underneath the dark tactical face.
    draw.rect(x, y, w, h, hud.window, .{ 0.58, 0.61, 0.43, 0.18 });
    line(hud, .{ x, y }, .{ x + w, y }, scale, gold);
    line(hud, .{ x, y }, .{ x, y + h }, scale, gold);
    line(hud, .{ x + w, y }, .{ x + w, y + h }, scale, muted);
    line(hud, .{ x, y + h }, .{ x + w, y + h }, scale, muted);
    for ([_][2]f32{ .{ x + 3 * scale, y + 3 * scale }, .{ x + w - 5 * scale, y + 3 * scale }, .{ x + 3 * scale, y + h - 5 * scale }, .{ x + w - 5 * scale, y + h - 5 * scale } }) |point| draw.rect(point[0], point[1], 2 * scale, 2 * scale, hud.white, gold);
}
// Heading up: forward is the top of the map; distant markers remain at its rim.
pub fn project(point: v.Vec3, origin: v.Vec3, yaw: f32, radius: f32) [2]f32 {
    const delta = v.subtract(point, origin);
    const angle = yaw * std.math.pi / 180;
    var x = (delta[0] * -@sin(angle) + delta[1] * @cos(angle)) / range;
    var y = -(delta[0] * @cos(angle) + delta[1] * @sin(angle)) / range;
    const length = @sqrt(x * x + y * y);
    if (length > 1) {
        x /= length;
        y /= length;
    }
    return .{ -x * radius, y * radius };
}
fn sample(origin: v.Vec3, client: i32, now: i64, map: [32]u8) !void {
    if (now >= sampled_at and now - sampled_at < 200 and std.mem.eql(u8, &map, &sampled_map)) return;
    sampled_at = now;
    sampled_map = map;
    var start = origin;
    start[2] += 24;
    for (&walls, 0..) |*wall, i| {
        const angle = @as(f32, @floatFromInt(i)) * 2 * std.math.pi / walls.len;
        const end = v.add(start, .{ @cos(angle) * range, @sin(angle) * range, 0 });
        const hit = try engine.collisionService().trace(.{ .start = start, .end = end, .mins = @splat(0), .maxs = @splat(0), .slot = @intCast(client), .mask = c.MASK_SOLID, .brushes_only = true });
        wall.* = if (hit.fraction < 1 and !hit.start_solid) hit.end else null;
    }
}
fn symbol(rule: rules.Rule) []const u8 {
    return switch (rule) {
        .taken, .owned => "K",
        .used => "S",
        .broken, .defeated => "!",
        .exit => ">",
    };
}
fn chapter(map: []const u8) []const u8 {
    const names = .{
        .{ "e1m1", "THE MARSH" },       .{ "e1m2", "SEWER SYSTEM" },      .{ "e1m3", "SOLITARY" },          .{ "e1m4", "CREMATORIUM" },
        .{ "e1m5", "PROCESSING" },      .{ "e1m6", "ICELAB" },            .{ "e1m7", "THE VAULT" },         .{ "e2m1", "LEMNOS ISLE" },
        .{ "e2m2", "CATACOMB" },        .{ "e2m3", "ATHENS" },            .{ "e2m4", "ACROPOLIS" },         .{ "e2m5", "LAIR OF MEDUSA" },
        .{ "e3m1", "PLAGUE VILLAGE" },  .{ "e3m2", "PASSAGE" },           .{ "e3m3", "DUNGEON" },           .{ "e3m4", "WYNDRAX TOWER" },
        .{ "e3m5", "CRYPT OF NHARRE" }, .{ "e3m6", "GHARROTH'S THRONE" }, .{ "e4m1", "ALCATRAZ" },          .{ "e4m2", "BENEATH THE ROCK" },
        .{ "e4m3", "TOWER OF CRIME" },  .{ "e4m4", "MISHIMA LABS" },      .{ "e4m5", "MISHIMA'S HIDEOUT" }, .{ "e4m6", "SEAL TRAINING CENTER" },
    };
    inline for (names) |entry| if (std.mem.startsWith(u8, map, entry[0])) return entry[1];
    return "CAMPAIGN";
}
fn wrapped(hud: *const Hud, value: []const u8, x: f32, y: f32, width: f32, scale: f32, color: canvas.Color) f32 {
    var buffer: [256]u8 = undefined;
    const length = @min(buffer.len, value.len);
    for (value[0..length], buffer[0..length]) |letter, *upper| upper.* = std.ascii.toUpper(letter);
    var rest: []const u8 = buffer[0..length];
    var top = y;
    const height = (@as(f32, @floatFromInt(hud.font.metrics.height)) + 4) * scale;
    while (rest.len > 0) {
        var end = rest.len;
        while (end > 1 and hud.font.metrics.width(rest[0..end], scale) > width) end -= 1;
        if (end < rest.len) {
            if (std.mem.lastIndexOfScalar(u8, rest[0..end], ' ')) |space| if (space > 0) {
                end = space;
            };
        }
        draw.text(hud.font, x, top, scale, rest[0..end], color);
        rest = std.mem.trimStart(u8, rest[end..], " ");
        top += height;
    }
    return top;
}
pub fn render(hud: *const Hud, display: c.glconfig_t, game: *const c.gameState_t, origin: v.Vec3, yaw: f32, client: i32, now: i64) !void {
    const bytes = try engine.config(game, c.CS_DK3_CAMPAIGN);
    if (bytes.len == 0) return;
    const view = rules.View.decode(bytes) catch return;
    const goals = rules.forMap(view.name());
    const width: f32 = @floatFromInt(display.vidWidth);
    const height: f32 = @floatFromInt(display.vidHeight);
    const scale = @min(width / 640, height / 480 * std.math.clamp(engine.number("cg_hudScale", 1), 0.75, 1.5));
    if (engine.number("cg_minimap", 1) > 0) {
        try sample(origin, client, now, view.map);
        const x = 12 * scale;
        const y = 12 * scale;
        const center: [2]f32 = .{ x + 66 * scale, y + 80 * scale };
        const radius = 54 * scale;
        panel(hud, x, y, 132 * scale, 160 * scale, scale);
        text(hud, x + 10 * scale, y + 7 * scale, 0.85 * scale, "TACTICAL", gold);
        for ([_]f32{ -0.5, 0, 0.5 }) |offset| {
            line(hud, .{ center[0] + offset * radius, center[1] - radius }, .{ center[0] + offset * radius, center[1] + radius }, scale, .{ 0.18, 0.23, 0.12, 0.6 });
            line(hud, .{ center[0] - radius, center[1] + offset * radius }, .{ center[0] + radius, center[1] + offset * radius }, scale, .{ 0.18, 0.23, 0.12, 0.6 });
        }
        for (walls, 0..) |wall, i| {
            const a = wall orelse continue;
            const b = walls[(i + 1) % walls.len] orelse continue;
            if (v.length(v.subtract(a, b)) > 180) continue;
            const pa = project(a, origin, yaw, radius);
            const pb = project(b, origin, yaw, radius);
            line(hud, .{ center[0] + pa[0], center[1] + pa[1] }, .{ center[0] + pb[0], center[1] + pb[1] }, scale, green);
        }
        const north = project(v.add(origin, .{ 0, range, 0 }), origin, yaw, radius - 4 * scale);
        text(hud, center[0] + north[0] - 2 * scale, center[1] + north[1] - 4 * scale, scale * 0.7, "N", muted);
        var nearest: f32 = std.math.inf(f32);
        for (view.markers[0..view.count]) |marker| {
            const point = project(marker.position, origin, yaw, radius - 5 * scale);
            const mx = center[0] + point[0];
            const my = center[1] + point[1];
            draw.rect(mx - 3 * scale, my - 4 * scale, 9 * scale, 10 * scale, hud.white, .{ 0.06, 0.07, 0.03, 0.95 });
            text(hud, mx - 2 * scale, my - 3 * scale, 0.8 * scale, symbol(marker.rule), gold);
            const dz = marker.position[2] - origin[2];
            if (@abs(dz) > 96) text(hud, mx + 5 * scale, my - 4 * scale, 0.7 * scale, if (dz > 0) "+" else "-", gold);
            nearest = @min(nearest, v.length(v.subtract(marker.position, origin)));
        }
        line(hud, .{ center[0] - 3 * scale, center[1] + 4 * scale }, .{ center[0], center[1] - 4 * scale }, 1.5 * scale, canvas.white);
        line(hud, .{ center[0], center[1] - 4 * scale }, .{ center[0] + 3 * scale, center[1] + 4 * scale }, 1.5 * scale, canvas.white);
        var buffer: [80]u8 = undefined;
        const caption = if (std.math.isFinite(nearest)) try std.fmt.bufPrint(&buffer, "{d:.0}u   +/- HEIGHT", .{nearest}) else "OBJECTIVES";
        text(hud, x + 9 * scale, y + 139 * scale, 0.7 * scale, caption, gold);
    }
    if (engine.number("cg_objectives", 0) <= 0) return;
    const x = width * 0.5 - 210 * scale;
    const y = 54 * scale;
    const panel_height = @min(@min(350 * scale, height - 145 * scale), (115 + @as(f32, @floatFromInt(goals.len)) * 38) * scale);
    panel(hud, x, y, 420 * scale, panel_height, scale);
    var buffer: [160]u8 = undefined;
    const complete = @popCount(view.done);
    text(hud, x + 16 * scale, y + 12 * scale, 1.1 * scale, "OBJECTIVES", gold);
    text(hud, x + 16 * scale, y + 33 * scale, 0.85 * scale, try std.fmt.bufPrint(&buffer, "{s}   {d}/{d}", .{ chapter(view.name()), complete, goals.len }), muted);
    const progress = @as(f32, @floatFromInt(complete)) / @as(f32, @floatFromInt(goals.len));
    draw.rect(x + 16 * scale, y + 49 * scale, 388 * scale, 3 * scale, hud.white, .{ 0.14, 0.18, 0.09, 1 });
    draw.rect(x + 16 * scale, y + 49 * scale, 388 * scale * progress, 3 * scale, hud.white, green);
    var top = y + 62 * scale;
    const active_index = for (goals, 0..) |goal, i| {
        if (goal.stage == view.stage() and !view.complete(i)) break i;
    } else 0;
    const first = active_index -| 1;
    for (goals[first..], first..) |goal, i| {
        const done = view.complete(i);
        const active = goal.stage == view.stage() and !done;
        text(hud, x + 16 * scale, top, scale * 0.95, if (done) "+" else if (active) ">" else ".", if (done) green else gold);
        const label = if (goal.required() > 1) try std.fmt.bufPrint(&buffer, "{s} ({d}/{d})", .{ goal.text, view.progress[i], goal.required() }) else goal.text;
        top = wrapped(hud, label, x + 32 * scale, top, 368 * scale, 0.95 * scale, if (done) muted else if (active) gold else canvas.white) + 9 * scale;
        if (top > y + panel_height - 35 * scale) break;
    }
    text(hud, x + 16 * scale, y + panel_height - 19 * scale, scale * 0.7, "K ITEM   S SWITCH   ! TARGET   > ROUTE", muted);
}

test "heading projection rotates, clamps distant goals and keeps the player centered" {
    const t = std.testing;
    const ahead = project(.{ 768, 0, 0 }, @splat(0), 0, 50);
    try t.expectApproxEqAbs(@as(f32, 0), ahead[0], 0.001);
    try t.expectApproxEqAbs(@as(f32, -50), ahead[1], 0.001);
    const right = project(.{ 0, -7680, 500 }, @splat(0), 0, 50);
    try t.expectApproxEqAbs(@as(f32, 50), right[0], 0.001);
    const turned = project(.{ 0, 768, 0 }, @splat(0), 90, 50);
    try t.expectApproxEqAbs(@as(f32, -50), turned[1], 0.001);
}
