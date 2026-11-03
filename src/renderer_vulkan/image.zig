// SPDX-License-Identifier: GPL-2.0-or-later
//! Image registry: R_LoadImage/R_FindImageFile/R_CreateImage (renderergl1/tr_image.c) on
//! Vulkan textures in the bindless set. Mipmaps are box-filtered on the CPU as GL1 does with
//! r_simpleMipMaps; picmip drops the top levels; gamma/intensity tables apply at upload.
const std = @import("std");
const c = @import("c.zig").c;
const cext = @import("c.zig");
const common = @import("common.zig");
const cvars = @import("cvars.zig");
const vk = @import("vk.zig");
const jobs = @import("load_jobs");
const prepared_texture = @import("prepared_texture.zig");

pub const Flags = packed struct(u8) {
    mipmap: bool = false,
    picmip: bool = false,
    clamp: bool = false,
    no_light_scale: bool = false,
    nearest: bool = false,
    _: u3 = 0,
};

pub const Liquid = enum(u8) { none, water, slime, lava };

/// Remaster surface response. Values come from `<image>.mat` sidecars (dkq3/tools/materialgen.py)
/// or, without one, from the texture name; `<image>_n` and `<image>_s` maps are used when present.
pub const Material = struct {
    roughness: f32 = 0.75,
    metalness: f32 = 0,
    bump: f32 = 0.6,
    emissive: f32 = 0,
    specular: f32 = 1,
    liquid: Liquid = .none,
    normal: ?*Image = null,
    spec: ?*Image = null,
};

pub const Image = struct {
    name: [c.MAX_QPATH]u8 = undefined,
    width: u32,
    height: u32,
    upload_width: u32,
    upload_height: u32,
    flags: Flags,
    texture: vk.Texture,
    has_alpha: bool,
    /// Mean colour of the source pixels (display-encoded 0-1), e.g. a sky box's light.
    average: [3]f32 = .{ 0.5, 0.5, 0.5 },
    material: Material = .{},
    material_ready: bool = false,
    /// Lightmaps: slot + 1 of the baked direction page (bake.zig), 0 before or without it.
    deluxe_slot: u32 = 0,

    pub fn nameSlice(self: *const Image) []const u8 {
        return std.mem.sliceTo(&self.name, 0);
    }
};

var images: std.ArrayList(*Image) = .empty;
var by_name: std.StringHashMapUnmanaged(*Image) = .empty;

/// Set only around eligible normal world surface admission.
pub var content_storage_scope = false;
const StorageKey = struct {
    width: u32,
    height: u32,
    levels: u32,
    fn eql(a: StorageKey, b: StorageKey) bool {
        return a.width == b.width and a.height == b.height and a.levels == b.levels;
    }
};
const Storage = struct { key: StorageKey, reservation: vk.ImageReservation };
const storage_budget: u64 = 4 * 1024 * 1024;
var storage_pool: [4]?Storage = @splat(null);
var storage_history: [8]?StorageKey = @splat(null);
var storage_history_cursor: usize = 0;
var storage_charge: u64 = 0;
var storage_requests: u64 = 0;
var storage_hits: u64 = 0;
var storage_prefills: u64 = 0;
var storage_failures: u64 = 0;

pub fn storageInfo() void {
    var unused: usize = 0;
    for (storage_pool) |entry| if (entry != null) {
        unused += 1;
    };
    const memory = vk.contentMemoryUsage();
    common.info("dk3 image storage: requests={d} hits={d} prefills={d} failures={d} unused={d} charge={d} memory_blocks={d} memory_bytes={d} memory_used={d}\n", .{ storage_requests, storage_hits, storage_prefills, storage_failures, unused, storage_charge, memory.blocks, memory.bytes, memory.used });
}

fn contentTexture(width: u32, height: u32, levels: u32) vk.Texture {
    const format = c.VK_FORMAT_R8G8B8A8_UNORM;
    const usage = c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    if (!content_storage_scope) return vk.createImage(width, height, levels, format, usage, c.VK_IMAGE_ASPECT_COLOR_BIT);
    const key: StorageKey = .{ .width = width, .height = height, .levels = levels };
    storage_requests += 1;
    var repeated = false;
    for (storage_history) |previous| if (previous) |value| {
        if (key.eql(value)) repeated = true;
    };
    storage_history[storage_history_cursor] = key;
    storage_history_cursor = (storage_history_cursor + 1) % storage_history.len;
    for (&storage_pool) |*entry| if (entry.*) |value| {
        if (!key.eql(value.key)) continue;
        entry.* = null;
        storage_charge -= value.reservation.charge;
        storage_hits += 1;
        return value.reservation.texture;
    };
    const texture = vk.createImage(width, height, levels, format, usage, c.VK_IMAGE_ASPECT_COLOR_BIT);
    if (repeated and width > 0 and height > 0 and width <= 512 and height <= 512 and storage_charge < storage_budget) {
        for (&storage_pool) |*entry| if (entry.* == null) {
            if (vk.tryReserveImage(width, height, levels, format, usage, c.VK_IMAGE_ASPECT_COLOR_BIT, storage_budget - storage_charge)) |reservation| {
                entry.* = .{ .key = key, .reservation = reservation };
                storage_charge += reservation.charge;
                storage_prefills += 1;
            } else storage_failures += 1;
            break;
        };
    }
    return texture;
}

pub var default_image: *Image = undefined;
pub var white: *Image = undefined;
pub var identity_light: *Image = undefined;
pub var scratch: [32]*Image = undefined;

var gamma_table: [256]u8 = undefined;
var mip_color_table: [256]u8 = undefined;
var gamma_identity = false;
var mip_color_identity = false;

const Loader = struct { ext: []const u8, load: *const fn ([*:0]const u8, *?[*]u8, *c_int, *c_int) callconv(.c) void };
/// Order of preference when several formats exist (tr_image.c `imageLoaders`).
pub const loaders = [_]Loader{
    .{ .ext = "tga", .load = cext.R_LoadTGA },
    .{ .ext = "jpg", .load = cext.R_LoadJPG },
    .{ .ext = "jpeg", .load = cext.R_LoadJPG },
    .{ .ext = "png", .load = cext.R_LoadPNG },
    .{ .ext = "pcx", .load = cext.R_LoadPCX },
    .{ .ext = "bmp", .load = cext.R_LoadBMP },
    .{ .ext = "pvr", .load = cext.R_LoadPVR },
};

/// `R_SetColorMappings` without hardware gamma: no overbright, software gamma tables.
pub fn setColorMappings() void {
    if (cvars.intensity.value <= 1) common.ri.Cvar_Set.?("r_intensity", "1");
    if (cvars.gamma.value < 0.5) common.ri.Cvar_Set.?("r_gamma", "0.5") else if (cvars.gamma.value > 3.0) common.ri.Cvar_Set.?("r_gamma", "3.0");
    // The remaster pipeline applies display gamma once, in the composite pass.
    const g = if (cvars.vkRemaster.integer != 0) 1.0 else cvars.gamma.value;
    setCpuColorMappings(g, cvars.intensity.value);
}

/// Initialize immutable CPU lookup tables before image workers are dispatched.
pub fn setCpuColorMappings(gamma: f32, intensity: f32) void {
    var intensity_table: [256]u8 = undefined;
    for (&gamma_table, 0..) |*entry, index| {
        const value: f32 = if (gamma == 1) @floatFromInt(index) else 255.0 * std.math.pow(f32, @as(f32, @floatFromInt(index)) / 255.0, 1.0 / gamma) + 0.5;
        entry.* = @intFromFloat(std.math.clamp(@floor(value), 0, 255));
    }
    for (&intensity_table, 0..) |*entry, index| {
        const value = @as(f32, @floatFromInt(index)) * intensity;
        entry.* = @intFromFloat(@min(@floor(value), 255));
    }
    gamma_identity = true;
    mip_color_identity = true;
    for (0..256) |index| {
        mip_color_table[index] = gamma_table[intensity_table[index]];
        gamma_identity = gamma_identity and gamma_table[index] == index;
        mip_color_identity = mip_color_identity and mip_color_table[index] == index;
    }
}

pub fn extension(name: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, name, '/') orelse 0;
    const dot = std.mem.lastIndexOfScalar(u8, name, '.') orelse return "";
    if (dot < slash) return "";
    return name[dot + 1 ..];
}

pub fn stripExtension(name: []const u8) []const u8 {
    const ext = extension(name);
    if (ext.len == 0) return name;
    return name[0 .. name.len - ext.len - 1];
}

const Pixels = struct {
    data: [*]const u8,
    allocation: ?[*]u8,
    width: u32,
    height: u32,
    fn deinit(self: Pixels) void {
        if (self.allocation) |owned| common.ri.Free.?(owned);
    }
};

fn tryLoader(loader: Loader, name: [*:0]const u8, allow_borrow: bool) ?Pixels {
    var pic: ?[*]u8 = null;
    var width: c_int = 0;
    var height: c_int = 0;
    if (allow_borrow and std.mem.eql(u8, loader.ext, "png")) {
        var view: ?[*]const u8 = null;
        if (cext.R_BorrowPreparedPNG(name, &view, &width, &height) != 0) {
            if (width <= 0 or height <= 0) return null;
            return .{ .data = view orelse return null, .allocation = null, .width = @intCast(width), .height = @intCast(height) };
        }
    }
    loader.load(name, &pic, &width, &height);
    const data = pic orelse return null;
    if (width <= 0 or height <= 0) {
        common.ri.Free.?(data);
        return null;
    }
    return .{ .data = data, .allocation = data, .width = @intCast(width), .height = @intCast(height) };
}

/// `R_LoadImage`: the named loader, then every other format in preference order.
fn loadPixels(name: []const u8, allow_borrow: bool) ?Pixels {
    var local_buffer: [c.MAX_QPATH]u8 = undefined;
    var local: []const u8 = name;
    const ext = extension(name);
    var original: ?usize = null;
    if (ext.len > 0) {
        for (loaders, 0..) |loader, index| {
            if (!std.ascii.eqlIgnoreCase(ext, loader.ext)) continue;
            if (tryLoader(loader, common.qpath(&local_buffer, name).ptr, allow_borrow)) |pixels| return pixels;
            original = index;
            local = stripExtension(name);
            break;
        }
    }
    for (loaders, 0..) |loader, index| {
        if (original == index) continue;
        var alternative: [c.MAX_QPATH + 8]u8 = undefined;
        const path = std.fmt.bufPrintZ(&alternative, "{s}.{s}", .{ local, loader.ext }) catch continue;
        if (tryLoader(loader, path.ptr, allow_borrow)) |pixels| {
            if (original != null) common.developer("WARNING: {s} not present, using {s} instead\n", .{ name, path });
            return pixels;
        }
    }
    return null;
}

/// `R_FindImageFile`: null when no file loads (callers choose the default image). During a
/// registration made in play (`defer_requests`) a PNG decodes in the background instead.
pub fn find(name: []const u8, flags: Flags) ?*Image {
    if (name.len == 0 or name.len >= c.MAX_QPATH) return null;
    if (!by_name.contains(name) and !defer_requests) if (findPrepared(name, flags)) |found| return found;
    if (defer_requests and !by_name.contains(name)) if (deferPng(name, flags)) |image| return image;
    if (by_name.get(name)) |existing| {
        if (!std.mem.eql(u8, name, "*white") and @as(u8, @bitCast(existing.flags)) != @as(u8, @bitCast(flags)))
            common.developer("WARNING: reused image {s} with mixed flags\n", .{name});
        return existing;
    }
    const started = common.milliseconds();
    // prepareLevels owns its copied levels before this synchronous call returns;
    // the selected batch stays alive throughout shader/model registration.
    const pixels = loadPixels(name, true) orelse return null;
    defer pixels.deinit();
    const decoded = common.milliseconds();
    const result = create(name, pixels.data[0 .. @as(usize, pixels.width) * pixels.height * 4], pixels.width, pixels.height, flags);
    const completed = common.milliseconds();
    if (completed - started >= 4)
        common.developer("dk3 image admission: name={s} size={d}x{d} read_decode_ms={d} prepare_upload_ms={d} borrowed_png={d} borrowed_level0={d}\n", .{ name, pixels.width, pixels.height, decoded - started, completed - decoded, @intFromBool(pixels.allocation == null), @intFromBool(flags.no_light_scale or identityColor(flags)) });
    return result;
}

fn mipLevel(source: []const u8, width: u32, height: u32, out: []u8) void {
    const w2 = @max(width >> 1, 1);
    const h2 = @max(height >> 1, 1);
    var y: u32 = 0;
    while (y < h2) : (y += 1) {
        const y0 = @min(y * 2, height - 1);
        const y1 = @min(y * 2 + 1, height - 1);
        var x: u32 = 0;
        // Four adjacent source pixels from each row produce two RGBA pixels.
        // Widen before summing (at most 1020), retaining the scalar filter's
        // exact truncation and independent alpha. Unaligned loads cover odd
        // row widths; small/tail columns retain the existing clamped path.
        while (x + 1 < w2) : (x += 2) {
            const top: @Vector(16, u8) = @bitCast(source[(y0 * width + x * 2) * 4 ..][0..16].*);
            const bottom: @Vector(16, u8) = @bitCast(source[(y1 * width + x * 2) * 4 ..][0..16].*);
            const vertical = @as(@Vector(16, u16), @intCast(top)) + @as(@Vector(16, u16), @intCast(bottom));
            const left = @shuffle(u16, vertical, undefined, @Vector(8, i32){ 0, 1, 2, 3, 8, 9, 10, 11 });
            const right = @shuffle(u16, vertical, undefined, @Vector(8, i32){ 4, 5, 6, 7, 12, 13, 14, 15 });
            const averaged: @Vector(8, u8) = @intCast((left + right) >> @as(@Vector(8, u4), @splat(2)));
            out[(y * w2 + x) * 4 ..][0..8].* = @bitCast(averaged);
        }
        while (x < w2) : (x += 1) {
            const x0 = @min(x * 2, width - 1);
            const x1 = @min(x * 2 + 1, width - 1);
            for (0..4) |channel| {
                const sum = @as(u32, source[(y0 * width + x0) * 4 + channel]) + source[(y0 * width + x1) * 4 + channel] +
                    source[(y1 * width + x0) * 4 + channel] + source[(y1 * width + x1) * 4 + channel];
                out[(y * w2 + x) * 4 + channel] = @intCast(sum >> 2);
            }
        }
    }
}

/// The CPU half of `R_CreateImage`: the mip chain, light scaling, mean colour and alpha test.
/// Touches no renderer state but the read-only gamma tables, so it runs on worker threads too.
pub const Levels = struct {
    levels: [16][]const u8 = undefined,
    owned: [16]?[]u8 = .{null} ** 16,
    count: usize = 0,
    /// Index of the first uploaded level (picmip and the device limit drop the largest).
    skip: usize = 0,
    upload_width: u32,
    upload_height: u32,
    average: [3]f32 = .{ 0.5, 0.5, 0.5 },
    has_alpha: bool = false,
    pub fn used(self: *const Levels) []const []const u8 {
        return self.levels[self.skip..self.count];
    }
    pub fn borrowedBase(self: *const Levels) bool {
        return self.count != 0 and self.owned[0] == null;
    }
    pub fn deinit(self: *Levels) void {
        for (self.owned[0..self.count]) |allocation| if (allocation) |level| std.heap.c_allocator.free(level);
        self.count = 0;
    }
};
fn identityColor(flags: Flags) bool {
    return if (flags.mipmap) mip_color_identity else gamma_identity;
}
pub fn prepareLevels(pixels: []const u8, width: u32, height: u32, flags: Flags, picmip: i32, limit: u32) !Levels {
    return prepareLevelsInternal(pixels, width, height, flags, picmip, limit, false);
}
/// Caller retains immutable source pixels until Levels.deinit. Only an unchanged
/// base can be borrowed; color mapping keeps the fully owned fallback. Used by
/// synchronous create, whose upload copies every level before returning.
pub fn prepareLevelsBorrowed(pixels: []const u8, width: u32, height: u32, flags: Flags, picmip: i32, limit: u32) !Levels {
    return prepareLevelsInternal(pixels, width, height, flags, picmip, limit, true);
}
fn prepareLevelsInternal(pixels: []const u8, width: u32, height: u32, flags: Flags, picmip: i32, limit: u32, allow_borrow: bool) !Levels {
    return prepareSource(pixels, width, height, flags, picmip, limit, allow_borrow, null);
}
pub fn prepareCached(cached: *const prepared_texture.Texture, flags: Flags, picmip: i32, limit: u32) !Levels {
    return prepareSource(cached.levels[0], cached.width, cached.height, flags, picmip, limit, true, cached);
}
fn prepareSource(pixels: []const u8, width: u32, height: u32, flags: Flags, picmip: i32, limit: u32, allow_borrow: bool, cached: ?*const prepared_texture.Texture) !Levels {
    const allocator = std.heap.c_allocator;
    var result: Levels = .{ .upload_width = width, .upload_height = height };
    errdefer result.deinit();
    const identity = identityColor(flags);
    if (allow_borrow and (flags.no_light_scale or identity)) {
        result.levels[0] = pixels;
    } else {
        const base = try allocator.dupe(u8, pixels);
        result.owned[0] = base;
        result.levels[0] = base;
    }
    result.count = 1;
    var w = width;
    var h = height;
    if (flags.mipmap) {
        while ((w > 1 or h > 1) and result.count < result.levels.len) {
            if (cached) |source| {
                if (flags.no_light_scale or identity) {
                    result.levels[result.count] = source.levels[result.count];
                } else {
                    const next = try allocator.dupe(u8, source.levels[result.count]);
                    result.levels[result.count] = next;
                    result.owned[result.count] = next;
                }
            } else {
                const next = try allocator.alloc(u8, @as(usize, @max(w >> 1, 1)) * @max(h >> 1, 1) * 4);
                mipLevel(result.levels[result.count - 1], w, h, next);
                result.levels[result.count] = next;
                result.owned[result.count] = next;
            }
            result.count += 1;
            w = @max(w >> 1, 1);
            h = @max(h >> 1, 1);
        }
    }
    var skip: usize = 0;
    if (flags.picmip and flags.mipmap and picmip > 0) skip = @min(@as(usize, @intCast(picmip)), result.count - 1);
    while (skip + 1 < result.count and ((width >> @intCast(skip)) > limit or (height >> @intCast(skip)) > limit)) skip += 1;
    result.skip = skip;
    result.upload_width = @max(width >> @intCast(skip), 1);
    result.upload_height = @max(height >> @intCast(skip), 1);
    setMetadata(pixels, &result);
    // Compose the byte lookups once at initialization. Identity mappings need
    // no pixel pass; all other mappings preserve the original integer results.
    const color_table = if (flags.mipmap) &mip_color_table else &gamma_table;
    if (!flags.no_light_scale and !identity) for (result.owned[result.skip..result.count]) |allocation| {
        const level = allocation.?;
        var index: usize = 0;
        while (index < level.len) : (index += 4) {
            for (0..3) |channel| {
                const value = level[index + channel];
                level[index + channel] = color_table[value];
            }
        }
    };
    return result;
}
fn setMetadata(pixels: []const u8, result: *Levels) void {
    {
        var sum: [3]f64 = .{ 0, 0, 0 };
        const step: usize = @max(pixels.len / 4 / 4096, 1);
        var samples: f64 = 0;
        var index: usize = 0;
        while (index < pixels.len / 4) : (index += step) {
            for (0..3) |channel| sum[channel] += @floatFromInt(pixels[index * 4 + channel]);
            samples += 1;
        }
        if (samples > 0) for (0..3) |channel| {
            result.average[channel] = @floatCast(sum[channel] / samples / 255.0);
        };
    }
    // Check complete RGBA blocks together. The alpha byte occupies the same
    // lane of every native-endian word; never read beyond a complete block.
    var alpha_index: usize = 0;
    const alpha_mask: @Vector(16, u32) = @splat(std.mem.nativeToLittle(u32, 0xff000000));
    while (alpha_index + 64 <= pixels.len) : (alpha_index += 64) {
        const rgba: @Vector(16, u32) = @bitCast(pixels[alpha_index..][0..64].*);
        if (@reduce(.Or, (rgba & alpha_mask) != alpha_mask)) {
            result.has_alpha = true;
            break;
        }
    }
    if (!result.has_alpha) while (alpha_index < pixels.len) : (alpha_index += 4) {
        if (pixels[alpha_index + 3] != 255) {
            result.has_alpha = true;
            break;
        }
    };
}
/// The GPU half: a new texture holding the prepared levels, bound to a fresh bindless slot.
fn commit(image: *Image, prepared: *const Levels) void {
    const used = prepared.used();
    image.upload_width = prepared.upload_width;
    image.upload_height = prepared.upload_height;
    image.average = prepared.average;
    image.has_alpha = prepared.has_alpha;
    image.texture = contentTexture(image.upload_width, image.upload_height, @intCast(used.len));
    vk.uploadTexture(&image.texture, used, true);
    vk.bindTexture(&image.texture, samplerFor(image.flags));
}
fn deviceLimit() u32 {
    return @intCast(@max(vk.s.properties.limits.maxImageDimension2D, 1));
}

/// `R_CreateImage`: registers `name` with RGBA8 `pixels` and uploads it.
pub fn create(name: []const u8, pixels: []const u8, width: u32, height: u32, flags: Flags) *Image {
    if (flags.mipmap and pixels.len >= 512 * 512 * 4 and cvars.vkGpuTexturePrep.integer != 0)
        if (createGpu(name, pixels, width, height, flags, null)) |image| return image;
    var prepared = prepareLevelsBorrowed(pixels, width, height, flags, cvars.picmip.integer, deviceLimit()) catch @panic("OOM");
    defer prepared.deinit();
    return registerPrepared(name, width, height, flags, &prepared);
}
fn registerPrepared(name: []const u8, width: u32, height: u32, flags: Flags, prepared: *const Levels) *Image {
    const image = registerImage(name, width, height, flags);
    commit(image, prepared);
    return image;
}
fn registerImage(name: []const u8, width: u32, height: u32, flags: Flags) *Image {
    const image = common.gpa.create(Image) catch @panic("OOM");
    image.* = .{
        .width = width,
        .height = height,
        .upload_width = width,
        .upload_height = height,
        .flags = flags,
        .texture = .{},
        .has_alpha = false,
    };
    _ = common.qpath(&image.name, name);
    // The registry owns the image before any GPU commands can reference it.
    images.append(common.gpa, image) catch @panic("OOM");
    by_name.put(common.gpa, image.nameSlice(), image) catch @panic("OOM");
    return image;
}

/// Generate raw mips first: mapping the source before filtering changes integer
/// truncation and is deliberately forbidden. Scratch and commands belong to
/// the current frame; submission orders preparation/copies before every draw.
fn createGpu(name: []const u8, pixels: []const u8, width: u32, height: u32, flags: Flags, existing: ?*Image) ?*Image {
    var offsets: [16]u64 = undefined;
    var widths: [16]u32 = undefined;
    var heights: [16]u32 = undefined;
    var count: usize = 0;
    var total: u64 = 0;
    var w = width;
    var h = height;
    while (count < offsets.len) {
        offsets[count] = total;
        widths[count] = w;
        heights[count] = h;
        total += @as(u64, w) * h * 4;
        count += 1;
        if (w == 1 and h == 1) break;
        w = @max(w >> 1, 1);
        h = @max(h >> 1, 1);
    }
    const space = vk.imageScratch(total + 1024) orelse return null;
    var skip: usize = if (flags.picmip and cvars.picmip.integer > 0) @min(@as(usize, @intCast(cvars.picmip.integer)), count - 1) else 0;
    while (skip + 1 < count and (widths[skip] > deviceLimit() or heights[skip] > deviceLimit())) skip += 1;
    var table: [256]u32 = undefined;
    for (&table, 0..) |*entry, i| entry.* = if (flags.no_light_scale) @intCast(i) else mip_color_table[i];
    vk.uploadBuffer(space.buffer, space.offset, pixels);
    vk.uploadBuffer(space.buffer, space.offset + total, std.mem.asBytes(&table));
    const cmd = vk.uploadCommands();
    const compute = c.VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;
    const shader_write = c.VK_ACCESS_2_SHADER_WRITE_BIT;
    const shader_read = c.VK_ACCESS_2_SHADER_READ_BIT;
    const Push = @import("post.zig").Push;
    for (1..count) |i| {
        vk.dispatch(cmd, "texture_prepare.comp", Push{
            .size = .{ widths[i], heights[i], widths[i - 1], heights[i - 1] },
            .buffer0 = space.address + offsets[i - 1],
            .buffer1 = space.address + offsets[i],
        }, widths[i], heights[i], 1, .{ 8, 8, 1 });
        vk.memoryBarrier(cmd, compute, shader_write, compute, shader_read);
    }
    // Every raw level has finished before mapping in place. Mapping earlier
    // would change later levels' filter rounding/color semantics.
    vk.memoryBarrier(cmd, compute, shader_write | shader_read, compute, shader_read | shader_write);
    const table_address = space.address + total;
    if (!flags.no_light_scale and !mip_color_identity) for (skip..count) |i| {
        vk.dispatch(cmd, "texture_prepare.comp", Push{
            .slots = .{ 1, 0, @truncate(table_address), @truncate(table_address >> 32) },
            .size = .{ widths[i], heights[i], 0, 0 },
            .buffer0 = space.address + offsets[i],
            .buffer1 = space.address + offsets[i],
        }, widths[i], heights[i], 1, .{ 8, 8, 1 });
    };
    vk.memoryBarrier(cmd, compute, shader_write, vk.stage_copy, vk.access_transfer_read);
    const image = existing orelse registerImage(name, width, height, flags);
    image.width = width;
    image.height = height;
    var metadata: Levels = .{ .upload_width = widths[skip], .upload_height = heights[skip] };
    setMetadata(pixels, &metadata);
    image.average = metadata.average;
    image.has_alpha = metadata.has_alpha;
    image.upload_width = widths[skip];
    image.upload_height = heights[skip];
    image.texture = contentTexture(image.upload_width, image.upload_height, @intCast(count - skip));
    vk.barrier(cmd, image.texture.image, c.VK_IMAGE_ASPECT_COLOR_BIT, c.VK_IMAGE_LAYOUT_UNDEFINED, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, vk.stage_all, 0, vk.stage_copy, vk.access_transfer_write);
    var regions: [16]c.VkBufferImageCopy = undefined;
    for (skip..count) |i| regions[i - skip] = std.mem.zeroInit(c.VkBufferImageCopy, .{
        .bufferOffset = space.offset + offsets[i],
        .imageSubresource = .{ .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT, .mipLevel = @as(u32, @intCast(i - skip)), .baseArrayLayer = 0, .layerCount = 1 },
        .imageExtent = .{ .width = widths[i], .height = heights[i], .depth = 1 },
    });
    vk.d.CmdCopyBufferToImage.?(cmd, space.buffer, image.texture.image, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, @intCast(count - skip), &regions);
    vk.barrier(cmd, image.texture.image, c.VK_IMAGE_ASPECT_COLOR_BIT, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, vk.stage_copy, vk.access_transfer_write, vk.stage_fragment | vk.stage_vertex, shader_read);
    vk.bindTexture(&image.texture, samplerFor(flags));
    return image;
}

fn resolvedPath(name: []const u8, buffer: *[c.MAX_QPATH + 8]u8) ?[:0]const u8 {
    const ext = extension(name);
    var local = name;
    var original: ?usize = null;
    for (loaders, 0..) |loader, i| if (std.ascii.eqlIgnoreCase(ext, loader.ext)) {
        const path = std.fmt.bufPrintZ(buffer, "{s}", .{name}) catch return null;
        if (common.fileExists(path.ptr)) return path;
        original = i;
        local = stripExtension(name);
        break;
    };
    for (loaders, 0..) |loader, i| {
        if (original == i) continue;
        const path = std.fmt.bufPrintZ(buffer, "{s}.{s}", .{ local, loader.ext }) catch continue;
        if (common.fileExists(path.ptr)) return path;
    }
    return null;
}
fn findPrepared(name: []const u8, flags: Flags) ?*Image {
    if (cvars.vkPreparedAssets.integer == 0) return null;
    var source_path: [c.MAX_QPATH + 8]u8 = undefined;
    const source_name = resolvedPath(name, &source_path) orelse return null;
    if (!std.ascii.eqlIgnoreCase(extension(source_name), "png")) return null;
    var cache_path: [64]u8 = undefined;
    const cache_name = prepared_texture.path(source_name, &cache_path) catch return null;
    if (!common.fileExists(cache_name.ptr)) return null;
    const bytes = common.readFile(cache_name.ptr) orelse return null;
    defer common.freeFile(bytes);
    const source = common.readFile(source_name.ptr) orelse return null;
    defer common.freeFile(source);
    const cached = prepared_texture.decode(bytes, source) catch |err| {
        common.developer("dk3 prepared texture fallback: name={s} reason={s}\n", .{ name, @errorName(err) });
        return null;
    };
    var levels = prepareCached(&cached, flags, cvars.picmip.integer, deviceLimit()) catch return null;
    defer levels.deinit();
    common.developer("dk3 prepared texture: name={s} bytes={d} levels={d}\n", .{ name, bytes.len, levels.used().len });
    return registerPrepared(name, cached.width, cached.height, flags, &levels);
}

// ---------------------------------------------------------------------------------------------
// Deferred images. Model and skin textures requested during play (a seamless region's characters
// admitted ahead of the player) would stall a frame for their PNG decode (200-300 ms at 4096^2)
// and mip chain. They register at once with a neutral placeholder; a background read and decode
// (the resident PNG batch), then a worker's mip chain, run off the frame, and the finished
// texture replaces the placeholder at a frame start, with bounded upload batches.

/// Set by the model registry around registrations made during play (main.zig opens it after
/// `EndRegistration`; later model/skin requests use deferred admission).
pub var defer_requests: bool = false;
const Deferred = struct {
    image: *Image,
    batch: ?*cext.ImageBatch,
    stage: enum { cache_start, cache_reading, decoding, waiting, mipping, gpu_ready } = .decoding,
    source_name: [c.MAX_QPATH]u8 = @splat(0),
    cache_name: [64]u8 = @splat(0),
    source_job: ?*c.struct_fsReadJob_s = null,
    cache_job: ?*c.struct_fsReadJob_s = null,
    source_bytes: []const u8 = &.{},
    cache_bytes: []const u8 = &.{},
    cached_attempt: bool = false,
    cache_failure: ?anyerror = null,
    pixels: ?Pixels = null,
    done: std.atomic.Value(bool) = .init(false),
    prepared: ?Levels = null,
    mip_nanoseconds: u64 = 0,
    owner_mip: bool = false,
    picmip: i32,
    limit: u32,
    fn work(self: *Deferred) void {
        const started = common.nanoseconds();
        defer {
            self.mip_nanoseconds = @intCast(@max(0, common.nanoseconds() - started));
            self.done.store(true, .release);
        }
        if (self.cached_attempt) {
            const cached = prepared_texture.decode(self.cache_bytes, self.source_bytes) catch |err| {
                self.cache_failure = err;
                return;
            };
            self.pixels = .{ .data = cached.levels[0].ptr, .allocation = null, .width = cached.width, .height = cached.height };
            self.prepared = prepareCached(&cached, self.image.flags, self.picmip, self.limit) catch null;
            return;
        }
        const pixels = self.pixels.?;
        self.prepared = prepareLevels(pixels.data[0 .. @as(usize, pixels.width) * pixels.height * 4], pixels.width, pixels.height, self.image.flags, self.picmip, self.limit) catch null;
    }
    fn run(raw: *anyopaque) !void {
        const self: *Deferred = @ptrCast(@alignCast(raw));
        self.work();
    }
    fn release(self: *Deferred) void {
        if (self.prepared) |*prepared| prepared.deinit();
        self.prepared = null;
        if (self.pixels) |pixels| pixels.deinit();
        self.pixels = null;
        cext.R_FreeImageBatch(self.batch);
        self.batch = null;
        self.clearReads();
    }
    fn clearReads(self: *Deferred) void {
        if (self.source_job) |job| common.ri.EndBackgroundRead.?(job);
        if (self.cache_job) |job| common.ri.EndBackgroundRead.?(job);
        if (self.source_job != null and self.cache_job != null) cached_reads -= 1;
        self.source_job = null;
        self.cache_job = null;
        self.source_bytes = &.{};
        self.cache_bytes = &.{};
    }
    fn fallback(self: *Deferred) bool {
        self.clearReads();
        if (self.pixels) |pixels| pixels.deinit();
        self.pixels = null;
        self.cached_attempt = false;
        self.done.store(false, .release);
        self.stage = .decoding;
        self.batch = cext.R_CreateImageBatch(1) orelse return false;
        return prepare(self.batch, self.image.nameSlice());
    }
};
var deferred: std.ArrayList(*Deferred) = .empty;
var deferred_failures: usize = 0;
var preparation_pool: ?*jobs.Pool = null;
var preparation_jobs: [4]jobs.Job = undefined;
var cached_reads: usize = 0;

fn submitPreparations() void {
    if (preparation_pool == null) preparation_pool = jobs.Pool.create(common.gpa, @min(4, jobs.Pool.defaultWorkers())) catch
        jobs.Pool.create(common.gpa, 0) catch @panic("OOM");
    const pool = preparation_pool.?;
    if (pool.active) return;
    var count: usize = 0;
    var bytes: usize = 0;
    for (deferred.items) |entry| {
        if (entry.stage != .waiting) continue;
        const charge = @as(usize, entry.pixels.?.width) * entry.pixels.?.height * 4;
        if (count != 0 and charge > 64 * 1024 * 1024 -| bytes) break;
        bytes += charge;
        entry.stage = .mipping;
        preparation_jobs[count] = .{ .run = Deferred.run, .context = entry };
        count += 1;
        if (count == preparation_jobs.len) break;
    }
    if (count != 0) pool.begin(preparation_jobs[0..count]) catch unreachable;
}

/// Owner-thread admission status, including decoding, mip preparation and commit.
pub fn pendingCount() usize {
    return deferred.items.len;
}
pub fn failedCount() usize {
    return deferred_failures;
}

/// Whether `name` resolves (as `loadPixels` resolves it) to a PNG file.
fn resolvesToPng(name: []const u8) bool {
    var buffer: [c.MAX_QPATH + 8]u8 = undefined;
    const ext = extension(name);
    var local: []const u8 = name;
    var original: ?usize = null;
    if (ext.len > 0) for (loaders, 0..) |loader, index| {
        if (!std.ascii.eqlIgnoreCase(ext, loader.ext)) continue;
        if (common.fileExists(common.qpath(buffer[0..c.MAX_QPATH], name).ptr)) return std.ascii.eqlIgnoreCase(ext, "png");
        original = index;
        local = stripExtension(name);
        break;
    };
    for (loaders, 0..) |loader, index| {
        if (original == index) continue;
        const path = std.fmt.bufPrintZ(&buffer, "{s}.{s}", .{ local, loader.ext }) catch continue;
        if (common.fileExists(path.ptr)) return std.mem.eql(u8, loader.ext, "png");
    }
    return false;
}
fn deferPng(name: []const u8, flags: Flags) ?*Image {
    if (!resolvesToPng(name)) return null;
    var source_path: [c.MAX_QPATH + 8]u8 = undefined;
    var cache_path: [64]u8 = @splat(0);
    const source = resolvedPath(name, &source_path);
    const use_cache = blk: {
        if (cvars.vkPreparedAssets.integer == 0 or source == null) break :blk false;
        const path = prepared_texture.path(source.?, &cache_path) catch break :blk false;
        // Small skins already decode in parallel and share an inline/upload
        // frame. Routing them through two cache-read slots serializes cheap
        // work behind large chains and adds frame hops. Reserve this path for
        // chains large enough to avoid material conversion work. This is a
        // metadata-only length query; source fallback and upload budgets stay
        // identical. Synchronous registrations may still use every valid cache.
        break :blk common.ri.FS_ReadFile.?(path.ptr, null) > 2 * 1024 * 1024;
    };
    const batch: ?*cext.ImageBatch = if (use_cache) null else (cext.R_CreateImageBatch(1) orelse return null);
    if (!use_cache and !prepare(batch, name)) {
        cext.R_FreeImageBatch(batch);
        return null;
    }
    var grey: [4 * 4 * 4]u8 = undefined;
    @memset(&grey, 128);
    const image = create(name, &grey, 4, 4, flags);
    const entry = common.gpa.create(Deferred) catch @panic("OOM");
    entry.* = .{ .image = image, .batch = batch, .picmip = cvars.picmip.integer, .limit = deviceLimit() };
    if (use_cache) {
        _ = common.qpath(&entry.source_name, source.?);
        entry.cache_name = cache_path;
        entry.stage = .cache_start;
    }
    deferred.append(common.gpa, entry) catch @panic("OOM");
    return image;
}

/// Advances deferred images; called once per frame before drawing.
pub fn pollDeferred() void {
    if (preparation_pool) |pool| _ = pool.poll() catch unreachable;
    // Small skins share an upload frame rather than waiting one frame each.
    // A single oversized texture may progress, retaining the prior large-image
    // behavior. Bound both bytes and API work for mixed-size queues.
    const upload_budget: usize = 4 * 1024 * 1024;
    const image_budget: usize = 8;
    var committed_bytes: usize = 0;
    var committed_images: usize = 0;
    // A <=256-square RGBA mip chain is small enough to finish in this frame.
    // Bound owner work separately from uploads: at most 2 MiB source per frame.
    // Large images keep their worker and cancellation/join ownership.
    const inline_image_bytes: usize = 256 * 256 * 4;
    const inline_frame_bytes: usize = 2 * 1024 * 1024;
    var inline_bytes: usize = 0;
    var index: usize = 0;
    while (index < deferred.items.len) {
        const entry = deferred.items[index];
        switch (entry.stage) {
            .cache_start => {
                // At most two read pairs: <=320 MiB encoded input buffers.
                // Hashing, validation and mip/color preparation run on workers.
                if (cached_reads >= 2) {
                    index += 1;
                    continue;
                }
                entry.source_job = common.ri.BeginBackgroundRead.?(&entry.source_name, 64 * 1024 * 1024);
                entry.cache_job = common.ri.BeginBackgroundRead.?(&entry.cache_name, 96 * 1024 * 1024);
                if (entry.source_job == null or entry.cache_job == null) {
                    if (!entry.fallback()) {
                        deferred_failures += 1;
                        drop(index);
                    }
                    continue;
                }
                cached_reads += 1;
                entry.stage = .cache_reading;
                index += 1;
            },
            .cache_reading => {
                var source_ptr: ?*const anyopaque = null;
                var cache_ptr: ?*const anyopaque = null;
                var source_length: c_int = 0;
                var cache_length: c_int = 0;
                const source_ready = common.ri.PollBackgroundRead.?(entry.source_job, &source_ptr, &source_length);
                const cache_ready = common.ri.PollBackgroundRead.?(entry.cache_job, &cache_ptr, &cache_length);
                if (source_ready == 0 or cache_ready == 0) {
                    index += 1;
                    continue;
                }
                if (source_ready != 1 or cache_ready != 1 or source_ptr == null or cache_ptr == null or cache_length < 64) {
                    if (!entry.fallback()) {
                        deferred_failures += 1;
                        drop(index);
                    }
                    continue;
                }
                entry.source_bytes = @as([*]const u8, @ptrCast(source_ptr.?))[0..@intCast(source_length)];
                entry.cache_bytes = @as([*]const u8, @ptrCast(cache_ptr.?))[0..@intCast(cache_length)];
                const width = std.mem.readInt(u32, entry.cache_bytes[8..12], .little);
                const height = std.mem.readInt(u32, entry.cache_bytes[12..16], .little);
                if (width == 0 or height == 0 or width > 16384 or height > 16384) {
                    if (!entry.fallback()) {
                        deferred_failures += 1;
                        drop(index);
                    }
                    continue;
                }
                // No pixel is read before the worker validates the package.
                entry.pixels = .{ .data = undefined, .allocation = null, .width = width, .height = height };
                entry.cached_attempt = true;
                entry.stage = .waiting;
                index += 1;
            },
            .decoding => {
                const ready = cext.R_PollImageBatch(entry.batch);
                if (ready == 0) {
                    index += 1;
                    continue;
                }
                if (ready > 0) {
                    // Decoded on the batch's worker: taking the pixels is a copy, not a decode.
                    cext.R_SelectImageBatch(entry.batch);
                    // The batch is freed before the mip worker runs, so this
                    // asynchronous path must retain its independent owned copy.
                    entry.pixels = loadPixels(entry.image.nameSlice(), false);
                    cext.R_SelectImageBatch(null);
                }
                cext.R_FreeImageBatch(entry.batch);
                entry.batch = null;
                if (entry.pixels == null) {
                    deferred_failures += 1;
                    common.warn("Deferred image {s} did not load; keeping its placeholder\n", .{entry.image.nameSlice()});
                    drop(index);
                    continue;
                }
                entry.stage = .waiting;
                const pixel_bytes = @as(usize, entry.pixels.?.width) * entry.pixels.?.height * 4;
                if (entry.image.flags.mipmap and pixel_bytes >= 512 * 512 * 4 and cvars.vkGpuTexturePrep.integer != 0) {
                    entry.stage = .gpu_ready;
                    continue;
                }
                if (pixel_bytes <= inline_image_bytes and pixel_bytes <= inline_frame_bytes - inline_bytes) {
                    inline_bytes += pixel_bytes;
                    entry.owner_mip = true;
                    entry.stage = .mipping;
                    entry.work();
                    // Revisit this entry immediately so the existing upload
                    // budget can admit it without another frame/worker hop.
                    continue;
                }
                index += 1;
            },
            .waiting => index += 1,
            .gpu_ready => {
                const pixels = entry.pixels.?;
                const charge = gpuUploadBytes(pixels.width, pixels.height, entry.image.flags, entry.picmip, entry.limit);
                if (committed_images != 0 and (committed_images >= image_budget or committed_bytes >= upload_budget or charge > upload_budget - committed_bytes)) {
                    index += 1;
                    continue;
                }
                const prior = entry.image.texture;
                if (createGpu(entry.image.nameSlice(), pixels.data[0 .. @as(usize, pixels.width) * pixels.height * 4], pixels.width, pixels.height, entry.image.flags, entry.image) == null) {
                    entry.stage = .waiting;
                    index += 1;
                    continue;
                }
                replaced.append(common.gpa, prior) catch @panic("OOM");
                committed_bytes += charge;
                committed_images += 1;
                common.developer("dk3 deferred GPU image: name={s} bytes={d}\n", .{ entry.image.nameSlice(), charge });
                drop(index);
            },
            .mipping => {
                if ((preparation_pool != null and preparation_pool.?.active) or !entry.done.load(.acquire)) {
                    index += 1;
                    continue;
                }
                if (entry.cached_attempt and entry.prepared == null) {
                    common.developer("dk3 prepared texture fallback: name={s} reason={s}\n", .{ entry.image.nameSlice(), if (entry.cache_failure) |err| @errorName(err) else "preparation" });
                    if (!entry.fallback()) {
                        deferred_failures += 1;
                        drop(index);
                    }
                    continue;
                }
                var upload_bytes: usize = 0;
                if (entry.prepared) |*prepared| for (prepared.used()) |level| {
                    upload_bytes += level.len;
                };
                if (entry.prepared != null and committed_images != 0 and
                    (committed_images >= image_budget or committed_bytes >= upload_budget or upload_bytes > upload_budget - committed_bytes))
                {
                    index += 1;
                    continue;
                }
                if (entry.prepared) |*prepared| {
                    const image = entry.image;
                    // A frame in flight may still sample the placeholder; it is released at shutdown.
                    replaced.append(common.gpa, image.texture) catch @panic("OOM");
                    image.width = entry.pixels.?.width;
                    image.height = entry.pixels.?.height;
                    const started = common.milliseconds();
                    commit(image, prepared);
                    committed_bytes += upload_bytes;
                    committed_images += 1;
                    common.developer("dk3 deferred image: name={s} size={d}x{d} upload_bytes={d} commit_ms={d} frame_images={d} frame_bytes={d} mip_us={d} owner_mip={d}\n", .{ image.nameSlice(), image.width, image.height, upload_bytes, common.milliseconds() - started, committed_images, committed_bytes, entry.mip_nanoseconds / 1000, @intFromBool(entry.owner_mip) });
                } else {
                    deferred_failures += 1;
                    common.warn("Deferred image {s} mip preparation failed; keeping its placeholder\n", .{entry.image.nameSlice()});
                }
                drop(index);
            },
        }
    }
    if (deferred.items.len != 0) submitPreparations();
}
fn drop(index: usize) void {
    const entry = deferred.orderedRemove(index);
    entry.release();
    common.gpa.destroy(entry);
}

fn samplerFor(flags: Flags) vk.SamplerKind {
    if (flags.nearest) return .nearest_clamp;
    if (flags.mipmap) return if (flags.clamp) .clamp_mip else .repeat_mip;
    return if (flags.clamp) .clamp else .repeat;
}
fn gpuUploadBytes(width: u32, height: u32, flags: Flags, picmip: i32, limit: u32) usize {
    var w = width;
    var h = height;
    var skip: u32 = if (flags.picmip) @intCast(@max(picmip, 0)) else 0;
    while ((w > 1 or h > 1) and (skip != 0 or w > limit or h > limit)) {
        w = @max(w >> 1, 1);
        h = @max(h >> 1, 1);
        skip -|= 1;
    }
    var bytes: usize = 0;
    while (true) {
        bytes += @as(usize, w) * h * 4;
        if (w == 1 and h == 1) return bytes;
        w = @max(w >> 1, 1);
        h = @max(h >> 1, 1);
    }
}

/// Replaces level 0 of a non-mipmapped image, recreating it when the size changes.
pub fn replace(image: *Image, pixels: []const u8, width: u32, height: u32) void {
    if (width != image.upload_width or height != image.upload_height) {
        // The old texture may still be read by a frame in flight; it is released at Shutdown.
        replaced.append(common.gpa, image.texture) catch @panic("OOM");
        image.texture = vk.createImage(width, height, 1, c.VK_FORMAT_R8G8B8A8_UNORM, c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT, c.VK_IMAGE_ASPECT_COLOR_BIT);
        image.width = width;
        image.height = height;
        image.upload_width = width;
        image.upload_height = height;
        const levels = [_][]const u8{pixels};
        vk.uploadTexture(&image.texture, &levels, true);
        vk.bindTexture(&image.texture, samplerFor(image.flags));
        return;
    }
    vk.uploadRegion(&image.texture, 0, 0, width, height, pixels);
}

/// Unpublished raw storage: no GPU commands or descriptors refer to it yet.
/// The owner must either finish it once or discard it before releasing its state.
pub const RawReservation = struct {
    image: *Image,

    pub fn finish(self: RawReservation, texels: []const u8) *Image {
        const image = self.image;
        // Transfer lifetime ownership before recording any GPU references.
        images.append(common.gpa, image) catch @panic("OOM");
        by_name.put(common.gpa, image.nameSlice(), image) catch @panic("OOM");
        const levels = [_][]const u8{texels};
        vk.uploadTexture(&image.texture, &levels, true);
        vk.bindTexture(&image.texture, samplerFor(image.flags));
        return image;
    }

    pub fn discard(self: RawReservation) void {
        vk.destroyImage(&self.image.texture);
        common.gpa.destroy(self.image);
    }
};

pub fn reserveRaw(name: []const u8, width: u32, height: u32, format: c.VkFormat, flags: Flags) RawReservation {
    const image = common.gpa.create(Image) catch @panic("OOM");
    image.* = .{ .width = width, .height = height, .upload_width = width, .upload_height = height, .flags = flags, .texture = .{}, .has_alpha = false };
    _ = common.qpath(&image.name, name);
    image.texture = vk.createImage(width, height, 1, format, c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT, c.VK_IMAGE_ASPECT_COLOR_BIT);
    return .{ .image = image };
}

/// A non-mipmapped image of another format from raw texels (float lightmaps).
pub fn createRaw(name: []const u8, texels: []const u8, width: u32, height: u32, format: c.VkFormat, flags: Flags) *Image {
    return reserveRaw(name, width, height, format, flags).finish(texels);
}

/// A keyword starts or ends one of the letter runs of the file name (materialgen.py `has`):
/// `swamp03` and `wtrfall` match, `swtrunk` is not water and `seat` is not sea.
fn contains(name: []const u8, words: []const []const u8) bool {
    const base = if (std.mem.lastIndexOfScalar(u8, name, '/')) |slash| name[slash + 1 ..] else name;
    var tokens = std.mem.tokenizeAny(u8, base, "0123456789_-.# ");
    while (tokens.next()) |token| for (words) |word| {
        // Three-letter keywords only as whole runs (`seat` is not sea).
        if (std.ascii.eqlIgnoreCase(token, word)) return true;
        if (word.len > 3 and (std.ascii.startsWithIgnoreCase(token, word) or std.ascii.endsWithIgnoreCase(token, word))) return true;
    };
    return false;
}

/// Defaults from the texture name; the same rules seed dkq3/tools/materialgen.py.
fn guessMaterial(name: []const u8) Material {
    var m: Material = .{};
    // Model skins (characters, weapons, items) carry painted shading: a height derived from
    // their luminance carves folds into faces and cloth, and their highlights are painted
    // too, so they get no procedural bump and no specular (the original lit them diffusely).
    if (!std.ascii.startsWithIgnoreCase(name, "textures/")) {
        m.bump = 0;
        m.specular = 0;
    }
    if (contains(name, &.{ "metal", "steel", "grate", "pipe", "chrome", "iron", "rust", "panel", "vent", "tech", "door", "plate" })) {
        m.metalness = 0.55;
        m.roughness = 0.45;
    }
    if (contains(name, &.{ "rock", "stone", "brick", "dirt", "mud", "sand", "moss", "bark", "wood", "ground", "grass" })) {
        m.roughness = 0.9;
        m.bump = 0.9;
    }
    if (contains(name, &.{ "glass", "window", "ice", "marble", "tile", "floor" })) m.roughness = 0.3;
    if (contains(name, &.{ "light", "lamp", "glow", "neon", "fire", "flame", "torch", "lite" })) m.emissive = 1.5;
    if (contains(name, &.{ "water", "swamp", "pool", "wave", "river", "sea", "lake" })) m.liquid = .water;
    if (contains(name, &.{ "slime", "sludge", "acid", "toxic", "goo" })) m.liquid = .slime;
    if (contains(name, &.{ "lava", "magma" })) m.liquid = .lava;
    if (m.liquid != .none) {
        m.roughness = 0.06;
        m.bump = 0;
        if (m.liquid == .lava) m.emissive = 2.5;
    }
    return m;
}

fn parseMaterial(text: []const u8, m: *Material) void {
    var lines = std.mem.tokenizeAny(u8, text, "\r\n");
    while (lines.next()) |line| {
        var fields = std.mem.tokenizeAny(u8, line, " \t");
        const key = fields.next() orelse continue;
        const value = fields.next() orelse continue;
        if (key[0] == '#' or key[0] == '/') continue;
        const number = std.fmt.parseFloat(f32, value) catch 0;
        if (std.ascii.eqlIgnoreCase(key, "roughness")) m.roughness = number else if (std.ascii.eqlIgnoreCase(key, "metalness")) m.metalness = number else if (std.ascii.eqlIgnoreCase(key, "bump")) m.bump = number else if (std.ascii.eqlIgnoreCase(key, "emissive")) m.emissive = number else if (std.ascii.eqlIgnoreCase(key, "specular")) m.specular = number else if (std.ascii.eqlIgnoreCase(key, "liquid")) {
            m.liquid = if (std.ascii.eqlIgnoreCase(value, "water")) .water else if (std.ascii.eqlIgnoreCase(value, "slime")) .slime else if (std.ascii.eqlIgnoreCase(value, "lava")) .lava else .none;
        }
    }
}

/// The image's remaster material, resolved on first use.
pub fn material(image: *Image) *const Material {
    if (image.material_ready) return &image.material;
    image.material_ready = true;
    const name = image.nameSlice();
    if (name.len == 0 or name[0] == '*') return &image.material;
    const base = stripExtension(name);
    image.material = guessMaterial(base);
    var path: [c.MAX_QPATH + 8]u8 = undefined;
    if (std.fmt.bufPrintZ(&path, "{s}.mat", .{base})) |file| {
        if (common.readFile(file.ptr)) |bytes| {
            defer common.freeFile(bytes);
            parseMaterial(bytes, &image.material);
        }
    } else |_| {}
    const map_flags: Flags = .{ .mipmap = image.flags.mipmap, .picmip = image.flags.picmip, .clamp = image.flags.clamp, .no_light_scale = true };
    if (std.fmt.bufPrint(&path, "{s}_n", .{base})) |normal| image.material.normal = find(normal, map_flags) else |_| {}
    if (std.fmt.bufPrint(&path, "{s}_s", .{base})) |spec| image.material.spec = find(spec, map_flags) else |_| {}
    return &image.material;
}

/// Textures replaced by `replace`, destroyed with the registry.
var replaced: std.ArrayList(vk.Texture) = .empty;

pub fn createBuiltins() void {
    var data: [16 * 16 * 4]u8 = undefined;
    @memset(&data, 32);
    for (0..16) |x| {
        for ([_]usize{ x, x * 16, 15 * 16 + x, x * 16 + 15 }) |pixel| @memset(data[pixel * 4 .. pixel * 4 + 4], 255);
    }
    default_image = create("*default", &data, 16, 16, .{ .mipmap = true });
    @memset(&data, 255);
    white = create("*white", data[0 .. 8 * 8 * 4], 8, 8, .{});
    identity_light = create("*identityLight", data[0 .. 8 * 8 * 4], 8, 8, .{});
    for (&scratch, 0..) |*entry, index| {
        var name: [16]u8 = undefined;
        entry.* = create(std.fmt.bufPrint(&name, "*scratch{d}", .{index}) catch unreachable, &data, 16, 16, .{ .picmip = true, .clamp = true });
    }
}

/// Destroys every content image; the caller releases their memory blocks.
pub fn shutdown() void {
    if (preparation_pool) |pool| {
        pool.finish() catch unreachable;
        pool.destroy();
        preparation_pool = null;
    }
    for (deferred.items) |entry| {
        entry.release();
        common.gpa.destroy(entry);
    }
    deferred.clearAndFree(common.gpa);
    std.debug.assert(cached_reads == 0);
    deferred_failures = 0;
    var unused_storage: usize = 0;
    for (&storage_pool) |*entry| if (entry.*) |*value| {
        vk.destroyImage(&value.reservation.texture);
        entry.* = null;
        unused_storage += 1;
    };
    if (unused_storage != 0) common.developer("dk3 image storage cleanup: unused={d} charge={d}\n", .{ unused_storage, storage_charge });
    storage_charge = 0;
    storage_history = @splat(null);
    storage_history_cursor = 0;
    storage_requests = 0;
    storage_hits = 0;
    storage_prefills = 0;
    storage_failures = 0;
    content_storage_scope = false;
    for (images.items) |image| {
        vk.destroyImage(&image.texture);
        common.gpa.destroy(image);
    }
    for (replaced.items) |*texture| vk.destroyImage(texture);
    replaced.clearAndFree(common.gpa);
    images.clearAndFree(common.gpa);
    by_name.clearAndFree(common.gpa);
}

pub fn list() void {
    var bytes: u64 = 0;
    for (images.items) |image| {
        bytes += @as(u64, image.upload_width) * image.upload_height * 4;
        common.info("{d:5} {d:5} {d:2} {s}\n", .{ image.upload_width, image.upload_height, image.texture.levels, image.nameSlice() });
    }
    common.info(" ---------\n {d} total images, {d} kB\n", .{ images.items.len, bytes / 1024 });
}

// ---------------------------------------------------------------------------------------------
// Resident preparation: `R_PrepareImage` (dk3_image_prefetch.inc). Only queues PNG decodes; the
// material compiler still creates images through `find`.

pub fn prepare(batch: ?*cext.ImageBatch, name: []const u8) bool {
    if (name.len == 0 or name[0] == '$' or name[0] == '*' or name.len >= c.MAX_QPATH) return true;
    if (by_name.contains(name)) return true;
    if (!defer_requests and cvars.vkPreparedAssets.integer != 0) {
        var source_path: [c.MAX_QPATH + 8]u8 = undefined;
        if (resolvedPath(name, &source_path)) |source_name| {
            var cache_path: [64]u8 = undefined;
            if (prepared_texture.path(source_name, &cache_path)) |cache_name| {
                // A stale package takes the normal synchronous decoder fallback
                // in findPrepared; it never substitutes mismatched pixels.
                if (common.fileExists(cache_name.ptr)) return true;
            } else |_| {}
        }
    }
    var buffer: [c.MAX_QPATH]u8 = undefined;
    var local: []const u8 = name;
    const ext = extension(name);
    var original: ?usize = null;
    if (ext.len > 0) {
        for (loaders, 0..) |loader, index| {
            if (!std.ascii.eqlIgnoreCase(ext, loader.ext)) continue;
            const path = common.qpath(&buffer, name);
            if (common.fileExists(path.ptr)) return if (std.ascii.eqlIgnoreCase(ext, "png")) cext.R_QueuePNG(batch, path.ptr) != 0 else true;
            original = index;
            local = stripExtension(name);
            break;
        }
    }
    for (loaders, 0..) |loader, index| {
        if (original == index) continue;
        var candidate: [c.MAX_QPATH + 8]u8 = undefined;
        const path = std.fmt.bufPrintZ(&candidate, "{s}.{s}", .{ local, loader.ext }) catch continue;
        if (common.fileExists(path.ptr)) return if (std.mem.eql(u8, loader.ext, "png")) cext.R_QueuePNG(batch, path.ptr) != 0 else true;
    }
    return true;
}
