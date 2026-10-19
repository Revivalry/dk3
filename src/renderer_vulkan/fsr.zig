// SPDX-License-Identifier: GPL-2.0-or-later
//! AMD FidelityFX Super Resolution 3.1 upscaling (r_vkUpscaler 1). The shaders are the
//! FidelityFX SDK v1.1.4 passes bundled unmodified under engine/fidelityfx (MIT, see its
//! LICENSE.txt), compiled from their GLSL entry points; this file replaces the SDK's C++ host
//! (ffx_fsr3upscaler.cpp and the Vulkan backend) with the renderer's own resources and
//! barriers. Inputs: the jittered HDR scene, its depth and motion vectors (motion.zig) at
//! render resolution; output: the display-resolution image the post chain reads (taa.zig).
const std = @import("std");
const c = @import("c.zig").c;
const common = @import("common.zig");
const vk = @import("vk.zig");

// FidelityFX resource identifiers (gpu/fsr3upscaler/ffx_fsr3upscaler_resources.h).
const id = struct {
    const input_color = 2;
    const input_motion_vectors = 3;
    const input_depth = 4;
    const input_exposure = 5;
    const input_reactive_mask = 6;
    const input_transparency_and_composition = 7;
    const reconstructed_previous_nearest_depth = 8;
    const dilated_motion_vectors = 9;
    const dilated_depth = 10;
    const internal_upscaled = 11;
    const accumulation = 12;
    const new_locks = 13;
    const luma_history = 14;
    const lanczos_lut = 16;
    const spd_atomic_count = 17;
    const upscaled_output = 18;
    const accumulation_1 = 20;
    const accumulation_2 = 21;
    const internal_upscaled_1 = 22;
    const internal_upscaled_2 = 23;
    const default_reactivity = 24;
    const dilated_reactive_masks = 26;
    const spd_mips = 27; // levels 0-5 are 27-32
    const frame_info = 34;
    const luma_history_1 = 37;
    const luma_history_2 = 38;
    const luma_1 = 40;
    const luma_2 = 41;
    const shading_change = 42;
    const farthest_depth = 43;
    const farthest_depth_mip1 = 44;
    const current_luma = 45;
    const previous_luma = 46;
    const luma_instability = 48;
    const intermediate_fp16x1 = 49;
    /// Not an SDK resource: the reactive mask fsr_reactive.comp derives from the HDR alpha.
    const reactive = 50;
    const count = 60;
};

const Kind = enum { srv, uav, cb_fsr, cb_spd };
const Binding = struct { kind: Kind, resource: u8 = 0 };

fn srv(resource: u8) Binding {
    return .{ .kind = .srv, .resource = resource };
}
fn uav(resource: u8) Binding {
    return .{ .kind = .uav, .resource = resource };
}
const cb_fsr: Binding = .{ .kind = .cb_fsr };
const cb_spd: Binding = .{ .kind = .cb_spd };

/// Each pass's bindings in binding order, from the `FSR3UPSCALER_BIND_*` defines of its GLSL
/// entry point (engine/fidelityfx/shaders/fsr3upscaler); samplers sit at 1000 and 1001.
const Pass = struct { name: []const u8, bindings: []const Binding };
const passes = [_]Pass{
    .{ .name = "prepare_inputs", .bindings = &.{ srv(id.input_motion_vectors), srv(id.input_depth), srv(id.input_color), uav(id.dilated_motion_vectors), uav(id.dilated_depth), uav(id.reconstructed_previous_nearest_depth), uav(id.farthest_depth), uav(id.current_luma), cb_fsr } },
    .{ .name = "luma_pyramid", .bindings = &.{ srv(id.current_luma), srv(id.farthest_depth), uav(id.spd_atomic_count), uav(id.frame_info), uav(id.spd_mips), uav(id.spd_mips + 1), uav(id.spd_mips + 2), uav(id.spd_mips + 3), uav(id.spd_mips + 4), uav(id.spd_mips + 5), uav(id.farthest_depth_mip1), cb_fsr, cb_spd } },
    .{ .name = "shading_change_pyramid", .bindings = &.{ srv(id.current_luma), srv(id.previous_luma), srv(id.dilated_motion_vectors), srv(id.input_exposure), uav(id.spd_atomic_count), uav(id.spd_mips), uav(id.spd_mips + 1), uav(id.spd_mips + 2), uav(id.spd_mips + 3), uav(id.spd_mips + 4), uav(id.spd_mips + 5), cb_fsr, cb_spd } },
    .{ .name = "shading_change", .bindings = &.{ srv(id.spd_mips), uav(id.shading_change), cb_fsr } },
    .{ .name = "prepare_reactivity", .bindings = &.{ srv(id.reconstructed_previous_nearest_depth), srv(id.dilated_motion_vectors), srv(id.dilated_depth), srv(id.input_reactive_mask), srv(id.input_transparency_and_composition), srv(id.accumulation), srv(id.shading_change), srv(id.current_luma), srv(id.input_exposure), uav(id.dilated_reactive_masks), uav(id.new_locks), uav(id.accumulation), cb_fsr } },
    .{ .name = "luma_instability", .bindings = &.{ srv(id.input_exposure), srv(id.dilated_reactive_masks), srv(id.dilated_motion_vectors), srv(id.frame_info), srv(id.luma_history), srv(id.farthest_depth_mip1), srv(id.current_luma), uav(id.luma_history), uav(id.luma_instability), cb_fsr } },
    .{ .name = "reactive", .bindings = &.{ srv(id.input_color), uav(id.reactive) } },
    .{ .name = "accumulate", .bindings = &.{ srv(id.input_exposure), srv(id.dilated_reactive_masks), srv(id.dilated_motion_vectors), srv(id.internal_upscaled), srv(id.lanczos_lut), srv(id.farthest_depth_mip1), srv(id.current_luma), srv(id.luma_instability), srv(id.input_color), uav(id.internal_upscaled), uav(id.upscaled_output), uav(id.new_locks), cb_fsr } },
};
const pass_index = struct {
    const prepare_inputs = 0;
    const luma_pyramid = 1;
    const shading_change_pyramid = 2;
    const shading_change = 3;
    const prepare_reactivity = 4;
    const luma_instability = 5;
    const reactive = 6;
    const accumulate = 7;
};

/// `cbFSR3Upscaler` (std140; the same layout as the SDK's Fsr3UpscalerConstants).
const Constants = extern struct {
    render_size: [2]i32,
    previous_render_size: [2]i32,
    upscale_size: [2]i32,
    previous_upscale_size: [2]i32,
    max_render_size: [2]i32,
    max_upscale_size: [2]i32,
    device_to_view_depth: [4]f32,
    jitter: [2]f32,
    previous_jitter: [2]f32,
    motion_vector_scale: [2]f32,
    downscale_factor: [2]f32,
    motion_vector_jitter_cancellation: [2]f32,
    tan_half_fov: f32,
    jitter_phase_count: f32,
    delta_time: f32,
    delta_pre_exposure: f32,
    view_space_to_meters: f32,
    frame_index: f32,
    velocity_factor: f32,
    reactiveness_scale: f32,
    shading_change_scale: f32,
    accumulation_added_per_frame: f32,
    min_disocclusion_accumulation: f32,
};

/// `cbSPD`.
const SpdConstants = extern struct {
    mips: u32,
    num_work_groups: u32,
    work_group_offset: [2]u32,
    render_size: [2]u32,
};

const Image = struct {
    texture: vk.Texture = .{},
    /// Single-level views for storage access (only the SPD mip chain has more than one).
    mip_views: [6]c.VkImageView = .{null} ** 6,
};

/// A resource as a dispatch binds it: a view and the layout it is in (with its image, format and
/// aspect for upscalers that describe resources themselves, dlss.zig).
pub const View = struct {
    view: c.VkImageView,
    layout: c.VkImageLayout,
    image: c.VkImage = null,
    format: c.VkFormat = c.VK_FORMAT_UNDEFINED,
    aspect: c.VkImageAspectFlags = c.VK_IMAGE_ASPECT_COLOR_BIT,
};

pub const Inputs = struct {
    color: View,
    depth: View,
    motion: View,
    output: View,
    render: [2]u32,
    display: [2]u32,
    /// Pixel offset of this frame's jitter (FidelityFX convention: x right, y down).
    jitter: [2]f32,
    near: f32,
    far: f32,
    fov_y: f32,
    frame_ms: f32,
    reset: bool,
};

var images: [id.count]Image = [_]Image{.{}} ** id.count;
var set_layouts: [passes.len]c.VkDescriptorSetLayout = .{null} ** passes.len;
var layouts: [passes.len]c.VkPipelineLayout = .{null} ** passes.len;
var pipelines: [passes.len]c.VkPipeline = .{null} ** passes.len;
var samplers: [2]c.VkSampler = .{ null, null };
var created_render: [2]u32 = .{ 0, 0 };
var created_display: [2]u32 = .{ 0, 0 };
var ready = false;
var failed = false;
var first_execution = true;
var frame_parity = false;
var constants: Constants = undefined;

pub fn available() bool {
    return vk.s.capabilities.push_descriptor and !failed;
}

fn spirv(comptime name: []const u8) []const u32 {
    const bytes align(4) = @embedFile(name).*;
    return std.mem.bytesAsSlice(u32, &bytes);
}

fn shaderCode(index: usize) []const u32 {
    return switch (index) {
        0 => spirv("fsr3_prepare_inputs.spv"),
        1 => spirv("fsr3_luma_pyramid.spv"),
        2 => spirv("fsr3_shading_change_pyramid.spv"),
        3 => spirv("fsr3_shading_change.spv"),
        4 => spirv("fsr3_prepare_reactivity.spv"),
        5 => spirv("fsr3_luma_instability.spv"),
        6 => spirv("fsr_reactive.comp.spv"),
        else => spirv("fsr3_accumulate.spv"),
    };
}

fn createPipelines() void {
    for (&samplers, 0..) |*sampler, index| {
        const filter: c.VkFilter = if (index == 0) c.VK_FILTER_NEAREST else c.VK_FILTER_LINEAR;
        const info = std.mem.zeroInit(c.VkSamplerCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
            .magFilter = filter,
            .minFilter = filter,
            .mipmapMode = if (index == 0) @as(c.VkSamplerMipmapMode, c.VK_SAMPLER_MIPMAP_MODE_NEAREST) else c.VK_SAMPLER_MIPMAP_MODE_LINEAR,
            .addressModeU = c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            .addressModeV = c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            .addressModeW = c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            .maxLod = c.VK_LOD_CLAMP_NONE,
        });
        vk.must(vk.d.CreateSampler.?(vk.s.device, &info, null, sampler), "vkCreateSampler");
    }
    for (passes, 0..) |pass, index| {
        var bindings: [16]c.VkDescriptorSetLayoutBinding = undefined;
        for (pass.bindings, 0..) |binding, slot| {
            bindings[slot] = std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
                .binding = @as(u32, @intCast(slot)),
                .descriptorType = @as(c.VkDescriptorType, switch (binding.kind) {
                    .srv => c.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
                    .uav => c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
                    .cb_fsr, .cb_spd => c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                }),
                .descriptorCount = 1,
                .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            });
        }
        var count = pass.bindings.len;
        for (samplers, 0..) |_, k| {
            bindings[count] = std.mem.zeroInit(c.VkDescriptorSetLayoutBinding, .{
                .binding = @as(u32, @intCast(1000 + k)),
                .descriptorType = c.VK_DESCRIPTOR_TYPE_SAMPLER,
                .descriptorCount = 1,
                .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
                .pImmutableSamplers = &samplers[k],
            });
            count += 1;
        }
        const set_info = std.mem.zeroInit(c.VkDescriptorSetLayoutCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .flags = c.VK_DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR,
            .bindingCount = @as(u32, @intCast(count)),
            .pBindings = &bindings,
        });
        vk.must(vk.d.CreateDescriptorSetLayout.?(vk.s.device, &set_info, null, &set_layouts[index]), "vkCreateDescriptorSetLayout");
        const layout_info = std.mem.zeroInit(c.VkPipelineLayoutCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .setLayoutCount = 1,
            .pSetLayouts = &set_layouts[index],
        });
        vk.must(vk.d.CreatePipelineLayout.?(vk.s.device, &layout_info, null, &layouts[index]), "vkCreatePipelineLayout");
        const code = shaderCode(index);
        const module_info = std.mem.zeroInit(c.VkShaderModuleCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = code.len * 4,
            .pCode = code.ptr,
        });
        var module: c.VkShaderModule = null;
        vk.must(vk.d.CreateShaderModule.?(vk.s.device, &module_info, null, &module), "vkCreateShaderModule");
        defer vk.d.DestroyShaderModule.?(vk.s.device, module, null);
        const info = std.mem.zeroInit(c.VkComputePipelineCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
            .stage = std.mem.zeroInit(c.VkPipelineShaderStageCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = c.VK_SHADER_STAGE_COMPUTE_BIT,
                .module = module,
                .pName = "main",
            }),
            .layout = layouts[index],
        });
        vk.must(vk.d.CreateComputePipelines.?(vk.s.device, null, 1, &info, null, &pipelines[index]), "vkCreateComputePipelines");
    }
}

fn createImage(resource: u8, width: u32, height: u32, levels: u32, format: c.VkFormat) void {
    const usage = c.VK_IMAGE_USAGE_STORAGE_BIT | c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    const image = &images[resource];
    image.texture = vk.createImage(@max(width, 1), @max(height, 1), levels, format, usage, c.VK_IMAGE_ASPECT_COLOR_BIT);
    for (0..@min(levels, 6)) |level| {
        const info = std.mem.zeroInit(c.VkImageViewCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = image.texture.image,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = format,
            .subresourceRange = .{ .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT, .baseMipLevel = @as(u32, @intCast(level)), .levelCount = 1, .baseArrayLayer = 0, .layerCount = 1 },
        });
        vk.must(vk.d.CreateImageView.?(vk.s.device, &info, null, &image.mip_views[level]), "vkCreateImageView");
    }
}

fn lanczos2(x: f32) f32 {
    if (x == 0) return 1;
    const px = std.math.pi * x;
    return (@sin(px) / px) * (@sin(0.5 * px) / (0.5 * px));
}

/// The internal resources of ffx_fsr3upscaler.cpp fsr3upscalerCreate, in the general layout.
fn createResources(cmd: c.VkCommandBuffer, render: [2]u32, display: [2]u32) void {
    const was_content = vk.content_arena;
    vk.content_arena = false;
    defer vk.content_arena = was_content;
    const rw = render[0];
    const rh = render[1];
    const half = [2]u32{ rw / 2, rh / 2 };
    createImage(id.accumulation_1, rw, rh, 1, c.VK_FORMAT_R8_UNORM);
    createImage(id.accumulation_2, rw, rh, 1, c.VK_FORMAT_R8_UNORM);
    createImage(id.luma_1, rw, rh, 1, c.VK_FORMAT_R16_SFLOAT);
    createImage(id.luma_2, rw, rh, 1, c.VK_FORMAT_R16_SFLOAT);
    createImage(id.intermediate_fp16x1, rw, rh, 1, c.VK_FORMAT_R16_SFLOAT);
    createImage(id.shading_change, half[0], half[1], 1, c.VK_FORMAT_R8_UNORM);
    createImage(id.new_locks, display[0], display[1], 1, c.VK_FORMAT_R8_UNORM);
    createImage(id.internal_upscaled_1, display[0], display[1], 1, c.VK_FORMAT_R16G16B16A16_SFLOAT);
    createImage(id.internal_upscaled_2, display[0], display[1], 1, c.VK_FORMAT_R16G16B16A16_SFLOAT);
    const spd_levels: u32 = std.math.log2_int(u32, @max(@max(half[0], half[1]), 1)) + 1;
    createImage(id.spd_mips, half[0], half[1], spd_levels, c.VK_FORMAT_R16G16_SFLOAT);
    createImage(id.farthest_depth_mip1, half[0], half[1], 1, c.VK_FORMAT_R16_SFLOAT);
    createImage(id.luma_history_1, rw, rh, 1, c.VK_FORMAT_R16G16B16A16_SFLOAT);
    createImage(id.luma_history_2, rw, rh, 1, c.VK_FORMAT_R16G16B16A16_SFLOAT);
    createImage(id.spd_atomic_count, 1, 1, 1, c.VK_FORMAT_R32_UINT);
    createImage(id.dilated_reactive_masks, rw, rh, 1, c.VK_FORMAT_R8G8B8A8_UNORM);
    createImage(id.reactive, rw, rh, 1, c.VK_FORMAT_R8_UNORM);
    createImage(id.lanczos_lut, 128, 1, 1, c.VK_FORMAT_R16_SNORM);
    createImage(id.default_reactivity, 1, 1, 1, c.VK_FORMAT_R8_UNORM);
    createImage(id.frame_info, 1, 1, 1, c.VK_FORMAT_R32G32B32A32_SFLOAT);
    createImage(id.dilated_motion_vectors, rw, rh, 1, c.VK_FORMAT_R16G16_SFLOAT);
    createImage(id.dilated_depth, rw, rh, 1, c.VK_FORMAT_R32_SFLOAT);
    createImage(id.reconstructed_previous_nearest_depth, rw, rh, 1, c.VK_FORMAT_R32_UINT);
    for (&images) |*image| {
        if (image.texture.image == null) continue;
        vk.barrier(cmd, image.texture.image, c.VK_IMAGE_ASPECT_COLOR_BIT, c.VK_IMAGE_LAYOUT_UNDEFINED, c.VK_IMAGE_LAYOUT_GENERAL, vk.stage_all, 0, vk.stage_all, vk.access_memory_read | vk.access_memory_write);
    }
    // The Lanczos-2 weight table and the default (zero) reactivity.
    var lut: [128]i16 = undefined;
    for (&lut, 0..) |*weight, index| {
        const x = 2.0 * @as(f32, @floatFromInt(index)) / 127.0;
        weight.* = @intFromFloat(@round(lanczos2(x) * 32767.0));
    }
    const space = vk.stage(@sizeOf(@TypeOf(lut)));
    @memcpy(space.bytes, std.mem.asBytes(&lut));
    const region = std.mem.zeroInit(c.VkBufferImageCopy, .{
        .bufferOffset = space.offset,
        .imageSubresource = .{ .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT, .mipLevel = 0, .baseArrayLayer = 0, .layerCount = 1 },
        .imageExtent = .{ .width = 128, .height = 1, .depth = 1 },
    });
    vk.d.CmdCopyBufferToImage.?(cmd, space.buffer, images[id.lanczos_lut].texture.image, c.VK_IMAGE_LAYOUT_GENERAL, 1, &region);
    clear(cmd, id.default_reactivity, .{ .float32 = .{ 0, 0, 0, 0 } });
    created_render = render;
    created_display = display;
    first_execution = true;
}

pub fn destroy() void {
    if (vk.s.device == null) return;
    for (&images) |*image| {
        for (&image.mip_views) |*view| {
            if (view.* != null) vk.d.DestroyImageView.?(vk.s.device, view.*, null);
            view.* = null;
        }
        vk.destroyImage(&image.texture);
    }
    created_render = .{ 0, 0 };
    created_display = .{ 0, 0 };
}

pub fn shutdown() void {
    destroy();
    if (vk.s.device == null) return;
    for (&pipelines) |*p| if (p.* != null) vk.d.DestroyPipeline.?(vk.s.device, p.*, null);
    for (&layouts) |*l| if (l.* != null) vk.d.DestroyPipelineLayout.?(vk.s.device, l.*, null);
    for (&set_layouts) |*l| if (l.* != null) vk.d.DestroyDescriptorSetLayout.?(vk.s.device, l.*, null);
    for (&samplers) |*sampler| if (sampler.* != null) vk.d.DestroySampler.?(vk.s.device, sampler.*, null);
    pipelines = .{null} ** passes.len;
    layouts = .{null} ** passes.len;
    set_layouts = .{null} ** passes.len;
    samplers = .{ null, null };
    ready = false;
}

fn clear(cmd: c.VkCommandBuffer, resource: u8, value: c.VkClearColorValue) void {
    const range = c.VkImageSubresourceRange{ .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT, .baseMipLevel = 0, .levelCount = c.VK_REMAINING_MIP_LEVELS, .baseArrayLayer = 0, .layerCount = 1 };
    vk.d.CmdClearColorImage.?(cmd, images[resource].texture.image, c.VK_IMAGE_LAYOUT_GENERAL, &value, 1, &range);
}

fn zero() c.VkClearColorValue {
    return .{ .float32 = .{ 0, 0, 0, 0 } };
}

/// Recommended jitter sequence length for this scale (ffxFsr3UpscalerGetJitterPhaseCount).
pub fn jitterPhaseCount(render_width: u32, display_width: u32) u32 {
    const ratio = @as(f32, @floatFromInt(display_width)) / @as(f32, @floatFromInt(@max(render_width, 1)));
    return @max(@as(u32, @intFromFloat(8.0 * ratio * ratio)), 1);
}

/// Runs the upscaler into `inputs.output`; false when it is unavailable (the caller resolves
/// with the built-in temporal pass instead).
pub fn dispatch(cmd: c.VkCommandBuffer, inputs: Inputs) bool {
    if (!available()) return false;
    if (!ready) {
        createPipelines();
        ready = true;
    }
    if (created_render[0] != inputs.render[0] or created_render[1] != inputs.render[1] or created_display[0] != inputs.display[0] or created_display[1] != inputs.display[1]) {
        destroy();
        createResources(cmd, inputs.render, inputs.display);
        vk.memoryBarrier(cmd, vk.stage_all, vk.access_memory_write, vk.stage_all, vk.access_memory_read | vk.access_memory_write);
    }
    const reset = inputs.reset or first_execution;
    const odd = frame_parity;
    frame_parity = !frame_parity;

    // Per-frame views of the ping-ponged and aliased resources (fsr3upscalerDispatch).
    var srvs: [id.count]u8 = undefined;
    var uavs: [id.count]u8 = undefined;
    for (0..id.count) |k| {
        srvs[k] = @intCast(k);
        uavs[k] = @intCast(k);
    }
    srvs[id.accumulation] = if (odd) id.accumulation_2 else id.accumulation_1;
    uavs[id.accumulation] = if (odd) id.accumulation_1 else id.accumulation_2;
    srvs[id.internal_upscaled] = if (odd) id.internal_upscaled_2 else id.internal_upscaled_1;
    uavs[id.internal_upscaled] = if (odd) id.internal_upscaled_1 else id.internal_upscaled_2;
    srvs[id.luma_history] = if (odd) id.luma_history_2 else id.luma_history_1;
    uavs[id.luma_history] = if (odd) id.luma_history_1 else id.luma_history_2;
    srvs[id.current_luma] = if (odd) id.luma_2 else id.luma_1;
    uavs[id.current_luma] = srvs[id.current_luma];
    srvs[id.previous_luma] = if (odd) id.luma_1 else id.luma_2;
    srvs[id.farthest_depth] = id.intermediate_fp16x1;
    uavs[id.farthest_depth] = id.intermediate_fp16x1;
    srvs[id.luma_instability] = id.intermediate_fp16x1;
    uavs[id.luma_instability] = id.intermediate_fp16x1;
    // Auto exposure: the luma pyramid's frame info supplies the exposure.
    srvs[id.input_exposure] = id.frame_info;
    srvs[id.input_reactive_mask] = id.reactive;
    srvs[id.input_transparency_and_composition] = id.default_reactivity;

    // Constants.
    const rw: i32 = @intCast(inputs.render[0]);
    const rh: i32 = @intCast(inputs.render[1]);
    const dw: i32 = @intCast(inputs.display[0]);
    const dh: i32 = @intCast(inputs.display[1]);
    if (first_execution) constants = std.mem.zeroes(Constants);
    constants.previous_jitter = constants.jitter;
    constants.jitter = inputs.jitter;
    constants.previous_render_size = constants.render_size;
    constants.render_size = .{ rw, rh };
    constants.max_render_size = .{ rw, rh };
    constants.previous_upscale_size = constants.upscale_size;
    constants.upscale_size = .{ dw, dh };
    constants.max_upscale_size = .{ dw, dh };
    const aspect = @as(f32, @floatFromInt(rw)) / @as(f32, @floatFromInt(rh));
    const horizontal = std.math.atan(@tan(inputs.fov_y / 2) * aspect) * 2;
    constants.tan_half_fov = @tan(horizontal * 0.5);
    // Q3 units are inches.
    constants.view_space_to_meters = 0.0254;
    // setupDeviceDepthToViewSpaceDepthParams: standard (not inverted, finite) depth.
    const near = @min(inputs.near, inputs.far);
    const far = @max(inputs.near, inputs.far);
    const q = far / (near - far);
    const cot_half_fov_y = @cos(0.5 * inputs.fov_y) / @sin(0.5 * inputs.fov_y);
    constants.device_to_view_depth = .{ -q, q * near, 1.0 / (cot_half_fov_y / aspect), 1.0 / cot_half_fov_y };
    constants.downscale_factor = .{ @as(f32, @floatFromInt(rw)) / @as(f32, @floatFromInt(dw)), @as(f32, @floatFromInt(rh)) / @as(f32, @floatFromInt(dh)) };
    constants.delta_pre_exposure = 1;
    // Motion vectors are render-target pixels (motion.zig): scale 1 per render pixel.
    constants.motion_vector_scale = .{ 1.0 / @as(f32, @floatFromInt(rw)), 1.0 / @as(f32, @floatFromInt(rh)) };
    constants.motion_vector_jitter_cancellation = .{ 0, 0 };
    const phases: f32 = @floatFromInt(jitterPhaseCount(inputs.render[0], inputs.display[0]));
    if (reset or constants.jitter_phase_count == 0) {
        constants.jitter_phase_count = phases;
    } else if (phases > constants.jitter_phase_count) {
        constants.jitter_phase_count += 1;
    } else if (phases < constants.jitter_phase_count) {
        constants.jitter_phase_count -= 1;
    }
    constants.delta_time = std.math.clamp(inputs.frame_ms / 1000.0, 0, 1);
    constants.frame_index = if (reset) 0 else constants.frame_index + 1;
    constants.velocity_factor = 1;
    constants.reactiveness_scale = 1;
    constants.shading_change_scale = 1;
    constants.accumulation_added_per_frame = 1.0 / 3.0;
    constants.min_disocclusion_accumulation = -1.0 / 3.0;

    // ffxSpdSetup over the render rectangle.
    const groups = [2]u32{ (inputs.render[0] - 1) / 64 + 1, (inputs.render[1] - 1) / 64 + 1 };
    const spd: SpdConstants = .{
        .mips = @min(std.math.log2_int(u32, @max(@max(inputs.render[0], inputs.render[1]), 1)), 12),
        .num_work_groups = groups[0] * groups[1],
        .work_group_offset = .{ 0, 0 },
        .render_size = inputs.render,
    };
    const cb_space = vk.frame().stream.alloc(512, 256) orelse return false;
    @memcpy(cb_space.bytes[0..@sizeOf(Constants)], std.mem.asBytes(&constants));
    @memcpy(cb_space.bytes[256..][0..@sizeOf(SpdConstants)], std.mem.asBytes(&spd));
    const buffers = [2]c.VkDescriptorBufferInfo{
        .{ .buffer = cb_space.buffer, .offset = cb_space.offset, .range = @sizeOf(Constants) },
        .{ .buffer = cb_space.buffer, .offset = cb_space.offset + 256, .range = @sizeOf(SpdConstants) },
    };

    // Clears (fsr3upscalerDispatch).
    if (first_execution) {
        for ([_]u8{ id.accumulation_1, id.accumulation_2, id.luma_1, id.luma_2 }) |resource| clear(cmd, resource, zero());
    }
    if (reset) {
        clear(cmd, srvs[id.accumulation], zero());
        clear(cmd, id.frame_info, .{ .float32 = .{ -1, 1, 0, 0 } });
    }
    const one: f32 = 1;
    clear(cmd, id.reconstructed_previous_nearest_depth, .{ .uint32 = .{ @bitCast(one), @bitCast(one), @bitCast(one), @bitCast(one) } });
    clear(cmd, id.spd_atomic_count, .{ .uint32 = .{ 0, 0, 0, 0 } });
    clear(cmd, id.spd_mips, zero());
    vk.memoryBarrier(cmd, vk.stage_copy, vk.access_transfer_write, c.VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT, vk.access_shader_read | c.VK_ACCESS_2_SHADER_WRITE_BIT);
    first_execution = false;

    const external = struct {
        fn view(in: Inputs, resource: u8) ?View {
            return switch (resource) {
                id.input_color => in.color,
                id.input_depth => in.depth,
                id.input_motion_vectors => in.motion,
                id.upscaled_output => in.output,
                else => null,
            };
        }
    };
    const render_groups = [2]u32{ (inputs.render[0] + 7) / 8, (inputs.render[1] + 7) / 8 };
    const display_groups = [2]u32{ (inputs.display[0] + 7) / 8, (inputs.display[1] + 7) / 8 };
    const shading_groups = [2]u32{ (inputs.render[0] / 2 + 7) / 8, (inputs.render[1] / 2 + 7) / 8 };
    const order = [_]struct { pass: usize, groups: [2]u32 }{
        .{ .pass = pass_index.reactive, .groups = render_groups },
        .{ .pass = pass_index.prepare_inputs, .groups = render_groups },
        .{ .pass = pass_index.luma_pyramid, .groups = groups },
        .{ .pass = pass_index.shading_change_pyramid, .groups = groups },
        .{ .pass = pass_index.shading_change, .groups = shading_groups },
        .{ .pass = pass_index.prepare_reactivity, .groups = render_groups },
        .{ .pass = pass_index.luma_instability, .groups = render_groups },
        .{ .pass = pass_index.accumulate, .groups = display_groups },
    };
    for (order) |step| {
        const pass = passes[step.pass];
        var writes: [16]c.VkWriteDescriptorSet = undefined;
        var image_infos: [16]c.VkDescriptorImageInfo = undefined;
        for (pass.bindings, 0..) |binding, slot| {
            var write = std.mem.zeroInit(c.VkWriteDescriptorSet, .{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .dstBinding = @as(u32, @intCast(slot)),
                .descriptorCount = 1,
            });
            switch (binding.kind) {
                .cb_fsr, .cb_spd => {
                    write.descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
                    write.pBufferInfo = &buffers[if (binding.kind == .cb_fsr) 0 else 1];
                },
                .srv, .uav => {
                    const storage = binding.kind == .uav;
                    write.descriptorType = if (storage) c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE else c.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
                    var info = c.VkDescriptorImageInfo{ .sampler = null, .imageView = null, .imageLayout = c.VK_IMAGE_LAYOUT_GENERAL };
                    if (external.view(inputs, binding.resource)) |v| {
                        info.imageView = v.view;
                        info.imageLayout = v.layout;
                    } else if (storage and binding.resource >= id.spd_mips and binding.resource <= id.spd_mips + 5) {
                        // Storage views of the SPD chain, one per level (the last repeats).
                        const level = binding.resource - id.spd_mips;
                        const mips = &images[id.spd_mips].mip_views;
                        var chosen = level;
                        while (chosen > 0 and mips[chosen] == null) chosen -= 1;
                        info.imageView = mips[chosen];
                    } else {
                        const physical = if (storage) uavs[binding.resource] else srvs[binding.resource];
                        const image = &images[physical];
                        info.imageView = if (storage) image.mip_views[0] else image.texture.view;
                    }
                    image_infos[slot] = info;
                    write.pImageInfo = &image_infos[slot];
                },
            }
            writes[slot] = write;
        }
        vk.d.CmdBindPipeline.?(cmd, c.VK_PIPELINE_BIND_POINT_COMPUTE, pipelines[step.pass]);
        vk.d.CmdPushDescriptorSetKHR.?(cmd, c.VK_PIPELINE_BIND_POINT_COMPUTE, layouts[step.pass], 0, @intCast(pass.bindings.len), &writes);
        vk.d.CmdDispatch.?(cmd, step.groups[0], step.groups[1], 1);
        vk.memoryBarrier(cmd, c.VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT, c.VK_ACCESS_2_SHADER_WRITE_BIT, c.VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT | vk.stage_fragment, vk.access_shader_read | c.VK_ACCESS_2_SHADER_WRITE_BIT);
    }
    return true;
}
