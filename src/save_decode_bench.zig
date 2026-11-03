// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Read-only CPU characterization of actual portable save decoding.
const std = @import("std");
const stream = @import("core/domain/save_stream.zig");
const snapshot = @import("mechanics/domain/snapshot.zig");
pub const snapshot_runtime_identity = @import("runtime_build").identity;
pub const saved_classes = if (@import("save_bench_options").server) @import("mechanics/server/saved_classes.zig") else struct {};

const Stamp = struct { wall: u64, cpu: u64 };
fn stamp() Stamp {
    var wall: std.c.timespec = undefined;
    var cpu: std.c.timespec = undefined;
    if (std.c.clock_gettime(.MONOTONIC, &wall) != 0 or std.c.clock_gettime(.PROCESS_CPUTIME_ID, &cpu) != 0) @panic("benchmark clocks unavailable");
    return .{
        .wall = @as(u64, @intCast(wall.sec)) * std.time.ns_per_s + @as(u64, @intCast(wall.nsec)),
        .cpu = @as(u64, @intCast(cpu.sec)) * std.time.ns_per_s + @as(u64, @intCast(cpu.nsec)),
    };
}
const Identity = struct { entities: usize = 0, worlds: usize = 0, player: u32 = 0, next: u32 = 0, records: usize = 0 };
fn identity(loaded: *const snapshot.Loaded) Identity {
    var result: Identity = .{ .entities = loaded.world.count(), .worlds = 1, .player = loaded.header.player_id, .next = loaded.header.next_id };
    for (loaded.residents) |*member| {
        const child = identity(member);
        result.entities += child.entities;
        result.worlds += child.worlds;
    }
    return result;
}

fn canonical(allocator: std.mem.Allocator, loaded: *snapshot.Loaded) anyerror![]u8 {
    const members = try allocator.alloc(snapshot.Archive, loaded.residents.len);
    defer allocator.free(members);
    var completed: usize = 0;
    defer for (members[0..completed]) |member| allocator.free(member.bytes);
    for (loaded.residents, 0..) |*member, i| {
        members[i] = .{ .map = member.map, .bytes = try canonical(allocator, member) };
        completed += 1;
    }
    const storage = try allocator.alloc(u8, if (loaded.region_member) snapshot.world_limit else snapshot.maximum);
    defer allocator.free(storage);
    const result = try snapshot.captureRegion(allocator, storage, &loaded.world, loaded.map, loaded.skill, loaded.header, loaded.visited, members);
    return allocator.dupe(u8, result);
}

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.c_allocator;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4 and args.len != 5) return error.ExpectedSaveModeRepeats;
    const mode = args[2];
    const Mode = enum { crc, stream, decode, roundtrip, parallel, prepared, selected, handoff, double_decode };
    const operation = std.meta.stringToEnum(Mode, mode) orelse return error.InvalidMode;
    const repeats = try std.fmt.parseInt(usize, args[3], 10);
    if (repeats == 0 or repeats > 1000) return error.InvalidRepeats;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(snapshot.maximum));
    defer allocator.free(bytes);
    const Pool = @import("core/ecs/jobs.zig").Pool;
    const pool: ?*Pool = if (operation == .parallel or operation == .prepared or operation == .selected or operation == .handoff) try Pool.create(allocator, 4) else null;
    defer if (pool) |workers| workers.destroy();
    var encoded_storage: ?[]u8 = null;
    defer if (encoded_storage) |storage| allocator.free(storage);
    var prepared: []const u8 = &.{};
    if (operation == .prepared or operation == .selected) {
        var loaded = try snapshot.decode(allocator, bytes);
        defer loaded.deinit(allocator);
        const plan = try snapshot.planPrepared(&loaded);
        encoded_storage = try allocator.alloc(u8, plan.bytes);
        prepared = try snapshot.capturePreparedPlanned(allocator, encoded_storage.?, &loaded, plan);
    }
    const Manifest = @import("mechanics/domain/campaign_regions.zig").Manifest;
    const manifest_bytes = if (args.len == 5) try std.Io.Dir.cwd().readFileAlloc(init.io, args[4], allocator, .limited(256 * 1024)) else null;
    defer if (manifest_bytes) |input| allocator.free(input);
    var manifest: ?Manifest = if (manifest_bytes) |input| try Manifest.parse(input) else null;
    if (operation == .selected and manifest == null) return error.ExpectedCampaignManifest;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    var buffer: [4096]u8 = undefined;
    var output = std.Io.File.Writer.initStreaming(.stdout(), init.io, &buffer);
    var expected: ?Identity = null;
    var expected_canonical: ?[32]u8 = null;
    for (0..repeats + 1) |sample| {
        const before = stamp();
        var engine_cache: ?[]u8 = null;
        defer if (engine_cache) |copy| allocator.free(copy);
        var consumer_copy: ?[]u8 = null;
        defer if (consumer_copy) |copy| allocator.free(copy);
        var ui_digest: [32]u8 = undefined;
        var state: Identity = .{};
        var canonical_digest: [32]u8 = @splat(0);
        var canonical_bytes: usize = 0;
        if (std.mem.eql(u8, mode, "crc")) {
            const reader = try stream.Reader.init(bytes);
            state.records = reader.records_left;
        } else if (std.mem.eql(u8, mode, "stream")) {
            // The outer stream deliberately treats nested checkpoint bytes as
            // opaque; full recursive reconstruction is measured by decode.
            try stream.Reader.validate(bytes);
        } else {
            if (operation == .double_decode or operation == .handoff) {
                var ui = try snapshot.decode(allocator, bytes);
                defer ui.deinit(allocator);
                if (operation == .handoff) {
                    const plan = try snapshot.planPrepared(&ui);
                    const storage = try allocator.alloc(u8, plan.bytes);
                    defer allocator.free(storage);
                    prepared = try snapshot.capturePreparedPlanned(allocator, storage, &ui, plan);
                    @import("core/domain/sha256_runtime.zig").hash(bytes, &ui_digest);
                    // Match the engine store/read byte ownership and account
                    // for both copies, not just the faster typed decoder.
                    engine_cache = try allocator.dupe(u8, prepared);
                    consumer_copy = try allocator.dupe(u8, engine_cache.?);
                    prepared = consumer_copy.?;
                }
            }
            if (operation == .handoff) {
                var server_digest: [32]u8 = undefined;
                @import("core/domain/sha256_runtime.zig").hash(bytes, &server_digest);
                if (!std.mem.eql(u8, &ui_digest, &server_digest)) return error.SourceMismatch;
            }
            var loaded = switch (operation) {
                .parallel => try snapshot.decodeWithPool(allocator, bytes, pool),
                .prepared => try snapshot.decodeWithPool(allocator, prepared, pool),
                .selected, .handoff => if (manifest) |*graph|
                    try snapshot.decodeCertifiedSelection(allocator, prepared, graph, pool)
                else
                    try snapshot.decodeWithPool(allocator, prepared, pool),
                else => try snapshot.decode(allocator, bytes),
            };
            defer loaded.deinit(allocator);
            if (operation == .selected or operation == .handoff) try loaded.bindOriginal(bytes);
            state = identity(&loaded);
            if (std.mem.eql(u8, mode, "roundtrip")) {
                const encoded = try canonical(allocator, &loaded);
                defer allocator.free(encoded);
                std.crypto.hash.sha2.Sha256.hash(encoded, &canonical_digest, .{});
                canonical_bytes = encoded.len;
                if (expected_canonical) |previous| {
                    if (!std.mem.eql(u8, &previous, &canonical_digest)) return error.CanonicalMismatch;
                } else expected_canonical = canonical_digest;
            }
        }
        const after = stamp();
        if (expected) |first| {
            if (!std.meta.eql(first, state)) return error.IdentityMismatch;
        } else expected = state;
        if (sample != 0) try output.interface.print(
            "{{\"mode\":\"{s}\",\"sample\":{d},\"bytes\":{d},\"sha256\":\"{s}\",\"wall_ns\":{d},\"cpu_ns\":{d},\"entities\":{d},\"worlds\":{d},\"player\":{d},\"next\":{d},\"outer_records\":{d},\"canonical_bytes\":{d},\"canonical_sha256\":\"{s}\"}}\n",
            .{ mode, sample, bytes.len, std.fmt.bytesToHex(digest, .lower), after.wall - before.wall, after.cpu - before.cpu, state.entities, state.worlds, state.player, state.next, state.records, canonical_bytes, std.fmt.bytesToHex(canonical_digest, .lower) },
        );
    }
    try output.interface.flush();
}
