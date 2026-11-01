// SPDX-License-Identifier: GPL-2.0-or-later
const std = @import("std");
const config = @import("ioq3_config.zig");
pub fn declareTests(b: *std.Build, optimize: std.builtin.OptimizeMode) *std.Build.Step {
    const image_tests = @import("renderer_vulkan.zig").declareCpuImageBench(b, optimize);
    const png_baseline = b.option(bool, "PNG_BENCH_BASELINE_CPU", "Profile PNG decoding at the portable renderer CPU baseline") orelse false;
    const png_target = if (png_baseline) b.resolveTargetQuery(.{
        .cpu_arch = b.graph.host.result.cpu.arch,
        .os_tag = b.graph.host.result.os.tag,
        .abi = b.graph.host.result.abi,
        .cpu_model = .baseline,
    }) else b.graph.host;
    const png_bench = b.createModule(.{ .target = png_target, .optimize = optimize, .link_libc = true });
    png_bench.addCMacro("DK3_BENCH_CPU_MODE", if (png_baseline) "\"baseline\"" else "\"native-host\"");
    @import("header_inputs.zig").track(b, png_bench, &.{"engine/ioquake3/code"});
    @import("libdeflate.zig").add(b, png_bench);
    @import("header_inputs.zig").trackFiles(b, png_bench, &.{ "src/tests/renderer_png_bench.c", "engine/ioquake3/code/renderercommon/tr_image_png.c" });
    png_bench.addIncludePath(b.path("engine/ioquake3/code/thirdparty/SDL2-2.32.8/include"));
    for ([_][]const u8{ "src/tests/renderer_png_bench.c", "engine/ioquake3/code/qcommon/q_shared.c" }) |source|
        png_bench.addCSourceFile(.{ .file = b.path(source), .flags = &.{ "-std=gnu99", "-fno-sanitize=alignment", "-ffunction-sections", "-fdata-sections" } });
    for (@import("ioq3_sources.zig").zlib_sources) |source|
        png_bench.addCSourceFile(.{ .file = b.path(b.fmt("engine/ioquake3/{s}", .{source})), .flags = &.{ "-std=gnu99", "-DNO_GZIP", "-w" } });
    const png_bench_exe = b.addExecutable(.{ .name = "png-decode-benchmark", .root_module = png_bench });
    png_bench_exe.link_gc_sections = true;
    const png_bench_step = b.step("bench-png", "Build the actual PNG decoder profiling executable");
    png_bench_step.dependOn(&b.addInstallArtifact(png_bench_exe, .{}).step);
    const zip_bench = b.createModule(.{ .target = b.graph.host, .optimize = optimize, .link_libc = true });
    @import("header_inputs.zig").track(b, zip_bench, &.{"engine/ioquake3/code"});
    for ([_][]const u8{ "src/tests/runtime_zip_bench.c", "engine/ioquake3/code/qcommon/unzip.c", "engine/ioquake3/code/qcommon/ioapi.c" }) |source|
        zip_bench.addCSourceFile(.{ .file = b.path(source), .flags = &.{"-std=gnu99"} });
    for (@import("ioq3_sources.zig").zlib_sources) |source|
        zip_bench.addCSourceFile(.{ .file = b.path(b.fmt("engine/ioquake3/{s}", .{source})), .flags = &.{ "-std=gnu99", "-DNO_GZIP", "-w" } });
    const zip_bench_exe = b.addExecutable(.{ .name = "zip-read-benchmark", .root_module = zip_bench });
    b.step("bench-zip", "Build the actual ZIP reader profiling executable").dependOn(&b.addInstallArtifact(zip_bench_exe, .{}).step);
    const step = b.step("test-runtime", "Check native runtime domain, ECS and adapter contracts");
    step.dependOn(image_tests);
    const root = runtimeModule(b, b.graph.host, optimize, "src/runtime_tests.zig");
    root.addIncludePath(b.path("src/tests/reference"));
    root.addIncludePath(b.path("src/tests"));
    for ([_][]const u8{ "engine/ioquake3/code/game/bg_pmove.c", "engine/ioquake3/code/game/bg_slidemove.c", "engine/ioquake3/code/qcommon/q_math.c", "src/tests/movement_reference.c" }) |source| root.addCSourceFile(.{ .file = b.path(source), .flags = &.{ "-std=gnu99", "-ffp-contract=off" } });
    root.linkSystemLibrary("m", .{});
    addLua(b, root);
    step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = root })).step);
    const configuration = b.createModule(.{ .target = b.graph.host, .optimize = optimize, .link_libc = true });
    @import("header_inputs.zig").track(b, configuration, &.{ "engine/ioquake3/code", "src/tests" });
    for ([_][]const u8{ "src/tests/server_configuration.c", "engine/ioquake3/code/qcommon/q_shared.c" }) |source|
        configuration.addCSourceFile(.{ .file = b.path(source), .flags = &.{ "-std=gnu99", "-ffunction-sections", "-fdata-sections" } });
    const configuration_contract = b.addExecutable(.{ .name = "server-configuration-contracts", .root_module = configuration });
    configuration_contract.link_gc_sections = true;
    step.dependOn(&b.addRunArtifact(configuration_contract).step);
    const collision = b.createModule(.{ .target = b.graph.host, .optimize = optimize, .link_libc = true });
    @import("header_inputs.zig").track(b, collision, &.{ "engine/ioquake3/code", "src/tests" });
    collision.addIncludePath(b.path("engine/ioquake3/code/qcommon"));
    for ([_][]const u8{ "cm_load.c", "cm_patch.c", "cm_polylib.c", "cm_trace.c", "cm_test.c", "q_shared.c", "q_math.c", "md4.c" }) |source|
        collision.addCSourceFile(.{ .file = b.path(b.fmt("engine/ioquake3/code/qcommon/{s}", .{source})), .flags = &.{"-std=gnu99"} });
    collision.addCSourceFile(.{ .file = b.path("src/tests/collision_worlds.c"), .flags = &.{"-std=gnu99"} });
    collision.linkSystemLibrary("m", .{});
    step.dependOn(&b.addRunArtifact(b.addExecutable(.{ .name = "collision-world-contracts", .root_module = collision })).step);
    const png = b.createModule(.{ .target = b.graph.host, .optimize = optimize, .link_libc = true });
    @import("header_inputs.zig").track(b, png, &.{"engine/ioquake3/code"});
    @import("libdeflate.zig").add(b, png);
    @import("header_inputs.zig").trackFiles(b, png, &.{ "engine/ioquake3/code/renderercommon/tr_image_png.c", "engine/ioquake3/code/renderercommon/tr_image_prepare.c", "src/tests/png_fixtures.h" });
    png.addIncludePath(b.path("engine/ioquake3/code/thirdparty/SDL2-2.32.8/include"));
    for ([_][]const u8{ "src/tests/renderer_png.c", "engine/ioquake3/code/qcommon/q_shared.c" }) |source|
        png.addCSourceFile(.{ .file = b.path(source), .flags = &.{ "-std=gnu99", "-fno-sanitize=alignment", "-ffunction-sections", "-fdata-sections" } });
    for (@import("ioq3_sources.zig").zlib_sources) |source|
        png.addCSourceFile(.{ .file = b.path(b.fmt("engine/ioquake3/{s}", .{source})), .flags = &.{ "-std=gnu99", "-DNO_GZIP", "-w" } });
    const png_contract = b.addExecutable(.{ .name = "png-loader-contracts", .root_module = png });
    png.linkSystemLibrary("pthread", .{});
    png_contract.link_gc_sections = true;
    const png_contract_run = b.addRunArtifact(png_contract);
    step.dependOn(&png_contract_run.step);
    b.step("test-png", "Check actual PNG decoding, caching and worker contracts").dependOn(&png_contract_run.step);
    const reads = b.createModule(.{ .target = b.graph.host, .optimize = optimize, .link_libc = true });
    @import("header_inputs.zig").track(b, reads, &.{ "engine/ioquake3/code", "src/tests" });
    reads.addIncludePath(b.path("engine/ioquake3/code/qcommon"));
    for ([_][]const u8{ "src/tests/background_read.c", "engine/ioquake3/code/qcommon/unzip.c", "engine/ioquake3/code/qcommon/ioapi.c" }) |source|
        reads.addCSourceFile(.{ .file = b.path(source), .flags = &.{"-std=gnu99"} });
    for (@import("ioq3_sources.zig").zlib_sources) |source|
        reads.addCSourceFile(.{ .file = b.path(b.fmt("engine/ioquake3/{s}", .{source})), .flags = &.{ "-std=gnu99", "-DNO_GZIP", "-w" } });
    reads.linkSystemLibrary("pthread", .{});
    step.dependOn(&b.addRunArtifact(b.addExecutable(.{ .name = "background-read-contracts", .root_module = reads })).step);
    for ([_]bool{ false, true }) |gl2| {
        const lightmaps = b.createModule(.{ .target = b.graph.host, .optimize = optimize, .link_libc = true });
        @import("header_inputs.zig").track(b, lightmaps, &.{"engine/ioquake3/code"});
        @import("header_inputs.zig").trackFiles(b, lightmaps, &.{if (gl2) "engine/ioquake3/code/renderergl2/tr_bsp.c" else "engine/ioquake3/code/renderergl1/tr_bsp.c"});
        lightmaps.addIncludePath(b.path("engine/ioquake3/code/thirdparty/SDL2-2.32.8/include"));
        if (gl2) lightmaps.addCMacro("DK3_TEST_GL2", "1");
        for ([_][]const u8{ "src/tests/renderer_lightmaps.c", "engine/ioquake3/code/qcommon/q_shared.c" }) |source|
            lightmaps.addCSourceFile(.{ .file = b.path(source), .flags = &.{ "-std=gnu99", "-ffunction-sections", "-fdata-sections" } });
        lightmaps.linkSystemLibrary("m", .{});
        const contract = b.addExecutable(.{ .name = if (gl2) "gl2-lightmap-contracts" else "gl1-lightmap-contracts", .root_module = lightmaps });
        contract.link_gc_sections = true;
        step.dependOn(&b.addRunArtifact(contract).step);
    }
    // Named module imports do not contribute their own tests to the runtime root.
    for ([_][]const u8{ "src/actor_catalog.zig", "src/weapon_catalog.zig", "src/inventory_rules.zig", "src/item_catalog.zig" }) |source| {
        const catalog = b.createModule(.{ .root_source_file = b.path(source), .target = b.graph.host, .optimize = optimize });
        step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = catalog })).step);
    }
    const audit = b.addExecutable(.{ .name = "dk3-runtime-audit", .root_module = b.createModule(.{ .root_source_file = b.path("src/audit.zig"), .target = b.graph.host, .optimize = optimize }) });
    const audit_step = b.step("runtime-audit", "Build read-only save compatibility inspector");
    audit_step.dependOn(&b.addInstallArtifact(audit, .{}).step);
    return step;
}
pub fn addProduct(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, product: config.Product, rules_identity: []const u8) *std.Build.Step.Compile {
    const root = switch (product) {
        .qagame => "src/server.zig",
        .cgame => "src/client.zig",
        .ui => "src/ui.zig",
        else => unreachable,
    };
    const module = runtimeModule(b, target, optimize, root);
    if (product == .qagame) addLua(b, module);
    const compatibility = b.addOptions();
    compatibility.addOption([]const u8, "identity", rules_identity);
    module.addOptions("runtime_build", compatibility);
    @import("header_inputs.zig").track(b, module, &.{"engine/ioquake3/code"});
    return b.addLibrary(.{ .name = @tagName(product), .linkage = .dynamic, .root_module = module });
}

fn runtimeModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, source: []const u8) *std.Build.Module {
    const module = b.createModule(.{ .root_source_file = b.path(source), .target = target, .optimize = optimize, .link_libc = true });
    if (target.result.os.tag == .windows) module.addCMacro("_FORTIFY_SOURCE", "0");
    for ([_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "appearance_catalog", .path = "src/multiplayer/appearance.zig" },
        .{ .name = "online_api", .path = "src/online/api.zig" },
        .{ .name = "inventory_rules", .path = "src/inventory_rules.zig" },
        .{ .name = "weapon_catalog", .path = "src/weapon_catalog.zig" },
        .{ .name = "item_catalog", .path = "src/item_catalog.zig" },
        .{ .name = "actor_catalog", .path = "src/actor_catalog.zig" },
    }) |dependency| module.addImport(dependency.name, b.createModule(.{ .root_source_file = b.path(dependency.path), .target = target, .optimize = optimize }));
    module.addCMacro("DK3_GAME", "1");
    for ([_][]const u8{ "qcommon", "game", "cgame", "ui", "client", "renderercommon", "botlib" }) |directory|
        module.addIncludePath(b.path(b.fmt("engine/ioquake3/code/{s}", .{directory})));
    return module;
}

/// Unmodified bundled Lua 5.4 core and pure libraries (engine/LUA-UPSTREAM.json).
/// Only the server module embeds it, for scripted development drivers.
const lua_sources = [_][]const u8{
    "lapi.c",     "lcode.c",    "lctype.c",   "ldebug.c",  "ldo.c",      "ldump.c",    "lfunc.c",
    "lgc.c",      "llex.c",     "lmem.c",     "lobject.c", "lopcodes.c", "lparser.c",  "lstate.c",
    "lstring.c",  "ltable.c",   "ltm.c",      "lundump.c", "lvm.c",      "lzio.c",     "lauxlib.c",
    "lbaselib.c", "lcorolib.c", "lmathlib.c", "lstrlib.c", "ltablib.c",  "lutf8lib.c",
};
fn addLua(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("engine/lua/src"));
    module.addCSourceFiles(.{ .root = b.path("engine/lua/src"), .files = &lua_sources, .flags = &.{"-std=gnu99"} });
}
