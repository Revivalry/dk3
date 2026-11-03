// SPDX-License-Identifier: GPL-2.0-or-later
//! Offline GPU-ready world conversion; no window, engine imports or Vulkan device.
const std = @import("std");
const world = @import("world.zig");
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 5) return error.ExpectedBspOutputOverbrightSubdivisions;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(128 * 1024 * 1024));
    const storage = try allocator.alloc(u8, @import("prepared_world.zig").maximum);
    const shift = try std.fmt.parseInt(u5, args[3], 10);
    const subdivisions = try std.fmt.parseInt(u32, args[4], 10);
    const prepared = try world.bakePrepared(bytes, shift, subdivisions, storage);
    // A new generation must not replace an existing converted artifact.
    const output = try std.Io.Dir.cwd().createFile(init.io, args[2], .{ .exclusive = true });
    defer output.close(init.io);
    errdefer std.Io.Dir.cwd().deleteFile(init.io, args[2]) catch {};
    try output.writeStreamingAll(init.io, prepared);
}
