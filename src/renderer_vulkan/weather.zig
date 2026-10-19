// SPDX-License-Identifier: GPL-2.0-or-later
//! Remaster GPU weather. The client hands over each visible authored rain or snow volume
//! (`AddDk3WeatherToScene`); instead of finite CPU particles, the stage vertex shader derives
//! every drop, flake and splash procedurally from its index, the volume and the scene time
//! (mesh kind 3, common.glsl `WeatherParams`). Volumes are also published to the view so
//! surfaces under rain get wet and puddled, and surfaces under snow get covered.
const std = @import("std");
const c = @import("c.zig").c;
const common = @import("common.zig");
const cvars = @import("cvars.zig");
const vk = @import("vk.zig");
const window = @import("window.zig");
const shader_mod = @import("shader.zig");
const image = @import("image.zig");
const world = @import("world.zig");

pub const Kind = enum(u32) { rain = 0, snow = 1 };

pub const Volume = struct {
    kind: Kind,
    flags: u32,
    mins: [3]f32,
    maxs: [3]f32,
    id: i32,
    registration: u32,
};

/// Mirrors common.glsl `WeatherParams`.
const Params = extern struct {
    mins: [4]f32, // w = kind
    maxs: [4]f32, // w = time in seconds
    velocity: [4]f32, // w = seed
    eye: [4]f32, // w = mode (0 drops or flakes, 1 splashes)
    shape: [4]f32, // exposure (s), world size of a pixel per unit distance, base alpha, count
    tiles: [4]f32, // first world tile x, y, tiles per row, particles per tile
    grid0: [4]f32 = .{ 0, 0, 0, 0 }, // light grid origin, w = colour volume slot + 1
    grid1: [4]f32 = .{ 0, 0, 0, 0 }, // light grid scale, w = direction volume slot + 1
    sky: [4]f32 = .{ 0, 0, 0, 1 }, // sky radiance (linear), w = intensity
};

/// Camera exposure that sets streak length (speed x exposure, about 5-10 in for rain).
pub const exposure_seconds: f32 = 1.0 / 30.0;

/// What the drops need from the view: eye, time, the size of a pixel, light grid and sky.
pub const Lighting = struct {
    eye: [3]f32,
    time: f32,
    pixel_per_unit: f32,
    grid: ?struct { origin: [4]f32, scale: [4]f32, color_slot: u32, slot: u32 },
    sky: [3]f32,
};

/// Particles live in world-anchored square tiles so they stay put while the eye moves.
pub const tile_size: f32 = 512;

pub const max_view_boxes = 8;

var volumes: std.ArrayList(Volume) = .empty;
var first_volume: usize = 0;

var drop_shader: shader_mod.Shader = .{ .sort = shader_mod.Sort.blend0 };
var splash_shader: shader_mod.Shader = .{ .sort = shader_mod.Sort.blend0 };
var shaders_ready = false;

pub fn beginFrame() void {
    volumes.clearRetainingCapacity();
    first_volume = 0;
}

pub fn clearScene() void {
    first_volume = volumes.items.len;
}

pub fn shutdown() void {
    volumes.clearAndFree(common.gpa);
    first_volume = 0;
    shaders_ready = false;
}

fn finite(v: [3]f32) bool {
    for (v) |x| if (!std.math.isFinite(x) or @abs(x) > 1000000) return false;
    return true;
}

/// `AddDk3WeatherToScene`: true when the volume will be drawn here.
pub fn add(kind: c_int, flags: c_int, mins: *const [3]f32, maxs: *const [3]f32, id: c_int) bool {
    if (!window.remaster or cvars.vkWeather.integer == 0) return false;
    if (kind != 0 and kind != 1) return false;
    if (!finite(mins.*) or !finite(maxs.*)) return false;
    for (0..2) |axis| if (maxs[axis] - mins[axis] < 1) return false;
    var top = maxs.*;
    // Snow volumes may be authored flat; the CPU path gives them ten units of height.
    if (kind == 1 and top[2] - mins[2] < 10) top[2] = mins[2] + 10;
    if (top[2] - mins[2] < 1) return false;
    volumes.append(common.gpa, .{
        .kind = @enumFromInt(@as(u32, @intCast(kind))),
        .flags = @bitCast(flags),
        .mins = mins.*,
        .maxs = top,
        .id = id,
        .registration = world.registration(),
    }) catch return false;
    return true;
}

pub fn sceneVolumes() []const Volume {
    return volumes.items[first_volume..];
}

/// Fall velocity of the original weather (domain/weather.zig `velocity`), without the per
/// particle random part.
fn velocity(kind: Kind, flags: u32) [3]f32 {
    if (kind == .snow) return .{ 0, 0, -55 };
    const x: f32 = if (flags & 3 == 0 and flags & 4 != 0) 300 else if (flags & 7 == 0 and flags & 8 != 0) -300 else 0;
    const y: f32 = if (flags & 1 != 0) 300 else if (flags & 2 != 0) -300 else 0;
    return .{ x, y, -400 };
}

fn ensureShaders() void {
    if (shaders_ready) return;
    var stage: shader_mod.Stage = .{
        .active = true,
        .rgb_gen = .vertex,
        .alpha_gen = .vertex,
        .blended = true,
        .src = shader_mod.Blend.src_alpha,
        .dst = shader_mod.Blend.one_minus_src_alpha,
        .depth_write = false,
    };
    stage.bundles[0].images[0] = image.white;
    stage.bundles[0].num_images = 1;
    stage.bundles[0].tc_gen = .texture;
    drop_shader = .{ .sort = shader_mod.Sort.blend0 };
    drop_shader.stages[0] = stage;
    drop_shader.num_stages = 1;
    drop_shader.cull = .two_sided;
    splash_shader = drop_shader;
    shaders_ready = true;
}

pub const Draw = struct { shader: *shader_mod.Shader, params: u64, count: u32 };

/// Particle draws for one volume (drops or flakes, and rain splashes).
pub fn draws(volume: Volume, lighting: Lighting, out: *[3]?Draw) void {
    const eye = lighting.eye;
    const time = lighting.time;
    out.* = .{ null, null, null };
    ensureShaders();
    // Nearest point of the volume; distant volumes are skipped.
    var nearest: f32 = 0;
    for (0..3) |axis| {
        const d = @max(@max(volume.mins[axis] - eye[axis], eye[axis] - volume.maxs[axis]), 0);
        nearest += d * d;
    }
    // Individual drops only near the eye; farther rain is fog in the froxel volume.
    var reach: f32 = if (volume.kind == .rain) 800 else 2048;
    if (nearest > reach * reach) return;
    // Density: the original capacity (rain 1% of the area, snow one per 64x64), scaled by
    // r_vkWeatherDensity, over the tiles of the volume near the eye.
    const density = @max(cvars.vkWeatherDensity.value, 0);
    const per_tile_f: f32 = (if (volume.kind == .rain) tile_size * tile_size * 0.035 else tile_size * tile_size / 4096.0 * 3) * density;
    const per_tile: u32 = @intFromFloat(@min(per_tile_f, 16384));
    if (per_tile == 0) return;
    const cap: u32 = if (volume.kind == .rain) 262144 else 32768;
    var first_tile: [2]f32 = undefined;
    var tiles: [2]u32 = undefined;
    while (true) {
        for (0..2) |axis| {
            const lo = @max(volume.mins[axis], eye[axis] - reach);
            const hi = @min(volume.maxs[axis], eye[axis] + reach);
            first_tile[axis] = @floor(lo / tile_size);
            tiles[axis] = @intFromFloat(@max(@floor(hi / tile_size) - first_tile[axis] + 1, 1));
        }
        if (tiles[0] * tiles[1] * per_tile <= cap or reach <= tile_size) break;
        reach *= 0.75;
    }
    const count = @min(tiles[0] * tiles[1] * per_tile, cap);
    const v = velocity(volume.kind, volume.flags);
    const seed: f32 = @floatFromInt(@as(u32, @bitCast(volume.id)) % 65521);
    var grid0: [4]f32 = .{ 0, 0, 0, 0 };
    var grid1: [4]f32 = .{ 0, 0, 0, 0 };
    if (lighting.grid) |g| {
        grid0 = .{ g.origin[0], g.origin[1], g.origin[2], @floatFromInt(g.color_slot + 1) };
        grid1 = .{ g.scale[0], g.scale[1], g.scale[2], @floatFromInt(g.slot + 1) };
    }
    const sky: [4]f32 = .{ lighting.sky[0], lighting.sky[1], lighting.sky[2], density };
    const rain_shape: [4]f32 = .{ exposure_seconds, lighting.pixel_per_unit, 0.6, @floatFromInt(count) };
    const params = [_]Params{
        .{
            .mins = .{ volume.mins[0], volume.mins[1], volume.mins[2], @floatFromInt(@intFromEnum(volume.kind)) },
            .maxs = .{ volume.maxs[0], volume.maxs[1], volume.maxs[2], time },
            .velocity = .{ v[0], v[1], v[2], seed },
            .eye = .{ eye[0], eye[1], eye[2], 0 },
            .shape = if (volume.kind == .rain) rain_shape else .{ exposure_seconds, lighting.pixel_per_unit, 0.9, @floatFromInt(count) },
            .tiles = .{ first_tile[0], first_tile[1], @floatFromInt(tiles[0]), @floatFromInt(per_tile) },
            .grid0 = grid0,
            .grid1 = grid1,
            .sky = sky,
        },
        .{
            .mins = .{ volume.mins[0], volume.mins[1], volume.mins[2], @floatFromInt(@intFromEnum(volume.kind)) },
            .maxs = .{ volume.maxs[0], volume.maxs[1], volume.maxs[2], time },
            .velocity = .{ v[0], v[1], v[2], seed },
            .eye = .{ eye[0], eye[1], eye[2], 1 },
            .shape = rain_shape,
            .tiles = .{ first_tile[0], first_tile[1], @floatFromInt(tiles[0]), @floatFromInt(per_tile) },
            .grid0 = grid0,
            .grid1 = grid1,
            .sky = sky,
        },
    };
    const parts: usize = if (volume.kind == .rain and cvars.vkWeatherSplashes.integer != 0) 2 else 1;
    for (0..parts) |part| {
        const space = vk.frame().stream.alloc(@sizeOf(Params), 16) orelse return;
        @memcpy(space.bytes[0..@sizeOf(Params)], std.mem.asBytes(&params[part]));
        out[part] = .{ .shader = if (part == 0) &drop_shader else &splash_shader, .params = space.address, .count = count * 6 };
    }
    if (volume.kind == .rain) out[2] = nearRain(volume, params[0], eye, density);
}

/// Drops per cubic unit of the camera's own rain (r_vkWeatherDensity 1).
const near_density: f32 = 1.5e-4;
/// The camera's own rain: the volume's drops spread over its whole height, so the slab between
/// the eye and the ground holds only a few, and looking down showed almost none while looking up
/// showed the column above. A denser layer falls through a window around the eye, inside the
/// same volume and under the same rain occlusion map.
fn nearRain(volume: Volume, base: Params, eye: [3]f32, density: f32) ?Draw {
    const below: f32 = 192;
    const above: f32 = 320;
    const reach: f32 = 384;
    const cap: u32 = 131072;
    const z_lo = @max(volume.mins[2], eye[2] - below);
    const z_hi = @min(volume.maxs[2], eye[2] + above);
    if (z_hi - z_lo < 16) return null;
    var first_tile: [2]f32 = undefined;
    var tiles: [2]u32 = undefined;
    for (0..2) |axis| {
        const lo = @max(volume.mins[axis], eye[axis] - reach);
        const hi = @min(volume.maxs[axis], eye[axis] + reach);
        if (hi <= lo) return null;
        first_tile[axis] = @floor(lo / tile_size);
        tiles[axis] = @intFromFloat(@floor(hi / tile_size) - first_tile[axis] + 1);
    }
    const per_tile_f = tile_size * tile_size * (z_hi - z_lo) * near_density * density;
    const per_tile: u32 = @intFromFloat(@min(per_tile_f, 65536));
    if (per_tile == 0) return null;
    // Typed: @min with the comptime cap would narrow the count to 17 bits.
    const count: u32 = @min(tiles[0] * tiles[1] * per_tile, cap);
    var params = base;
    params.mins[2] = z_lo;
    params.maxs[2] = z_hi;
    // Its own random sequence, and no splashes (the volume's layer lands them).
    params.velocity[3] = base.velocity[3] + 7919;
    params.eye[3] = 0;
    params.tiles = .{ first_tile[0], first_tile[1], @floatFromInt(tiles[0]), @floatFromInt(per_tile) };
    params.shape[3] = @floatFromInt(count);
    const space = vk.frame().stream.alloc(@sizeOf(Params), 16) orelse return null;
    @memcpy(space.bytes[0..@sizeOf(Params)], std.mem.asBytes(&params));
    return .{ .shader = &drop_shader, .params = space.address, .count = count * 6 };
}

/// Box list for the view, the `max_view_boxes` volumes nearest the eye: (mins, kind), (maxs, 0).
pub fn viewBoxes(registration: u32, eye: [3]f32, boxes: *[max_view_boxes * 2][4]f32) u32 {
    var chosen: [max_view_boxes]struct { volume: *const Volume, distance: f32 } = undefined;
    var count: u32 = 0;
    for (sceneVolumes()) |*volume| {
        if (volume.registration != registration) continue;
        var distance: f32 = 0;
        for (0..3) |axis| {
            const d = @max(@max(volume.mins[axis] - eye[axis], eye[axis] - volume.maxs[axis]), 0);
            distance += d * d;
        }
        // Keep the nearest: replace the farthest kept when full.
        var slot: ?usize = if (count < max_view_boxes) count else null;
        if (slot == null) {
            var farthest: usize = 0;
            for (chosen[0..count], 0..) |entry, k| {
                if (entry.distance > chosen[farthest].distance) farthest = k;
            }
            if (distance < chosen[farthest].distance) slot = farthest;
        }
        const k = slot orelse continue;
        chosen[k] = .{ .volume = volume, .distance = distance };
        if (count < max_view_boxes) count += 1;
    }
    for (chosen[0..count], 0..) |entry, k| {
        const volume = entry.volume;
        boxes[k * 2] = .{ volume.mins[0], volume.mins[1], volume.mins[2], @floatFromInt(@intFromEnum(volume.kind)) };
        boxes[k * 2 + 1] = .{ volume.maxs[0], volume.maxs[1], volume.maxs[2], 0 };
    }
    return count;
}
