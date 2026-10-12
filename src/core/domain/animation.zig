// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Supplied model frame sequences, independent of renderer and simulation storage.
const std = @import("std");
pub const Playback = struct {
    sequence: Sequence,
    started: i64,
    looping: bool = true,
    reverse: bool = false,
    pub fn frame(self: Playback, now: i64) u16 {
        const value = self.sequence.frame(now - self.started, self.looping);
        return if (self.reverse) self.sequence.last - (value - self.sequence.first) else value;
    }
    pub fn sample(self: Playback, now: i64) @TypeOf((Sequence{}).sample(0, false)) {
        var value = self.sequence.sample(now - self.started, self.looping);
        if (self.reverse) {
            value.frame = self.sequence.last - (value.frame - self.sequence.first);
            value.oldframe = self.sequence.last - (value.oldframe - self.sequence.first);
        }
        return value;
    }
};
pub const Sequence = struct {
    first: u16 = 0,
    last: u16 = 0,
    fps: u16 = 10,
    pub fn duration(self: Sequence) i64 {
        return @divTrunc(@as(i64, self.last - self.first + 1) * 1000, self.fps);
    }
    /// When a clip played once reaches its last frame: the reference's end-of-clip event, which
    /// monster AI and pain locks wait for (one frame before `duration`; a one-frame clip keeps it).
    pub fn lastFrameMs(self: Sequence) i64 {
        return if (self.last == self.first) self.duration() else @divTrunc(@as(i64, self.last - self.first) * 1000, self.fps);
    }
    pub fn sample(self: Sequence, elapsed_ms: i64, looping: bool) struct { frame: u16, oldframe: u16, backlerp: f32 } {
        const elapsed = @max(0, elapsed_ms);
        const old = self.frame(elapsed, looping);
        const step = @mod(elapsed * self.fps, 1000);
        const next = if (old < self.last) old + 1 else if (looping) self.first else old;
        return .{ .frame = next, .oldframe = old, .backlerp = 1 - @as(f32, @floatFromInt(step)) * 0.001 };
    }
    pub fn frame(self: Sequence, elapsed_ms: i64, looping: bool) u16 {
        const count: u64 = self.last - self.first + 1;
        const elapsed: u64 = @intCast(@max(0, elapsed_ms));
        const step = elapsed / 1000 * self.fps + elapsed % 1000 * self.fps / 1000;
        return self.first + @as(u16, @intCast(if (looping) step % count else @min(step, count - 1)));
    }
};
/// Whitespace-separated words; a quoted word may hold spaces (an authored
/// sequence named "copy of c_swordp").
const Words = struct {
    bytes: []const u8,
    index: usize = 0,
    fn next(self: *Words) ?[]const u8 {
        while (self.index < self.bytes.len and std.mem.indexOfScalar(u8, " \t\r\n", self.bytes[self.index]) != null) self.index += 1;
        if (self.index >= self.bytes.len) return null;
        if (self.bytes[self.index] == '"') {
            const start = self.index + 1;
            const end = std.mem.indexOfScalarPos(u8, self.bytes, start, '"') orelse self.bytes.len;
            self.index = @min(end + 1, self.bytes.len);
            return self.bytes[start..end];
        }
        const start = self.index;
        while (self.index < self.bytes.len and std.mem.indexOfScalar(u8, " \t\r\n\"", self.bytes[self.index]) == null) self.index += 1;
        return self.bytes[start..self.index];
    }
};
pub fn find(bytes: []const u8, name: []const u8) !?Sequence {
    var words: Words = .{ .bytes = bytes };
    if (!std.mem.eql(u8, words.next() orelse return error.InvalidAnimation, "dk3_animation")) return error.InvalidAnimation;
    if (!std.mem.eql(u8, words.next() orelse return error.InvalidAnimation, "1")) return error.InvalidAnimation;
    const frames = try std.fmt.parseInt(u16, words.next() orelse return error.InvalidAnimation, 10);
    var selected: ?Sequence = null;
    while (words.next()) |sequence_name| {
        const first = try std.fmt.parseInt(u16, words.next() orelse return error.InvalidAnimation, 10);
        const last = try std.fmt.parseInt(u16, words.next() orelse return error.InvalidAnimation, 10);
        const fps = try std.fmt.parseInt(u16, words.next() orelse return error.InvalidAnimation, 10);
        if (last < first or last >= frames or fps == 0 or fps > 240) return error.InvalidAnimation;
        if (std.mem.eql(u8, sequence_name, name)) {
            if (selected != null) return error.DuplicateAnimation;
            selected = .{ .first = first, .last = last, .fps = fps };
        }
    }
    return selected;
}
/// The same metadata with every clip at `fps`: an entity, not its model, sets the playback rate
/// (the converted metadata carries the engine's default 10).
pub fn retime(allocator: std.mem.Allocator, bytes: []const u8, fps: u16) ![]u8 {
    if (fps == 0 or fps > 240) return error.InvalidAnimation;
    var words: Words = .{ .bytes = bytes };
    if (!std.mem.eql(u8, words.next() orelse return error.InvalidAnimation, "dk3_animation")) return error.InvalidAnimation;
    if (!std.mem.eql(u8, words.next() orelse return error.InvalidAnimation, "1")) return error.InvalidAnimation;
    const frames = try std.fmt.parseInt(u16, words.next() orelse return error.InvalidAnimation, 10);
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.print("dk3_animation 1\n{d}\n", .{frames});
    while (words.next()) |name| {
        const first = words.next() orelse return error.InvalidAnimation;
        const last = words.next() orelse return error.InvalidAnimation;
        _ = words.next() orelse return error.InvalidAnimation;
        if (std.mem.indexOfScalar(u8, name, '"') != null) return error.InvalidAnimation;
        try output.writer.print("\"{s}\" {s} {s} {d}\n", .{ name, first, last, fps });
    }
    return output.toOwnedSlice();
}
test "retimed metadata keeps every clip and its frames at the entity's rate" {
    const bytes = try retime(std.testing.allocator, "dk3_animation 1\n30\n\"copy of c_swordp\" 21 21 10\n\"amba\" 0 9 10\n", 20);
    defer std.testing.allocator.free(bytes);
    const amba = (try find(bytes, "amba")).?;
    try std.testing.expectEqual(@as(u16, 20), amba.fps);
    try std.testing.expectEqual(@as(u16, 9), amba.last);
    try std.testing.expectEqual(@as(u16, 21), (try find(bytes, "copy of c_swordp")).?.first);
    try std.testing.expectEqual(@as(i64, 500), amba.duration());
}
test "animation timing follows elapsed time and death holds its final frame" {
    const sequence = (try find("dk3_animation 1\n20\n\"diea\" 5 12 10\n", "diea")).?;
    try std.testing.expectEqual(@as(u16, 8), sequence.frame(350, false));
    try std.testing.expectEqual(@as(u16, 12), sequence.frame(10000, false));
    try std.testing.expectEqual(@as(u16, 7), sequence.frame(1000, true));
    try std.testing.expectError(error.InvalidAnimation, find("dk3_animation 1 20 \"diea\" 5 20 10", "diea"));
    // Authored names may contain spaces (e2m5's cinematic Hiro).
    const copied = (try find("dk3_animation 1\n30\n\"copy of c_swordp\" 21 21 10\n\"amba\" 0 9 10\n", "amba")).?;
    try std.testing.expectEqual(@as(u16, 9), copied.last);
}
