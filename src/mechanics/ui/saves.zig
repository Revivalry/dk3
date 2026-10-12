// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Save rows keep their own selection when focus moves to the Load/Save button.
//! Each row shows its save's wall-clock time and the selected one its picture, map and difficulty
//! (the `<slot>.info` sidecar the server writes with every save; older saves have neither).
const std = @import("std");
const engine = @import("../../engine/ui.zig");
const c = engine.c;
const snapshot = @import("../domain/snapshot.zig");
/// What a save's `<slot>.info` sidecar says.
pub const Info = struct {
    time: i64 = 0,
    date: [24]u8 = @splat(0),
    map: [32]u8 = @splat(0),
    shot: [64]u8 = @splat(0),
    skill: i32 = 0,
    level: i32 = 0,
    /// The picture file exists (`screenshots/<shot>.jpg`).
    pictured: bool = false,
    pub fn text(field: []const u8) []const u8 {
        return std.mem.sliceTo(field, 0);
    }
    /// Parses `key value` lines; quoted values are taken verbatim.
    pub fn parse(bytes: []const u8) Info {
        var info: Info = .{};
        var lines = std.mem.splitScalar(u8, bytes, '\n');
        while (lines.next()) |line| {
            const space = std.mem.indexOfScalar(u8, line, ' ') orelse continue;
            const key = line[0..space];
            var value = std.mem.trim(u8, line[space + 1 ..], " \r");
            if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') value = value[1 .. value.len - 1];
            if (std.mem.eql(u8, key, "time")) info.time = std.fmt.parseInt(i64, value, 10) catch 0;
            if (std.mem.eql(u8, key, "skill")) info.skill = std.fmt.parseInt(i32, value, 10) catch 0;
            if (std.mem.eql(u8, key, "level")) info.level = std.fmt.parseInt(i32, value, 10) catch 0;
            inline for (.{ "date", "map", "shot" }) |name| if (std.mem.eql(u8, key, name)) {
                const field = &@field(info, name);
                const length = @min(value.len, field.len - 1);
                @memcpy(field[0..length], value[0..length]);
            };
        }
        return info;
    }
};
pub const Browser = struct {
    names: [128][48]u8 = @splat(@splat(0)),
    infos: [128]Info = @splat(.{}),
    count: usize = 0,
    choice: @import("../domain/menu.zig").Selection = .{},
    first: usize = 0,
    pub fn name(self: *const Browser, index: usize) []const u8 {
        return std.mem.sliceTo(&self.names[index], 0);
    }
    pub fn selected(self: *const Browser) ?[]const u8 {
        return self.name(self.choice.selected orelse return null);
    }
    pub fn refresh(self: *Browser, writing: bool) !void {
        self.* = .{};
        if (writing) {
            @memcpy(self.names[0][0..5], "quick");
            for (1..9) |i| _ = try std.fmt.bufPrintZ(&self.names[i], "save{d}", .{i});
            self.count = 9;
        } else {
            var buffer: [16384]u8 = @splat(0);
            const count = engine.gateway.call(c.UI_FS_GETFILELIST, .{ @as([*:0]const u8, "saves"), @as([*:0]const u8, ".sav"), &buffer, @as(isize, buffer.len) });
            var at: usize = 0;
            for (0..@intCast(@max(0, count))) |_| {
                if (at >= buffer.len) break;
                const end = at + (std.mem.indexOfScalar(u8, buffer[at..], 0) orelse break);
                const file = buffer[at..end];
                at = end + 1;
                if (!std.mem.endsWith(u8, file, ".sav")) continue;
                const slot = file[0 .. file.len - 4];
                if (!snapshot.validName(slot) or std.mem.startsWith(u8, slot, "dk3-") or self.count == self.names.len) continue;
                @memcpy(self.names[self.count][0..slot.len], slot);
                self.count += 1;
            }
        }
        for (self.names[0..self.count], self.infos[0..self.count]) |*slot_name, *entry| entry.* = load(std.mem.sliceTo(slot_name, 0));
        // Loading lists the newest save first; saves without a time follow by name.
        if (!writing) {
            var order: [128]usize = undefined;
            for (order[0..self.count], 0..) |*index, i| index.* = i;
            std.mem.sort(usize, order[0..self.count], self, newer);
            const names = self.names;
            const infos = self.infos;
            for (order[0..self.count], 0..) |from, to| {
                self.names[to] = names[from];
                self.infos[to] = infos[from];
            }
        }
        if (self.count > 0) self.choice.selected = 0;
    }
    pub fn info(self: *const Browser, index: usize) *const Info {
        return &self.infos[index];
    }
    fn newer(self: *Browser, a: usize, b: usize) bool {
        const x = self.infos[a].time;
        const y = self.infos[b].time;
        if (x != y) return x > y;
        return less({}, self.names[a], self.names[b]);
    }
    pub fn page(self: *Browser, direction: i32) void {
        const pages = @max(1, (self.count + 7) / 8);
        self.first = @as(usize, @intCast(@mod(@as(i64, @intCast(self.first / 8)) + direction, @as(i64, @intCast(pages))))) * 8;
    }
    pub fn validate(self: *const Browser) !void {
        const slot = self.selected() orelse return error.SelectSaveFirst;
        var path: [80]u8 = undefined;
        const bytes = try @import("../../engine/files.zig").read(.ui, &engine.gateway, std.heap.c_allocator, try std.fmt.bufPrintZ(&path, "saves/{s}.sav", .{slot}), snapshot.maximum);
        defer std.heap.c_allocator.free(bytes);
        var loaded = try snapshot.decode(std.heap.c_allocator, bytes);
        defer loaded.deinit(std.heap.c_allocator);
    }
};
fn less(_: void, a: [48]u8, b: [48]u8) bool {
    return std.mem.order(u8, std.mem.sliceTo(&a, 0), std.mem.sliceTo(&b, 0)) == .lt;
}
fn load(slot: []const u8) Info {
    var path: [96]u8 = undefined;
    const name = std.fmt.bufPrintZ(&path, "saves/{s}.info", .{slot}) catch return .{};
    const bytes = (@import("../../engine/files.zig").readOptional(.ui, &engine.gateway, std.heap.c_allocator, name, 4096) catch return .{}) orelse return .{};
    defer std.heap.c_allocator.free(bytes);
    var info = Info.parse(bytes);
    const shot = Info.text(&info.shot);
    if (shot.len > 0) {
        const picture = std.fmt.bufPrintZ(&path, "screenshots/{s}.jpg", .{shot}) catch return info;
        var handle: c.fileHandle_t = 0;
        const length = engine.gateway.call(c.UI_FS_FOPENFILE, .{ picture.ptr, &handle, @as(isize, c.FS_READ) });
        if (handle != 0) _ = engine.gateway.call(c.UI_FS_FCLOSEFILE, .{@as(isize, handle)});
        info.pictured = length > 0;
    }
    return info;
}
test "a save's info sidecar gives its time, picture and map" {
    const info = Info.parse("dk3_save_info 2\nmap \"e1m3b\"\nhealth 87\nlevel 3\ntime 1791800000\ndate \"2026-10-12 14:03\"\nskill 3\nshot \"dk3save-save1-a\"\n");
    try std.testing.expectEqual(@as(i64, 1791800000), info.time);
    try std.testing.expectEqualStrings("2026-10-12 14:03", Info.text(&info.date));
    try std.testing.expectEqualStrings("e1m3b", Info.text(&info.map));
    try std.testing.expectEqualStrings("dk3save-save1-a", Info.text(&info.shot));
    try std.testing.expectEqual(@as(i32, 3), info.skill);
    try std.testing.expectEqual(@as(i32, 3), info.level);
    try std.testing.expectEqual(Info{}, Info.parse("dk3_save_info 1\n"));
}
