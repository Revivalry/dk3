// SPDX-License-Identifier: GPL-2.0-or-later
//! Resolve reviewed host libraries without exposing host libc headers to the target.
const std = @import("std");
const config = @import("ioq3_config.zig");

pub fn add(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget, library: config.SystemLibrary) void {
    if (target.result.os.tag == .windows and std.mem.eql(u8, library.package, "sdl2")) {
        // The reviewed ioquake3 source bundle includes matching Windows SDL2
        // headers, import libraries and the runtime DLL.
        module.addSystemIncludePath(b.path("engine/ioquake3/code/thirdparty/SDL2-2.32.8/include"));
        module.addLibraryPath(b.path("engine/ioquake3/code/thirdparty/libs/win64"));
        module.linkSystemLibrary("SDL2main", .{ .use_pkg_config = .no });
        module.linkSystemLibrary("SDL2", .{ .use_pkg_config = .no });
        return;
    }
    const pkg_config = b.graph.environ_map.get("PKG_CONFIG") orelse "pkg-config";
    var paths: [2][]const u8 = undefined;
    for ([_][]const u8{ "includedir", "libdir" }, &paths) |variable, *path| {
        var exit_code: u8 = undefined;
        const output = b.runAllowFail(&.{ pkg_config, b.fmt("--variable={s}", .{variable}), library.package }, &exit_code, .ignore) catch |err| {
            module.addCSourceFile(.{ .file = failSource(b, b.fmt("pkg-config package {s}: {t}; install its development package", .{ library.package, err })), .flags = &.{} });
            return;
        };
        path.* = config.pkgConfigDirectory(output) orelse {
            module.addCSourceFile(.{ .file = failSource(b, b.fmt("pkg-config package {s} has no {s}; install its development package", .{ library.package, variable })), .flags = &.{} });
            return;
        };
    }
    // Debian's SDL_config.h includes <SDL2/_real_SDL_config.h> from its multiarch
    // directory. Stage just the library's headers, including that subtree when
    // present: adding /usr/include or its multiarch root would replace Zig's libc.
    const staged = b.addWriteFiles();
    _ = staged.addCopyDirectory(.{ .cwd_relative = b.pathJoin(&.{ paths[0], library.include_subdir }) }, library.include_subdir, .{});
    const triple = target.result.linuxTriple(b.allocator) catch @panic("OOM");
    const multiarch = b.pathJoin(&.{ paths[0], triple, library.include_subdir });
    if (std.Io.Dir.cwd().access(b.graph.io, multiarch, .{})) |_| {
        _ = staged.addCopyDirectory(.{ .cwd_relative = multiarch }, library.include_subdir, .{});
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => @panic(b.fmt("library headers {s}: {t}", .{ multiarch, err })),
    }
    module.addSystemIncludePath(staged.getDirectory().path(b, library.include_subdir));
    module.addSystemIncludePath(staged.getDirectory());
    module.addLibraryPath(.{ .cwd_relative = paths[1] });
    module.linkSystemLibrary(library.link_name, .{ .use_pkg_config = .no });
}

fn failSource(b: *std.Build, message: []const u8) std.Build.LazyPath {
    const generated = b.addWriteFiles();
    generated.step.dependOn(&b.addFail(message).step);
    return generated.add("unavailable.c", "#error unavailable build input\n");
}
