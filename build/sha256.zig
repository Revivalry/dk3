// SPDX-License-Identifier: GPL-2.0-or-later
//! Qualify a separate SHA/AVX2 stdlib implementation; callers remain baseline CPU.
const std = @import("std");
pub fn linkHardware(b: *std.Build, module: *std.Build.Module) void {
    const target = module.resolved_target.?;
    if (target.result.cpu.arch != .x86_64) return;
    var query = target.query;
    query.cpu_model = .baseline;
    query.cpu_features_add = std.Target.x86.featureSet(&.{ .sha, .avx2 });
    query.cpu_features_sub = .empty;
    const hardware = b.createModule(.{
        .root_source_file = b.path("src/core/domain/sha256_hardware.zig"),
        .target = b.resolveTargetQuery(query),
        .optimize = module.optimize.?,
        .pic = true,
    });
    const library = b.addLibrary(.{ .name = "dk3_sha256_hardware", .linkage = .static, .root_module = hardware });
    // Never interpose hardware-target compiler-rt helpers on generic callers.
    library.bundle_compiler_rt = false;
    module.linkLibrary(library);
}
pub fn moduleFor(b: *std.Build, parent: *std.Build.Module) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path("src/core/domain/sha256_runtime.zig"),
        .target = parent.resolved_target.?,
        .optimize = parent.optimize.?,
    });
    linkHardware(b, module);
    return module;
}
