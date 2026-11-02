// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: source/settings-bound GPU-ready world geometry and HDR pages.
const std = @import("std");
pub const maximum = 256 * 1024 * 1024;
pub const header_size = 72;
pub const vertex_size = 48;
pub const page_size = 128 * 128 * 8;
pub const Surface = extern struct {
    kind: u32,
    first_index: u32,
    num_indexes: u32,
    grid_width: u32,
    grid_height: u32,
    first_vertex: u32,
    mins: [3]f32,
    maxs: [3]f32,
    plane_normal: [3]f32,
    plane_dist: f32,
};
comptime {
    if (@sizeOf(Surface) != 64) @compileError("prepared surface wire layout changed");
}
pub const World = struct {
    vertices: []const u8,
    indices: []const u8,
    surfaces: []const u8,
    lightmaps: []const u8,
};
pub fn path(name: []const u8, buffer: *[64]u8) ![:0]const u8 {
    const texture_path = try @import("prepared_texture.zig").path(name, buffer);
    buffer[texture_path.len - 1] = 'w';
    return buffer[0..texture_path.len :0];
}
fn word(bytes: []const u8, at: usize) u32 {
    return std.mem.readInt(u32, bytes[at..][0..4], .little);
}
pub fn decode(bytes: []const u8, source: []const u8, shift: u5, patch_level: u32, surfaces: usize, pages: usize) !World {
    if (@import("builtin").target.cpu.arch.endian() != .little) return error.UnsupportedPreparedEndian;
    if (bytes.len < header_size or bytes.len > maximum or !std.mem.eql(u8, bytes[0..8], "DK3WLD1\x00")) return error.InvalidPreparedWorld;
    var digest: [32]u8 = undefined;
    @import("runtime_digest").hash(source, &digest);
    if (!std.mem.eql(u8, &digest, bytes[8..40]) or word(bytes, 40) != shift or word(bytes, 44) != patch_level) return error.StalePreparedWorld;
    if (word(bytes, 56) != surfaces or word(bytes, 60) != pages or word(bytes, 68) != 0 or std.hash.Crc32.hash(bytes[header_size..]) != word(bytes, 64)) return error.InvalidPreparedWorld;
    const vertex_bytes: u64 = @as(u64, word(bytes, 48)) * vertex_size;
    const index_bytes: u64 = @as(u64, word(bytes, 52)) * 4;
    const surface_bytes: u64 = @as(u64, word(bytes, 56)) * @sizeOf(Surface);
    const page_bytes: u64 = @as(u64, word(bytes, 60)) * page_size;
    if (header_size + vertex_bytes + index_bytes + surface_bytes + page_bytes != bytes.len) return error.InvalidPreparedWorld;
    const vertex_end = header_size + vertex_bytes;
    const index_end = vertex_end + index_bytes;
    const surface_end = index_end + surface_bytes;
    const result: World = .{ .vertices = bytes[header_size..vertex_end], .indices = bytes[vertex_end..index_end], .surfaces = bytes[index_end..surface_end], .lightmaps = bytes[surface_end..] };
    var at: usize = 0;
    while (at < result.indices.len) : (at += 4) if (word(result.indices, at) >= word(bytes, 48)) return error.InvalidPreparedWorld;
    at = 0;
    while (at < result.vertices.len) : (at += vertex_size) {
        for (0..10) |i| if (!std.math.isFinite(@as(f32, @bitCast(word(result.vertices, at + i * 4))))) return error.InvalidPreparedWorld;
        if (word(result.vertices, at + 44) != 0) return error.InvalidPreparedWorld;
    }
    at = 0;
    while (at < result.surfaces.len) : (at += @sizeOf(Surface)) {
        const surface = readSurface(result.surfaces[at..][0..@sizeOf(Surface)]);
        if (surface.kind > 3 or @as(u64, surface.first_index) + surface.num_indexes > word(bytes, 52) or surface.first_vertex > word(bytes, 48)) return error.InvalidPreparedWorld;
        if (surface.kind == 2 and @as(u64, surface.grid_width) * surface.grid_height + surface.first_vertex > word(bytes, 48)) return error.InvalidPreparedWorld;
        for ([_][3]f32{ surface.mins, surface.maxs, surface.plane_normal }) |vector| for (vector) |value| if (!std.math.isFinite(value)) return error.InvalidPreparedWorld;
        if (!std.math.isFinite(surface.plane_dist)) return error.InvalidPreparedWorld;
    }
    return result;
}
pub fn readSurface(bytes: []const u8) Surface {
    var result: Surface = undefined;
    @memcpy(std.mem.asBytes(&result), bytes[0..@sizeOf(Surface)]);
    return result;
}
