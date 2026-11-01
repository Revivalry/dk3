// SPDX-License-Identifier: GPL-2.0-or-later
const std = @import("std");

/// Include header contents in the compiler command key. The local Zig 0.16 C-only
/// module cache reused a renderer after tr_local.h changed; do not trust that hit.
pub fn track(b: *std.Build, module: *std.Build.Module, roots: []const []const u8) void {
    var paths: std.ArrayList([]const u8) = .empty;
    for (roots) |root| {
        var directory = std.Io.Dir.cwd().openDir(b.graph.io, b.pathFromRoot(root), .{ .iterate = true }) catch |err|
            @panic(b.fmt("header directory {s}: {t}", .{ root, err }));
        defer directory.close(b.graph.io);
        var walker = directory.walk(b.allocator) catch @panic("OOM");
        defer walker.deinit();
        while (walker.next(b.graph.io) catch |err| @panic(b.fmt("header inputs: {t}", .{err}))) |entry| {
            if (entry.kind != .file or (!std.mem.endsWith(u8, entry.path, ".h") and !std.mem.endsWith(u8, entry.path, ".inc") and !std.mem.endsWith(u8, entry.path, ".def"))) continue;
            paths.append(b.allocator, b.pathJoin(&.{ root, entry.path })) catch @panic("OOM");
        }
    }
    stamp(b, module, paths.items, "DK3_HEADER_INPUTS");
}

/// C fixtures include implementation .c files, which the local C-only cache
/// can otherwise reuse after those included sources change. Stamp them too.
pub fn trackFiles(b: *std.Build, module: *std.Build.Module, files: []const []const u8) void {
    const paths = b.allocator.dupe([]const u8, files) catch @panic("OOM");
    stamp(b, module, paths, "DK3_INCLUDED_SOURCE_INPUTS");
}

fn stamp(b: *std.Build, module: *std.Build.Module, paths: [][]const u8, macro: []const u8) void {
    std.mem.sort([]const u8, paths, {}, struct {
        fn lessThan(_: void, a: []const u8, c: []const u8) bool {
            return std.mem.lessThan(u8, a, c);
        }
    }.lessThan);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    for (paths) |path| {
        const bytes = std.Io.Dir.cwd().readFileAlloc(b.graph.io, b.pathFromRoot(path), b.allocator, .limited(16 << 20)) catch |err|
            @panic(b.fmt("header input {s}: {t}", .{ path, err }));
        defer b.allocator.free(bytes);
        hash.update(path);
        hash.update(&.{0});
        hash.update(bytes);
        hash.update(&.{0});
    }
    var digest: [32]u8 = undefined;
    hash.final(&digest);
    module.addCMacro(macro, b.fmt("\"{s}\"", .{std.fmt.bytesToHex(digest, .lower)}));
}
