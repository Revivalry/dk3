// SPDX-License-Identifier: GPL-2.0-or-later
//! Native Zig Vulkan renderer module (docs/vulkan-remaster.md). It links only the
//! self-contained renderercommon image decoders; window, materials, worlds and
//! models are Zig. SPIR-V is compiled from src/renderer_vulkan/shaders by glslc.
const std = @import("std");
const config = @import("ioq3_config.zig");
const lists = @import("ioq3_sources.zig");

const source_root = "engine/ioquake3";
const shader_dir = "src/renderer_vulkan/shaders";

/// Every shader stage compiled into the module, embedded as `<file>.spv`.
pub const shaders = [_][]const u8{
    "stage.vert",          "stage.frag",            "composite.vert",    "composite.frag",
    "post_histogram.comp", "post_exposure.comp",    "bloom_down.comp",   "bloom_up.comp",
    "froxel_inject.comp",  "froxel_integrate.comp", "froxel_tiles.comp", "taa.comp",
    "light_cull.comp",     "ddgi.comp",             "rt_skin.comp",      "bake.vert",
    "bake.frag",           "pt_trace.comp",         "pt_temporal.comp",  "pt_atrous.comp",
    "pt_composite.comp",   "light_visibility.comp", "depth.frag",        "lightstyle.comp",
    "motion_fill.comp",    "fsr_reactive.comp",
};

/// renderercommon sources used unchanged: decoders, the resident PNG batches, noise and inflate.
const c_sources = [_][]const u8{
    "code/renderercommon/tr_image_bmp.c",
    "code/renderercommon/tr_image_jpg.c",
    "code/renderercommon/tr_image_pcx.c",
    "code/renderercommon/tr_image_png.c",
    "code/renderercommon/tr_image_prepare.c",
    "code/renderercommon/tr_image_pvr.c",
    "code/renderercommon/tr_image_tga.c",
    "code/renderercommon/tr_noise.c",
    "code/renderercommon/puff.c",
} ++ lists.jpeg_sources ++ lists.dynamic_renderer_sources ++ lists.zlib_sources;

pub fn addProduct(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, settings: config.Config) *std.Build.Step.Compile {
    const module = b.createModule(.{
        .root_source_file = b.path("src/renderer_vulkan/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    if (target.result.os.tag == .windows) {
        module.addCMacro("_FORTIFY_SOURCE", "0");
        module.linkSystemLibrary("advapi32", .{});
    }
    @import("header_inputs.zig").track(b, module, &.{source_root});
    // The OpenGL2 product's reviewed flag and sanitizer rules cover the same decoder files.
    for (c_sources) |path| module.addCSourceFile(.{ .file = b.path(b.pathJoin(&.{ source_root, path })), .flags = config.sourceFlags(.renderer_opengl2, path) });
    module.addCSourceFile(.{ .file = b.path("src/renderer_vulkan/icon.c"), .flags = config.sourceFlags(.renderer_opengl2, "src/renderer_vulkan/icon.c") });
    for (config.productIncludeDirs(b.allocator, .renderer_opengl2, settings) catch @panic("OOM")) |directory|
        module.addIncludePath(b.path(b.pathJoin(&.{ source_root, directory })));
    for ([_][]const u8{ "code/qcommon", "code/renderercommon", "code/sdl" }) |directory|
        module.addIncludePath(b.path(b.pathJoin(&.{ source_root, directory })));
    module.addCMacro("USE_ICON", "1");
    module.addCMacro("USE_RENDERER_DLOPEN", "1");
    module.addCMacro("renderer_vulkan_EXPORTS", "1");
    module.addCMacro("PRODUCT_VERSION", b.fmt("\"{s}\"", .{settings.product_version}));
    module.addCMacro("PRODUCT_DATE", b.fmt("\"{s}\"", .{settings.product_date}));
    @import("system_library.zig").add(b, module, target, config.sdl2);
    module.addSystemIncludePath(vulkanHeaders(b));
    addShaders(b, module);
    if (target.result.os.tag != .windows) for ([_][]const u8{ "dl", "m", "pthread" }) |library| module.linkSystemLibrary(library, .{});
    const artifact = b.addLibrary(.{ .name = "renderer_vulkan", .linkage = .dynamic, .root_module = module });
    return artifact;
}

/// Only `vulkan/` and `vk_video/` from the host include directory: adding the whole
/// directory would mix host glibc headers into the x86_64-linux-gnu target.
fn vulkanHeaders(b: *std.Build) std.Build.LazyPath {
    const pkg_config = b.graph.environ_map.get("PKG_CONFIG") orelse "pkg-config";
    var exit_code: u8 = undefined;
    const output = b.runAllowFail(&.{ pkg_config, "--variable=includedir", "vulkan" }, &exit_code, .ignore) catch
        return failDirectory(b, "pkg-config package vulkan: install vulkan-headers and vulkan-loader-devel");
    const root = config.pkgConfigDirectory(output) orelse return failDirectory(b, "pkg-config package vulkan has no includedir");
    const staged = b.addWriteFiles();
    _ = staged.addCopyDirectory(.{ .cwd_relative = b.pathJoin(&.{ root, "vulkan" }) }, "vulkan", .{});
    _ = staged.addCopyDirectory(.{ .cwd_relative = b.pathJoin(&.{ root, "vk_video" }) }, "vk_video", .{});
    return staged.getDirectory();
}

/// Preprocessor variants: `name` is compiled from `source` with `define` set.
pub const Variant = struct { name: []const u8, source: []const u8, define: []const u8 };
pub const variants = [_]Variant{
    .{ .name = "stage_rt.frag", .source = "stage.frag", .define = "-DRAY_QUERY=1" },
    .{ .name = "stage_early.frag", .source = "stage.frag", .define = "-DEARLY_Z=1" },
    .{ .name = "stage_rt_early.frag", .source = "stage.frag", .define = "-DEARLY_Z_RT=1" },
    .{ .name = "froxel_inject_rt.comp", .source = "froxel_inject.comp", .define = "-DRAY_QUERY=1" },
};

/// FidelityFX FSR 3.1 upscaler passes (engine/fidelityfx, MIT) used by fsr.zig, compiled from
/// their GLSL entry points with the renderer's permutation: HDR colour, render-resolution
/// unjittered motion vectors, standard depth, no sharpening (the composite sharpens).
const fsr_dir = "engine/fidelityfx";
pub const fsr_passes = [_][]const u8{ "prepare_inputs", "luma_pyramid", "shading_change_pyramid", "shading_change", "prepare_reactivity", "luma_instability", "accumulate" };
const fsr_defines = [_][]const u8{
    "-DFFX_GPU=1",
    "-DFFX_GLSL=1",
    "-DFFX_HALF=0",
    "-DFFX_FSR3UPSCALER_OPTION_UPSAMPLE_SAMPLERS_USE_DATA_HALF=0",
    "-DFFX_FSR3UPSCALER_OPTION_ACCUMULATE_SAMPLERS_USE_DATA_HALF=0",
    "-DFFX_FSR3UPSCALER_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF=0",
    "-DFFX_FSR3UPSCALER_OPTION_POSTPROCESSLOCKSTATUS_SAMPLERS_USE_DATA_HALF=0",
    "-DFFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE=2",
    "-DFFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE=1",
    "-DFFX_FSR3UPSCALER_OPTION_HDR_COLOR_INPUT=1",
    "-DFFX_FSR3UPSCALER_OPTION_LOW_RESOLUTION_MOTION_VECTORS=1",
    "-DFFX_FSR3UPSCALER_OPTION_JITTERED_MOTION_VECTORS=0",
    "-DFFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH=0",
    "-DFFX_FSR3UPSCALER_OPTION_APPLY_SHARPENING=0",
};

fn addShaders(b: *std.Build, module: *std.Build.Module) void {
    const glslc = b.findProgram(&.{"glslc"}, &.{}) catch {
        module.addCSourceFile(.{ .file = failSource(b, "glslc not found: install shaderc to build renderer_vulkan"), .flags = &.{} });
        return;
    };
    for (shaders) |name| {
        const compile = b.addSystemCommand(&.{ glslc, "--target-env=vulkan1.3", "-O", "-Werror", "-I" });
        compile.addDirectoryArg(b.path(shader_dir));
        compile.addArgs(&.{ "-MD", "-MF" });
        _ = compile.addDepFileOutputArg(b.fmt("{s}.d", .{name}));
        compile.addArg("-o");
        const output = compile.addOutputFileArg(b.fmt("{s}.spv", .{name}));
        compile.addFileArg(b.path(b.pathJoin(&.{ shader_dir, name })));
        module.addAnonymousImport(b.fmt("{s}.spv", .{name}), .{ .root_source_file = output });
    }
    for (fsr_passes) |pass| {
        const compile = b.addSystemCommand(&.{ glslc, "-fshader-stage=compute", "--target-env=vulkan1.3", "-O" });
        compile.addArgs(&fsr_defines);
        compile.addArg("-I");
        compile.addDirectoryArg(b.path(fsr_dir ++ "/gpu"));
        compile.addArg("-I");
        compile.addDirectoryArg(b.path(fsr_dir ++ "/gpu/fsr3upscaler"));
        compile.addArgs(&.{ "-MD", "-MF" });
        _ = compile.addDepFileOutputArg(b.fmt("fsr3_{s}.d", .{pass}));
        compile.addArg("-o");
        const output = compile.addOutputFileArg(b.fmt("fsr3_{s}.spv", .{pass}));
        compile.addFileArg(b.path(b.fmt(fsr_dir ++ "/shaders/fsr3upscaler/ffx_fsr3upscaler_{s}_pass.glsl", .{pass})));
        module.addAnonymousImport(b.fmt("fsr3_{s}.spv", .{pass}), .{ .root_source_file = output });
    }
    for (variants) |variant| {
        const compile = b.addSystemCommand(&.{ glslc, "--target-env=vulkan1.3", "-O", "-Werror", variant.define, "-I" });
        compile.addDirectoryArg(b.path(shader_dir));
        compile.addArgs(&.{ "-MD", "-MF" });
        _ = compile.addDepFileOutputArg(b.fmt("{s}.d", .{variant.name}));
        compile.addArg("-o");
        const output = compile.addOutputFileArg(b.fmt("{s}.spv", .{variant.name}));
        compile.addFileArg(b.path(b.pathJoin(&.{ shader_dir, variant.source })));
        module.addAnonymousImport(b.fmt("{s}.spv", .{variant.name}), .{ .root_source_file = output });
    }
}

fn failSource(b: *std.Build, message: []const u8) std.Build.LazyPath {
    const generated = b.addWriteFiles();
    generated.step.dependOn(&b.addFail(message).step);
    return generated.add("unavailable.c", "#error unavailable build input\n");
}

fn failDirectory(b: *std.Build, message: []const u8) std.Build.LazyPath {
    const generated = b.addWriteFiles();
    generated.step.dependOn(&b.addFail(message).step);
    return generated.getDirectory();
}
