// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: bounded typed values for build-bound prepared snapshots.
//! Fixed subtrees use exact field widths; no padding, native pointers or allocator
//! state is serialized. The enclosing snapshot verifies the runtime identity.
const std = @import("std");
pub const maximum = 1024 * 1024;
pub fn encodedLength(input: anytype) !usize {
    return encodedSize(input);
}
fn integerSize(comptime T: type) usize {
    const bits = @typeInfo(T).int.bits;
    if (bits > 64) @compileError("prepared integer exceeds 64 bits");
    return if (bits <= 8) 1 else if (bits <= 16) 2 else if (bits <= 32) 4 else 8;
}
fn fixedSize(comptime T: type) ?usize {
    @setEvalBranchQuota(200000);
    return switch (@typeInfo(T)) {
        .void => 0,
        .bool => 1,
        .int => integerSize(T),
        .float => |info| if (info.bits == 16 or info.bits == 32 or info.bits == 64) info.bits / 8 else @compileError("unsupported prepared float"),
        .@"enum" => |info| fixedSize(info.tag_type),
        .array => |info| if (fixedSize(info.child)) |size| info.len * size else null,
        .@"struct" => |info| blk: {
            var size: usize = 0;
            for (info.fields) |field| size += fixedSize(field.type) orelse break :blk null;
            break :blk size;
        },
        else => null,
    };
}
fn canCopy(comptime T: type) bool {
    @setEvalBranchQuota(200000);
    const size = fixedSize(T) orelse return false;
    if (@import("builtin").cpu.arch.endian() != .little or @sizeOf(T) != size) return false;
    return switch (@typeInfo(T)) {
        .int => |info| info.bits == @sizeOf(T) * 8,
        .float => true,
        .array => |info| canCopy(info.child),
        .@"struct" => |info| blk: {
            var offset: usize = 0;
            for (info.fields) |field| {
                if (@offsetOf(T, field.name) != offset or !canCopy(field.type)) break :blk false;
                offset += fixedSize(field.type).?;
            }
            break :blk true;
        },
        else => false, // bools, enum tags and partial integers need range checks.
    };
}
fn writeFixed(comptime T: type, bytes: []u8, input: T) void {
    if (comptime canCopy(T)) {
        @memcpy(bytes, std.mem.asBytes(&input));
        return;
    }
    switch (@typeInfo(T)) {
        .void => {},
        .bool => bytes[0] = @intFromBool(input),
        .int => |info| {
            const size = comptime integerSize(T);
            const U = std.meta.Int(.unsigned, size * 8);
            const S = std.meta.Int(.signed, size * 8);
            const raw: U = if (info.signedness == .signed) @bitCast(@as(S, input)) else input;
            std.mem.writeInt(U, bytes[0..size], raw, .little);
        },
        .float => |info| std.mem.writeInt(std.meta.Int(.unsigned, info.bits), bytes[0 .. info.bits / 8], @bitCast(input), .little),
        .@"enum" => writeFixed(@TypeOf(@intFromEnum(input)), bytes, @intFromEnum(input)),
        .array => |info| {
            const size = comptime fixedSize(info.child).?;
            for (input, 0..) |child, i| writeFixed(info.child, bytes[i * size ..][0..size], child);
        },
        .@"struct" => |info| {
            var offset: usize = 0;
            inline for (info.fields) |field| {
                const size = comptime fixedSize(field.type).?;
                writeFixed(field.type, bytes[offset..][0..size], @field(input, field.name));
                offset += size;
            }
        },
        else => unreachable,
    }
}
fn readFixed(comptime T: type, bytes: []const u8) anyerror!T {
    if (comptime canCopy(T)) {
        var result: T = undefined;
        @memcpy(std.mem.asBytes(&result), bytes);
        return result;
    }
    return switch (@typeInfo(T)) {
        .void => {},
        .bool => switch (bytes[0]) {
            0 => false,
            1 => true,
            else => error.InvalidValueBoolean,
        },
        .int => |info| blk: {
            const size = comptime integerSize(T);
            const U = std.meta.Int(.unsigned, size * 8);
            const raw = std.mem.readInt(U, bytes[0..size], .little);
            if (info.signedness == .signed) {
                const S = std.meta.Int(.signed, size * 8);
                break :blk std.math.cast(T, @as(S, @bitCast(raw))) orelse error.InvalidValueInteger;
            }
            break :blk std.math.cast(T, raw) orelse error.InvalidValueInteger;
        },
        .float => |info| @bitCast(std.mem.readInt(std.meta.Int(.unsigned, info.bits), bytes[0 .. info.bits / 8], .little)),
        .@"enum" => |info| std.enums.fromInt(T, try readFixed(info.tag_type, bytes)) orelse error.InvalidValueTag,
        .array => |info| blk: {
            var result: T = undefined;
            const size = comptime fixedSize(info.child).?;
            for (&result, 0..) |*child, i| child.* = try readFixed(info.child, bytes[i * size ..][0..size]);
            break :blk result;
        },
        .@"struct" => |info| blk: {
            var result: T = undefined;
            var offset: usize = 0;
            inline for (info.fields) |field| {
                const size = comptime fixedSize(field.type).?;
                @field(result, field.name) = try readFixed(field.type, bytes[offset..][0..size]);
                offset += size;
            }
            break :blk result;
        },
        else => unreachable,
    };
}
fn add(a: usize, b: usize) !usize {
    if (a > maximum or b > maximum - a) return error.ValueCapacity;
    return a + b;
}
fn encodedSize(input: anytype) anyerror!usize {
    const T = @TypeOf(input);
    if (comptime fixedSize(T)) |size| return if (size <= maximum) size else error.ValueCapacity;
    return switch (@typeInfo(T)) {
        .optional => if (input) |present| try add(1, try encodedSize(present)) else 1,
        .array => blk: {
            var size: usize = 0;
            for (input) |child| {
                size = try add(size, try encodedSize(child));
            }
            break :blk size;
        },
        .pointer => |info| blk: {
            if (info.size != .slice) @compileError("prepared pointer must be a slice");
            if (input.len > (if (info.child == u8) @as(usize, 65536) else 4096)) return error.ValueCapacity;
            if (comptime fixedSize(info.child)) |size| break :blk try add(4, input.len * size);
            var size: usize = 4;
            for (input) |child| size = try add(size, try encodedSize(child));
            break :blk size;
        },
        .@"struct" => |info| blk: {
            var size: usize = 0;
            inline for (info.fields) |field| {
                size = try add(size, try encodedSize(@field(input, field.name)));
            }
            break :blk size;
        },
        .@"union" => blk: {
            const tag = std.meta.activeTag(input);
            switch (input) {
                inline else => |payload| break :blk try add(try encodedSize(tag), try encodedSize(payload)),
            }
        },
        else => unreachable,
    };
}
const Encoder = struct {
    bytes: []u8,
    cursor: usize = 0,
    fn raw(self: *Encoder, count: usize) []u8 {
        defer self.cursor += count;
        return self.bytes[self.cursor..][0..count];
    }
    fn value(self: *Encoder, input: anytype) void {
        const T = @TypeOf(input);
        if (comptime fixedSize(T)) |size| {
            writeFixed(T, self.raw(size), input);
            return;
        }
        switch (@typeInfo(T)) {
            .optional => {
                self.value(input != null);
                if (input) |present| self.value(present);
            },
            .array => for (input) |child| self.value(child),
            .pointer => |info| {
                self.value(@as(u32, @intCast(input.len)));
                if (info.child == u8) @memcpy(self.raw(input.len), input) else for (input) |child| self.value(child);
            },
            .@"struct" => |info| inline for (info.fields) |field| self.value(@field(input, field.name)),
            .@"union" => {
                self.value(std.meta.activeTag(input));
                switch (input) {
                    inline else => |payload| self.value(payload),
                }
            },
            else => unreachable,
        }
    }
};
pub fn encode(allocator: std.mem.Allocator, input: anytype) ![]u8 {
    const bytes = try allocator.alloc(u8, try encodedSize(input));
    var encoder: Encoder = .{ .bytes = bytes };
    encoder.value(input);
    std.debug.assert(encoder.cursor == bytes.len);
    return bytes;
}
const Decoder = struct {
    arena: std.mem.Allocator,
    bytes: []const u8,
    cursor: usize = 0,
    allocation_left: usize = 8 * maximum,
    fn raw(self: *Decoder, count: usize) ![]const u8 {
        if (count > self.bytes.len - self.cursor) return error.TruncatedValue;
        defer self.cursor += count;
        return self.bytes[self.cursor..][0..count];
    }
    fn value(self: *Decoder, comptime T: type) anyerror!T {
        if (comptime fixedSize(T)) |size| return readFixed(T, try self.raw(size));
        return switch (@typeInfo(T)) {
            .optional => |info| if (try self.value(bool)) try self.value(info.child) else null,
            .array => |info| blk: {
                var result: T = undefined;
                for (&result) |*child| child.* = try self.value(info.child);
                break :blk result;
            },
            .pointer => |info| blk: {
                if (info.size != .slice or info.sentinel_ptr != null) @compileError("prepared pointer must be an unsentinelled slice");
                const count = try self.value(u32);
                if (count > (if (info.child == u8) @as(usize, 65536) else 4096) or count > self.allocation_left / @max(@sizeOf(info.child), 1)) return error.ValueCapacity;
                self.allocation_left -= @as(usize, count) * @sizeOf(info.child);
                const result = try self.arena.alloc(info.child, count);
                if (info.child == u8) @memcpy(result, try self.raw(count)) else for (result) |*child| child.* = try self.value(info.child);
                break :blk result;
            },
            .@"struct" => |info| blk: {
                var result: T = undefined;
                inline for (info.fields) |field| @field(result, field.name) = try self.value(field.type);
                break :blk result;
            },
            .@"union" => |info| blk: {
                const tag = try self.value(info.tag_type.?);
                switch (tag) {
                    inline else => |active| break :blk @unionInit(T, @tagName(active), try self.value(@FieldType(T, @tagName(active)))),
                }
            },
            else => unreachable,
        };
    }
};
/// arena is the transaction arena: discard it on failure, keep it with the
/// completed world on success. No pointer escapes that explicit ownership.
pub fn decode(comptime T: type, arena: std.mem.Allocator, bytes: []const u8) !T {
    if (bytes.len > maximum) return error.ValueCapacity;
    var decoder: Decoder = .{ .arena = arena, .bytes = bytes };
    const result = try decoder.value(T);
    if (decoder.cursor != bytes.len) return error.TrailingValue;
    return result;
}

test "typed prepared values retain slices, union tags, signed numbers and float bits" {
    const T = struct { name: []const u8, entries: []const ?i16, payload: union(enum) { empty, number: f32 } };
    const input: T = .{ .name = "world/α", .entries = &.{ -32768, null, 32767 }, .payload = .{ .number = -0.0 } };
    const bytes = try encode(std.testing.allocator, input);
    defer std.testing.allocator.free(bytes);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try decode(T, arena.allocator(), bytes);
    try std.testing.expectEqualStrings(input.name, result.name);
    try std.testing.expectEqualSlices(?i16, input.entries, result.entries);
    try std.testing.expectEqual(@as(u32, @bitCast(input.payload.number)), @as(u32, @bitCast(result.payload.number)));
    for (0..bytes.len) |length| try std.testing.expectError(error.TruncatedValue, decode(T, arena.allocator(), bytes[0..length]));
    try std.testing.expectError(error.InvalidValueBoolean, decode(bool, arena.allocator(), &.{2}));
    try std.testing.expectError(error.TrailingValue, decode(bool, arena.allocator(), &.{ 1, 0 }));
    try std.testing.expectError(error.ValueCapacity, decode([]const u8, arena.allocator(), &(@as([8]u8, @splat(255)))));
}
