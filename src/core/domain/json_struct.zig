// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Owned typed JSON objects with static field-name dispatch.
const std = @import("std");

pub fn parseOwned(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8, maximum_value: usize) !T {
    var parser = Parser.init(allocator);
    defer parser.deinit();
    return parser.parseOwned(T, allocator, bytes, maximum_value);
}

/// Nesting storage belongs to the parser; every parsed value belongs to the
/// allocator supplied to parseOwned. Complete inputs never borrow that storage.
pub const Parser = struct {
    scanner: std.json.Scanner,

    pub fn init(allocator: std.mem.Allocator) Parser {
        return .{ .scanner = std.json.Scanner.initCompleteInput(allocator, "") };
    }
    pub fn deinit(self: *Parser) void {
        self.scanner.deinit();
        self.* = undefined;
    }
    pub fn parseOwned(self: *Parser, comptime T: type, allocator: std.mem.Allocator, bytes: []const u8, maximum_value: usize) !T {
        // Reinitialize every scanner state, including after a failed parse,
        // retaining only the independently owned nesting allocation.
        var stack = self.scanner.stack;
        stack.bit_len = 0;
        stack.bytes.clearRetainingCapacity();
        self.scanner = std.json.Scanner.initCompleteInput(stack.bytes.allocator, bytes);
        self.scanner.stack = stack;
        const options: std.json.ParseOptions = .{ .allocate = .alloc_always, .max_value_len = maximum_value };
        if (comptime @typeInfo(T) != .@"struct") return std.json.parseFromTokenSourceLeaky(T, allocator, &self.scanner, options);
        if (comptime @typeInfo(T).@"struct".is_tuple or std.meta.hasFn(T, "jsonParse") or @typeInfo(T).@"struct".fields.len == 0)
            return std.json.parseFromTokenSourceLeaky(T, allocator, &self.scanner, options);
        return (try std.json.parseFromTokenSourceLeaky(Object(T), allocator, &self.scanner, options)).value;
    }
};

fn Object(comptime T: type) type {
    return struct {
        value: T,

        pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!@This() {
            const fields = @typeInfo(T).@"struct".fields;
            const lookup = comptime blk: {
                @setEvalBranchQuota(200_000);
                var entries: [fields.len]struct { []const u8, usize } = undefined;
                for (fields, 0..) |field, i| entries[i] = .{ field.name, i };
                break :blk std.StaticStringMap(usize).initComptime(entries);
            };
            std.debug.assert(options.duplicate_field_behavior == .@"error" and !options.ignore_unknown_fields);
            if (try source.next() != .object_begin) return error.UnexpectedToken;
            var value: T = undefined;
            var seen = [_]bool{false} ** fields.len;
            while (true) {
                const token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
                const name = switch (token) {
                    .string, .allocated_string => |name| name,
                    .object_end => break,
                    else => return error.UnexpectedToken,
                };
                const found = lookup.get(name);
                if (token == .allocated_string) allocator.free(token.allocated_string);
                const index = found orelse return error.UnknownField;
                if (seen[index]) return error.DuplicateField;
                switch (index) {
                    inline 0...fields.len - 1 => |i| {
                        const field = fields[i];
                        if (field.is_comptime) @compileError("JSON object cannot contain comptime fields");
                        @field(value, field.name) = try std.json.innerParse(field.type, allocator, source, options);
                        seen[i] = true;
                    },
                    else => unreachable,
                }
            }
            inline for (fields, 0..) |field, i| {
                if (!seen[i]) {
                    if (field.defaultValue()) |default| {
                        @field(value, field.name) = default;
                    } else return error.MissingField;
                }
            }
            return .{ .value = value };
        }
    };
}

test "owned object parsing preserves standard defaults and rejection behavior" {
    const Value = struct { id: u32, name: []const u8 = "default", amount: f32 = 0, nested: struct { x: i32 = 7 } = .{} };
    const fixtures = [_][]const u8{
        "{\"id\":1}",
        "{\"nested\":{\"x\":-3},\"name\":\"own\\u0065d\",\"amount\":1.25,\"id\":7}",
        "{\"\\u0069d\":9,\"name\":\"value\"}",
        "{}",
        "{\"id\":1,\"unknown\":2}",
        "{\"id\":1,\"id\":2}",
        "{\"id\":1,\"\\u0069d\":2}",
        "{\"id\":1,\"nested\":{\"x\":1,\"x\":2}}",
        "{\"id\":4294967296}",
        "{\"id\":-1}",
        "{\"id\":\"invalid\"}",
        "{\"id\":1,\"amount\":true}",
        "{\"id\":1,\"name\":\"unterminated}",
        "{\"id\":1} false",
        "[]",
    };
    for (fixtures) |bytes| {
        var reference = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer reference.deinit();
        var candidate = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer candidate.deinit();
        const expected = std.json.parseFromSliceLeaky(Value, reference.allocator(), bytes, .{ .allocate = .alloc_always, .max_value_len = 65536 });
        const actual = parseOwned(Value, candidate.allocator(), bytes, 65536);
        if (expected) |value| {
            try std.testing.expectEqualDeep(value, try actual);
        } else |err| try std.testing.expectError(err, actual);
    }
}

test "owned values survive input replacement and scanner limits remain effective" {
    const Value = struct { id: u32, name: []const u8 };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const input = try std.testing.allocator.dupe(u8, "{\"id\":1,\"name\":\"owned\"}");
    defer std.testing.allocator.free(input);
    const value = try parseOwned(Value, arena.allocator(), input, 65536);
    @memset(input, 'x');
    try std.testing.expectEqualStrings("owned", value.name);
    try std.testing.expectError(error.ValueTooLong, parseOwned(Value, arena.allocator(), "{\"id\":1,\"name\":\"long value\"}", 4));
    try std.testing.expectEqual(@as(u16, 12), try parseOwned(u16, arena.allocator(), "12", 65536));
    try std.testing.expectEqualDeep(.{ @as(u32, 4), true }, try parseOwned(struct { u32, bool }, arena.allocator(), "[4,true]", 65536));
}

test "reused scanner retains nesting storage and owned values across inputs and errors" {
    const Value = struct { id: u32, name: []const u8 = "default" };
    var nesting = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var parser = Parser.init(nesting.allocator());
    defer parser.deinit();
    var values = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer values.deinit();
    const allocator = values.allocator();
    const input = try std.testing.allocator.dupe(u8, "{\"id\":1,\"name\":\"owned\"}");
    defer std.testing.allocator.free(input);
    const first = try parser.parseOwned(Value, allocator, input, 65536);
    @memset(input, 'x');
    const allocated = nesting.allocations;
    for (0..32) |_| {
        const next = try parser.parseOwned(Value, allocator, "{\"name\":\"next\",\"id\":2}", 65536);
        try std.testing.expectEqual(@as(u32, 2), next.id);
        try std.testing.expectEqualStrings("next", next.name);
    }
    try std.testing.expectEqual(allocated, nesting.allocations);
    for ([_][]const u8{
        "{\"id\":1,\"id\":2}",       "{\"id\":1,\"\\u0069d\":2}",
        "{\"id\":1,\"unknown\":[]}", "{\"id\":",
        "[]",                        "{}",
        "{\"id\":1} false",
    }) |bytes| {
        const expected = std.json.parseFromSliceLeaky(Value, allocator, bytes, .{ .allocate = .alloc_always, .max_value_len = 65536 });
        const actual = parser.parseOwned(Value, allocator, bytes, 65536);
        if (expected) |value| try std.testing.expectEqualDeep(value, try actual) else |err| try std.testing.expectError(err, actual);
        try std.testing.expectEqual(@as(u32, 3), (try parser.parseOwned(Value, allocator, "{\"id\":3}", 65536)).id);
    }
    try std.testing.expectEqualStrings("owned", first.name);
    try std.testing.expectError(error.ValueTooLong, parser.parseOwned(Value, allocator, "{\"id\":1,\"name\":\"long value\"}", 4));
    try std.testing.expectEqual(@as(u32, 4), (try parser.parseOwned(Value, allocator, "{\"id\":4}", 65536)).id);
}

test "reused scanner grows for deep input and recovers from nesting allocation failure" {
    var nesting = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var parser = Parser.init(nesting.allocator());
    defer parser.deinit();
    var values = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer values.deinit();
    const allocator = values.allocator();
    try std.testing.expectError(error.OutOfMemory, parser.parseOwned(std.json.Value, allocator, "[0]", 65536));
    nesting.fail_index = std.math.maxInt(usize);
    const depth = 1200;
    const bytes = try std.testing.allocator.alloc(u8, depth * 2 + 1);
    defer std.testing.allocator.free(bytes);
    @memset(bytes[0..depth], '[');
    bytes[depth] = '0';
    @memset(bytes[depth + 1 ..], ']');
    var parsed = try parser.parseOwned(std.json.Value, allocator, bytes, 65536);
    for (0..depth) |_| {
        try std.testing.expectEqual(@as(usize, 1), parsed.array.items.len);
        parsed = parsed.array.items[0];
    }
    try std.testing.expectEqual(@as(i64, 0), parsed.integer);
    const allocations = nesting.allocations;
    _ = try parser.parseOwned(std.json.Value, allocator, bytes, 65536);
    try std.testing.expectEqual(allocations, nesting.allocations);
    try std.testing.expectEqual(@as(u8, 7), try parser.parseOwned(u8, allocator, "7", 65536));
}
