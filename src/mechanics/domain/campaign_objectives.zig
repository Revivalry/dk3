// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: authored campaign goals and bounded HUD transport, independent of class policy.
const std = @import("std");
pub const Rule = enum { used, taken, owned, broken, defeated, exit };
pub const Goal = struct {
    map: []const u8,
    stage: u8,
    rule: Rule,
    // BSP entity ordinals, one based, matching authored persistent identities.
    ids: [8]u24 = @splat(0),
    count: u4 = 0,
    // A single authored counter can report its individual activations.
    quantity: u4 = 0,
    text: []const u8,
    pub fn required(self: Goal) u4 {
        return if (self.quantity > 0) self.quantity else self.count;
    }
};
const source = @embedFile("../../game/domain/campaign_objectives.tsv");
pub const revision: u32 = blk: {
    @setEvalBranchQuota(1000000);
    break :blk @truncate(std.hash.Wyhash.hash(0, source));
};
pub const goals = parse();
fn parse() [goalCount()]Goal {
    @setEvalBranchQuota(1000000);
    var result: [goalCount()]Goal = undefined;
    var lines = std.mem.tokenizeScalar(u8, source, '\n');
    var index: usize = 0;
    while (lines.next()) |line| {
        if (line[0] == '#') continue;
        var fields = std.mem.splitScalar(u8, line, '|');
        var goal: Goal = .{
            .map = fields.next().?,
            .stage = std.fmt.parseInt(u8, fields.next().?, 10) catch unreachable,
            .rule = undefined,
            .text = "",
        };
        var rule = std.mem.splitScalar(u8, fields.next().?, ':');
        goal.rule = std.meta.stringToEnum(Rule, rule.next().?).?;
        if (rule.next()) |quantity| {
            goal.quantity = std.fmt.parseInt(u4, quantity, 10) catch unreachable;
            if (goal.quantity < 2) @compileError("campaign counter needs at least two activations");
        }
        if (rule.next() != null) @compileError("invalid campaign counter");
        var ids = std.mem.splitScalar(u8, fields.next().?, ',');
        while (ids.next()) |id| {
            goal.ids[goal.count] = std.fmt.parseInt(u24, id, 10) catch unreachable;
            goal.count += 1;
        }
        goal.text = fields.next().?;
        if (fields.next() != null or goal.count == 0 or goal.text.len > 100) @compileError("invalid campaign goal");
        if (goal.quantity > 0 and (goal.rule != .used or goal.count != 1)) @compileError("campaign counter needs one used entity");
        result[index] = goal;
        index += 1;
    }
    return result;
}
fn goalCount() usize {
    @setEvalBranchQuota(1000000);
    var lines = std.mem.tokenizeScalar(u8, source, '\n');
    var count: usize = 0;
    while (lines.next()) |line| if (line[0] != '#') {
        count += 1;
    };
    return count;
}
pub fn forMap(map: []const u8) []const Goal {
    var start: ?usize = null;
    for (&goals, 0..) |*goal, i| {
        if (std.mem.eql(u8, goal.map, map)) {
            if (start == null) start = i;
        } else if (start) |first| return goals[first..i];
    }
    return if (start) |first| goals[first..] else &.{};
}
pub const Marker = struct { goal: u8, rule: Rule = .exit, position: [3]f32 };
pub const View = struct {
    map: [32]u8 = @splat(0),
    done: u64 = 0,
    // Per-goal progress allows multi-switch and ingredient groups to show 1/4 etc.
    progress: [64]u4 = @splat(0),
    markers: [8]Marker = undefined,
    count: usize = 0,
    pub fn name(self: *const View) []const u8 {
        return std.mem.sliceTo(&self.map, 0);
    }
    pub fn complete(self: *const View, i: usize) bool {
        return self.done & (@as(u64, 1) << @intCast(i)) != 0;
    }
    pub fn stage(self: *const View) u8 {
        var first: u8 = 255;
        for (forMap(self.name()), 0..) |goal, i| if (!self.complete(i)) {
            first = @min(first, goal.stage);
        };
        return first;
    }
    pub fn encode(self: *const View, buffer: []u8) ![:0]const u8 {
        var progress: [64]u8 = undefined;
        const list = forMap(self.name());
        for (list, 0..) |_, i| progress[i] = std.fmt.digitToChar(self.progress[i], .lower);
        var used = (try std.fmt.bufPrint(buffer, "1 {s} {x} {s}", .{ self.name(), self.done, progress[0..list.len] })).len;
        for (self.markers[0..self.count]) |marker| {
            used += (try std.fmt.bufPrint(buffer[used..], " {d} {d} {d:.0} {d:.0} {d:.0}", .{ marker.goal, @intFromEnum(marker.rule), marker.position[0], marker.position[1], marker.position[2] })).len;
        }
        if (used >= buffer.len) return error.NoSpaceLeft;
        buffer[used] = 0;
        return buffer[0..used :0];
    }
    pub fn decode(bytes: []const u8) !View {
        var fields = std.mem.tokenizeScalar(u8, bytes, ' ');
        if (!std.mem.eql(u8, fields.next() orelse "", "1")) return error.ObjectiveVersion;
        const map = fields.next() orelse return error.ObjectiveMap;
        const list = forMap(map);
        if (map.len >= 32 or list.len == 0 or list.len > 64) return error.ObjectiveMap;
        var self: View = .{};
        @memcpy(self.map[0..map.len], map);
        self.done = try std.fmt.parseInt(u64, fields.next() orelse return error.ObjectiveProgress, 16);
        if (list.len < 64 and self.done >> @intCast(list.len) != 0) return error.ObjectiveProgress;
        const progress = fields.next() orelse return error.ObjectiveProgress;
        if (progress.len != list.len) return error.ObjectiveProgress;
        for (progress, 0..) |letter, i| {
            self.progress[i] = @intCast(try std.fmt.charToDigit(letter, 16));
            if (self.progress[i] > list[i].required()) return error.ObjectiveProgress;
            if (self.complete(i) != (self.progress[i] == list[i].required())) return error.ObjectiveProgress;
        }
        while (fields.next()) |index| {
            if (self.count == self.markers.len) return error.ObjectiveMarkers;
            var marker: Marker = .{ .goal = try std.fmt.parseInt(u8, index, 10), .position = undefined };
            if (marker.goal >= list.len or self.complete(marker.goal)) return error.ObjectiveMarkers;
            marker.rule = std.enums.fromInt(Rule, try std.fmt.parseInt(u8, fields.next() orelse return error.ObjectiveMarkers, 10)) orelse return error.ObjectiveMarkers;
            for (&marker.position) |*axis| {
                axis.* = try std.fmt.parseFloat(f32, fields.next() orelse return error.ObjectiveMarkers);
                if (!std.math.isFinite(axis.*) or @abs(axis.*) > 1000000) return error.ObjectiveMarkers;
            }
            self.markers[self.count] = marker;
            self.count += 1;
        }
        return self;
    }
};

test "campaign goals cover every episode and transport partial progress without accepting invalid markers" {
    var maps: usize = 0;
    var prior: []const u8 = "";
    for (goals) |goal| {
        if (!std.mem.eql(u8, prior, goal.map)) {
            maps += 1;
            prior = goal.map;
        }
        try std.testing.expect(forMap(goal.map).len <= 64);
        for (goal.ids[0..goal.count]) |id| try std.testing.expect(id > 0);
    }
    try std.testing.expectEqual(@as(usize, 62), maps);
    var view: View = .{};
    @memcpy(view.map[0..5], "e1m1a");
    view.markers[0] = .{ .goal = 0, .position = .{ 1, -2, 3 } };
    view.count = 1;
    var buffer: [1000]u8 = undefined;
    const restored = try View.decode(try view.encode(&buffer));
    try std.testing.expectEqual(@as(usize, 1), restored.count);
    try std.testing.expectEqualStrings("e1m1a", restored.name());
    try std.testing.expectError(error.ObjectiveMarkers, View.decode("1 e1m1a 0 0 99 1 2 3"));
}
