// SPDX-License-Identifier: GPL-2.0-or-later
//! NVIDIA DLSS Super Resolution (r_vkUpscaler 2) through the NGX runtime that ships with the
//! NVIDIA driver (libnvidia-ngx.so.1 on Linux, _nvngx.dll on Windows). The DLSS module itself
//! (libnvidia-ngx-dlss.so.* or nvngx_dlss.dll) is proprietary and is never distributed with dk3: a user who
//! installs it puts it in dlss/ under the game's home directory, or points r_vkDlssPath or
//! DK3_DLSS_PATH at its directory. Nothing from NVIDIA's SDK is linked or included; the few NGX
//! entry points, structures and parameter names used here are declared below. Without the
//! runtime, the module or an NVIDIA GPU, DLSS reports itself unavailable and the renderer
//! upscales with FSR (fsr.zig) or its own resolve (taa.zig).
const std = @import("std");
const builtin = @import("builtin");
const c = @import("c.zig").c;
const common = @import("common.zig");
const cvars = @import("cvars.zig");
const vk = @import("vk.zig");
const fsr = @import("fsr.zig");

// NGX interface (NVSDK_NGX API 1.5, the version this was written against).
const sdk_version: c_int = 0x15;
const result_success: u32 = 1;
const feature_super_sampling: c_int = 1;
const flag_hdr: c_int = 1 << 0;
const flag_mv_low_res: c_int = 1 << 1;
const flag_auto_exposure: c_int = 1 << 6;
const Quality = enum(c_int) { max_performance = 0, balanced = 1, max_quality = 2, ultra_performance = 3, ultra_quality = 4, dlaa = 5 };

const Parameter = extern struct { vtable: *const ParameterTable };
/// The parameter map's virtual functions in declaration order (Itanium C++ ABI).
const ParameterTable = extern struct {
    set_ull: *const fn (*Parameter, [*:0]const u8, c_ulonglong) callconv(.c) void,
    set_f: *const fn (*Parameter, [*:0]const u8, f32) callconv(.c) void,
    set_d: *const fn (*Parameter, [*:0]const u8, f64) callconv(.c) void,
    set_ui: *const fn (*Parameter, [*:0]const u8, c_uint) callconv(.c) void,
    set_i: *const fn (*Parameter, [*:0]const u8, c_int) callconv(.c) void,
    set_d3d11: *const anyopaque,
    set_d3d12: *const anyopaque,
    set_void: *const fn (*Parameter, [*:0]const u8, ?*anyopaque) callconv(.c) void,
    get_ull: *const anyopaque,
    get_f: *const anyopaque,
    get_d: *const anyopaque,
    get_ui: *const fn (*Parameter, [*:0]const u8, *c_uint) callconv(.c) u32,
    get_i: *const fn (*Parameter, [*:0]const u8, *c_int) callconv(.c) u32,
};

const Wide = if (builtin.os.tag == .windows) u16 else u32;
const PathList = extern struct { path: [*]const [*:0]const Wide, length: c_uint };
const LoggingInfo = extern struct { callback: ?*const anyopaque = null, minimum_level: c_int = 0, disable_other_sinks: bool = false };
const FeatureCommonInfo = extern struct { paths: PathList, internal: ?*anyopaque = null, logging: LoggingInfo = .{} };

const ImageViewInfo = extern struct {
    view: c.VkImageView,
    image: c.VkImage,
    range: c.VkImageSubresourceRange,
    format: c.VkFormat,
    width: c_uint,
    height: c_uint,
};
const Resource = extern struct {
    info: ImageViewInfo,
    kind: c_int = 0, // image view
    read_write: bool,
};

const Handle = opaque {};
const Api = struct {
    init: *const fn (u64, [*:0]const Wide, c.VkInstance, c.VkPhysicalDevice, c.VkDevice, c.PFN_vkGetInstanceProcAddr, c.PFN_vkGetDeviceProcAddr, c_int, *const FeatureCommonInfo) callconv(.c) u32,
    shutdown: *const fn () callconv(.c) u32,
    capabilities: *const fn (*?*Parameter) callconv(.c) u32,
    allocate: *const fn (*?*Parameter) callconv(.c) u32,
    destroy_parameters: *const fn (*Parameter) callconv(.c) u32,
    create: *const fn (c.VkDevice, c.VkCommandBuffer, c_int, *Parameter, *?*Handle) callconv(.c) u32,
    evaluate: *const fn (c.VkCommandBuffer, *const Handle, *Parameter, ?*const anyopaque) callconv(.c) u32,
    release: *const fn (*Handle) callconv(.c) u32,
};

var api: ?Api = null;
var library: ?*anyopaque = null;
var tried = false;
var initialized = false;
var supported = false;
var parameters: ?*Parameter = null;
var handle: ?*Handle = null;
var feature_render: [2]u32 = .{ 0, 0 };
var feature_display: [2]u32 = .{ 0, 0 };
var feature_quality: Quality = .dlaa;
var feature_preset: c_int = 0;

fn symbol(comptime T: type, name: [:0]const u8) ?T {
    return @ptrCast(c.SDL_LoadFunction(library, name) orelse return null);
}

fn loadNgx(name: [*:0]const u8) ?*anyopaque {
    const lib = c.SDL_LoadObject(name) orelse return null;
    if (c.SDL_LoadFunction(lib, "NVSDK_NGX_VULKAN_Init_Ext2") == null) {
        c.SDL_UnloadObject(lib);
        return null;
    }
    return lib;
}

/// SDL supplies the shared dynamic loader. On Windows, the driver records its NGX core
/// location in the registry; the SDK-compatible nvngx.dll name remains a fallback.
fn openRuntime() ?*anyopaque {
    if (builtin.os.tag == .windows) {
        const registry = struct {
            extern "advapi32" fn RegGetValueW(?*anyopaque, [*:0]const u16, [*:0]const u16, u32, ?*u32, ?*anyopaque, *u32) callconv(.winapi) i32;
        };
        var directory: [1024]u16 = undefined;
        var size: u32 = @sizeOf(@TypeOf(directory));
        const root: ?*anyopaque = @ptrFromInt(0x80000002); // HKEY_LOCAL_MACHINE
        if (registry.RegGetValueW(root, std.unicode.utf8ToUtf16LeStringLiteral("SOFTWARE\\NVIDIA Corporation\\Global\\NGXCore"), std.unicode.utf8ToUtf16LeStringLiteral("FullPath"), 0x2, null, &directory, &size) == 0) {
            const units = @min(@as(usize, size) / @sizeOf(u16), directory.len);
            const length = std.mem.indexOfScalar(u16, directory[0..units], 0) orelse 0;
            var path_text: [4096]u8 = undefined;
            const used = std.unicode.utf16LeToUtf8(&path_text, directory[0..length]) catch 0;
            var filename: [4120]u8 = undefined;
            if (used != 0) {
                const full = std.fmt.bufPrintZ(&filename, "{s}\\_nvngx.dll", .{path_text[0..used]}) catch null;
                if (full) |path| if (loadNgx(path)) |lib| return lib;
            }
        }
        return loadNgx("nvngx.dll") orelse loadNgx("_nvngx.dll");
    }
    return loadNgx("libnvidia-ngx.so.1");
}

/// NGX uses native wchar_t: UTF-16 on Windows, UTF-32 on Linux.
fn wide(out: []Wide, value: []const u8) ?[*:0]const Wide {
    if (value.len >= out.len) return null;
    const length = if (builtin.os.tag == .windows)
        std.unicode.utf8ToUtf16Le(out, value) catch return null
    else blk: {
        var iterator = (std.unicode.Utf8View.init(value) catch return null).iterator();
        var index: usize = 0;
        while (iterator.nextCodepoint()) |point| : (index += 1) out[index] = point;
        break :blk index;
    };
    out[length] = 0;
    return @ptrCast(out.ptr);
}

/// Where the user installed the DLSS module: r_vkDlssPath, DK3_DLSS_PATH, else dlss/ in the
/// game's home directory.
fn modulePath(buffer: []u8) ?[]const u8 {
    const from_cvar = common.span(cvars.vkDlssPath.string);
    if (from_cvar.len > 0) return from_cvar;
    if (std.c.getenv("DK3_DLSS_PATH")) |value| return std.mem.span(value);
    const home = common.span(common.ri.Cvar_Get.?("fs_homepath", "", 0).*.string);
    if (home.len == 0) return null;
    return std.fmt.bufPrint(buffer, "{s}/dlss", .{home}) catch null;
}

/// Loads NGX and asks it whether DLSS can run here; once per renderer.
fn start() void {
    tried = true;
    if (!vk.s.capabilities.ngx or vk.s.device == null) return;
    library = openRuntime();
    if (library == null) return;
    api = .{
        .init = symbol(@FieldType(Api, "init"), "NVSDK_NGX_VULKAN_Init_Ext2") orelse return,
        .shutdown = symbol(@FieldType(Api, "shutdown"), "NVSDK_NGX_VULKAN_Shutdown") orelse return,
        .capabilities = symbol(@FieldType(Api, "capabilities"), "NVSDK_NGX_VULKAN_GetCapabilityParameters") orelse return,
        .allocate = symbol(@FieldType(Api, "allocate"), "NVSDK_NGX_VULKAN_AllocateParameters") orelse return,
        .destroy_parameters = symbol(@FieldType(Api, "destroy_parameters"), "NVSDK_NGX_VULKAN_DestroyParameters") orelse return,
        .create = symbol(@FieldType(Api, "create"), "NVSDK_NGX_VULKAN_CreateFeature1") orelse return,
        .evaluate = symbol(@FieldType(Api, "evaluate"), "NVSDK_NGX_VULKAN_EvaluateFeature") orelse return,
        .release = symbol(@FieldType(Api, "release"), "NVSDK_NGX_VULKAN_ReleaseFeature") orelse return,
    };
    const ngx = api.?;
    var path_text: [512]u8 = undefined;
    var module_wide: [512]Wide = undefined;
    var data_wide: [1024]Wide = undefined;
    const module = modulePath(&path_text);
    var paths = [1][*:0]const Wide{wide(&module_wide, module orelse ".") orelse return};
    const info: FeatureCommonInfo = .{ .paths = .{ .path = &paths, .length = 1 } };
    // Any application id serves for DLSS Super Resolution outside NVIDIA's app profiles.
    const home = common.span(common.ri.Cvar_Get.?("fs_homepath", "", 0).*.string);
    const result = ngx.init(0x6b3d6b33, wide(&data_wide, if (home.len != 0) home else ".") orelse return, vk.s.instance, vk.s.physical, vk.s.device, vk.getInstanceProcAddr(), vk.i.GetDeviceProcAddr, sdk_version, &info);
    if (result != result_success) {
        common.developer("dlss: NGX init failed ({x})\n", .{result});
        return;
    }
    initialized = true;
    var caps: ?*Parameter = null;
    if (ngx.capabilities(&caps) != result_success or caps == null) return;
    defer _ = ngx.destroy_parameters(caps.?);
    var value: c_int = 0;
    var needs_driver: c_int = 0;
    _ = caps.?.vtable.get_i(caps.?, "SuperSampling.Available", &value);
    _ = caps.?.vtable.get_i(caps.?, "SuperSampling.NeedsUpdatedDriver", &needs_driver);
    supported = value != 0;
    if (needs_driver != 0) common.info("dlss: the NVIDIA driver is too old for this DLSS runtime\n", .{});
    common.info("dlss: NGX ready, DLSS {s}{s}\n", .{ if (supported) "available" else "unavailable", if (!supported and module == null) " (install NVIDIA's DLSS runtime in dlss/ under the game's home directory)" else "" });
    if (!supported) return;
    if (ngx.allocate(&parameters) != result_success) supported = false;
}

pub fn available() bool {
    if (!tried) start();
    return supported;
}

fn qualityFor(render: [2]u32, display: [2]u32) Quality {
    const scale = @as(f32, @floatFromInt(render[0])) / @as(f32, @floatFromInt(display[0]));
    if (scale >= 0.99) return .dlaa;
    if (scale >= 0.66) return .max_quality;
    if (scale >= 0.57) return .balanced;
    if (scale >= 0.49) return .max_performance;
    return .ultra_performance;
}

fn release() void {
    if (handle) |h| if (api) |ngx| {
        vk.waitIdle();
        _ = ngx.release(h);
    };
    handle = null;
    feature_render = .{ 0, 0 };
}

fn resource(view: fsr.View, width: u32, height: u32, read_write: bool) Resource {
    return .{
        .info = .{
            .view = view.view,
            .image = view.image,
            .range = .{ .aspectMask = view.aspect, .baseMipLevel = 0, .levelCount = 1, .baseArrayLayer = 0, .layerCount = 1 },
            .format = view.format,
            .width = width,
            .height = height,
        },
        .read_write = read_write,
    };
}

/// Evaluates DLSS into `inputs.output`; false when it is unavailable or fails (the caller falls
/// back to another resolve).
pub fn dispatch(cmd: c.VkCommandBuffer, inputs: fsr.Inputs) bool {
    if (!available()) return false;
    const ngx = api.?;
    const p = parameters.?;
    const quality = qualityFor(inputs.render, inputs.display);
    if (handle == null or feature_preset != cvars.vkDlssPreset.integer or feature_render[0] != inputs.render[0] or feature_render[1] != inputs.render[1] or feature_display[0] != inputs.display[0] or feature_display[1] != inputs.display[1] or feature_quality != quality) {
        release();
        p.vtable.set_ui(p, "CreationNodeMask", 1);
        p.vtable.set_ui(p, "VisibilityNodeMask", 1);
        p.vtable.set_ui(p, "Width", inputs.render[0]);
        p.vtable.set_ui(p, "Height", inputs.render[1]);
        p.vtable.set_ui(p, "OutWidth", inputs.display[0]);
        p.vtable.set_ui(p, "OutHeight", inputs.display[1]);
        p.vtable.set_i(p, "PerfQualityValue", @intFromEnum(quality));
        p.vtable.set_i(p, "DLSS.Feature.Create.Flags", flag_hdr | flag_mv_low_res | flag_auto_exposure);
        p.vtable.set_i(p, "DLSS.Enable.Output.Subrects", 0);
        // Render presets (r_vkDlssPreset): 0 keeps the runtime's default for each mode.
        const preset: c_uint = @intCast(std.math.clamp(cvars.vkDlssPreset.integer, 0, 15));
        for ([_][*:0]const u8{ "DLSS.Hint.Render.Preset.DLAA", "DLSS.Hint.Render.Preset.Quality", "DLSS.Hint.Render.Preset.Balanced", "DLSS.Hint.Render.Preset.Performance", "DLSS.Hint.Render.Preset.UltraPerformance", "DLSS.Hint.Render.Preset.UltraQuality" }) |name| p.vtable.set_ui(p, name, preset);
        var created: ?*Handle = null;
        const result = ngx.create(vk.s.device, cmd, feature_super_sampling, p, &created);
        if (result != result_success or created == null) {
            common.warn("dlss: feature creation failed ({x}); using FSR\n", .{result});
            supported = false;
            return false;
        }
        handle = created;
        feature_render = inputs.render;
        feature_display = inputs.display;
        feature_quality = quality;
        feature_preset = cvars.vkDlssPreset.integer;
    }
    // NGX samples its inputs in the shader-read layout and writes the output in general.
    const read_stages = c.VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;
    vk.barrier(cmd, inputs.depth.image, c.VK_IMAGE_ASPECT_DEPTH_BIT, inputs.depth.layout, c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, vk.stage_all, 0, read_stages, vk.access_shader_read);
    vk.barrier(cmd, inputs.motion.image, c.VK_IMAGE_ASPECT_COLOR_BIT, inputs.motion.layout, c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, c.VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT, c.VK_ACCESS_2_SHADER_WRITE_BIT, read_stages, vk.access_shader_read);
    var color = resource(inputs.color, inputs.render[0], inputs.render[1], false);
    var depth = resource(inputs.depth, inputs.render[0], inputs.render[1], false);
    var motion = resource(inputs.motion, inputs.render[0], inputs.render[1], false);
    var output = resource(inputs.output, inputs.display[0], inputs.display[1], true);
    p.vtable.set_void(p, "Color", &color);
    p.vtable.set_void(p, "Output", &output);
    p.vtable.set_void(p, "Depth", &depth);
    p.vtable.set_void(p, "MotionVectors", &motion);
    p.vtable.set_void(p, "TransparencyMask", null);
    p.vtable.set_void(p, "ExposureTexture", null);
    p.vtable.set_void(p, "DLSS.Input.Bias.Current.Color.Mask", null);
    p.vtable.set_f(p, "Jitter.Offset.X", inputs.jitter[0]);
    p.vtable.set_f(p, "Jitter.Offset.Y", inputs.jitter[1]);
    p.vtable.set_f(p, "Sharpness", 0);
    p.vtable.set_i(p, "Reset", @intFromBool(inputs.reset));
    // Motion vectors are render-target pixels toward the previous position (motion.zig).
    p.vtable.set_f(p, "MV.Scale.X", 1);
    p.vtable.set_f(p, "MV.Scale.Y", 1);
    p.vtable.set_f(p, "FrameTimeDeltaInMsec", inputs.frame_ms);
    p.vtable.set_ui(p, "DLSS.Render.Subrect.Dimensions.Width", inputs.render[0]);
    p.vtable.set_ui(p, "DLSS.Render.Subrect.Dimensions.Height", inputs.render[1]);
    for ([_][*:0]const u8{ "DLSS.Input.Color.Subrect.Base.X", "DLSS.Input.Color.Subrect.Base.Y", "DLSS.Input.Depth.Subrect.Base.X", "DLSS.Input.Depth.Subrect.Base.Y", "DLSS.Input.MV.SubrectBase.X", "DLSS.Input.MV.SubrectBase.Y", "DLSS.Output.Subrect.Base.X", "DLSS.Output.Subrect.Base.Y" }) |name| p.vtable.set_ui(p, name, 0);
    p.vtable.set_f(p, "DLSS.Pre.Exposure", 1);
    p.vtable.set_f(p, "DLSS.Exposure.Scale", 1);
    const result = ngx.evaluate(cmd, handle.?, p, null);
    vk.barrier(cmd, inputs.depth.image, c.VK_IMAGE_ASPECT_DEPTH_BIT, c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, inputs.depth.layout, read_stages, vk.access_shader_read, vk.stage_all, vk.access_shader_read);
    vk.barrier(cmd, inputs.motion.image, c.VK_IMAGE_ASPECT_COLOR_BIT, c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, inputs.motion.layout, read_stages, vk.access_shader_read, vk.stage_all, vk.access_shader_read | c.VK_ACCESS_2_SHADER_WRITE_BIT);
    vk.memoryBarrier(cmd, vk.stage_all, vk.access_memory_write, vk.stage_all, vk.access_memory_read | vk.access_memory_write);
    if (result != result_success) {
        common.warn("dlss: evaluation failed ({x}); using FSR\n", .{result});
        supported = false;
        return false;
    }
    return true;
}

/// Drops the feature (render targets change); NGX itself stays up.
pub fn destroy() void {
    release();
}

/// Before the device goes away.
pub fn shutdown() void {
    release();
    if (api) |ngx| {
        if (parameters) |p| _ = ngx.destroy_parameters(p);
        if (initialized and vk.s.device != null) _ = ngx.shutdown();
    }
    parameters = null;
    initialized = false;
    supported = false;
    tried = false;
    api = null;
    if (library) |lib| c.SDL_UnloadObject(lib);
    library = null;
}
