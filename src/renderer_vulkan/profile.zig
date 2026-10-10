// SPDX-License-Identifier: GPL-2.0-or-later
//! GPU pass timing for r_vkStats: named scopes write timestamps into the frame slot's query
//! pool; when the slot comes round again (its timeline wait already done) the results are read
//! without waiting and averaged per name, together with the CPU frame time.
const std = @import("std");
const c = @import("c.zig").c;
const common = @import("common.zig");
const cvars = @import("cvars.zig");
const vk = @import("vk.zig");

const max_scopes = 64;

const Slot = struct {
    pool: c.VkQueryPool = null,
    names: [max_scopes][]const u8 = undefined,
    count: u32 = 0,
    recorded: bool = false,
};

var slots: [vk.frames_in_flight]Slot = [_]Slot{.{}} ** vk.frames_in_flight;
var period_ns: f64 = 1;

const Total = struct { name: []const u8, ms: f64 = 0, samples: u32 = 0 };
var totals: [max_scopes]Total = undefined;
var total_count: usize = 0;
var frames: u32 = 0;
var cpu_ms: f64 = 0;
var wait_ms: f64 = 0;
var last_frame_ns: i128 = 0;
/// Frame pacing: the longest CPU frame interval and the summed change between consecutive ones.
var max_interval_ms: f64 = 0;
var last_interval_ms: f64 = 0;
var interval_change_ms: f64 = 0;
/// GPU end of the previous frame's "frame" scope: the gap to the next frame's start is time the
/// GPU had no frame work (waiting on the CPU or on presentation).
var last_frame_end: u64 = 0;
var frame_end: u64 = 0;

const CpuTotal = struct { name: []const u8, ns: i128 = 0 };
var cpu_totals: [16]CpuTotal = undefined;
var cpu_count: usize = 0;

/// CPU section timing: `cpuBegin` returns a start stamp for `cpuEnd`.
pub fn cpuBegin() i128 {
    return if (enabled()) common.nanoseconds() else 0;
}

pub fn cpuEnd(name: []const u8, start: i128) void {
    if (start == 0) return;
    const elapsed = common.nanoseconds() - start;
    for (cpu_totals[0..cpu_count]) |*total| if (std.mem.eql(u8, total.name, name)) {
        total.ns += elapsed;
        return;
    };
    if (cpu_count == cpu_totals.len) return;
    cpu_totals[cpu_count] = .{ .name = name, .ns = elapsed };
    cpu_count += 1;
}

fn enabled() bool {
    return cvars.vkStats.integer > 0;
}

pub fn create() void {
    period_ns = vk.s.properties.limits.timestampPeriod;
    const info = std.mem.zeroInit(c.VkQueryPoolCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO,
        .queryType = c.VK_QUERY_TYPE_TIMESTAMP,
        .queryCount = max_scopes * 2,
    });
    for (&slots) |*slot| {
        slot.* = .{};
        vk.must(vk.d.CreateQueryPool.?(vk.s.device, &info, null, &slot.pool), "vkCreateQueryPool");
    }
}

pub fn destroy() void {
    for (&slots) |*slot| {
        if (slot.pool != null) vk.d.DestroyQueryPool.?(vk.s.device, slot.pool, null);
        slot.* = .{};
    }
}

fn add(name: []const u8, ms: f64) void {
    for (totals[0..total_count]) |*total| if (std.mem.eql(u8, total.name, name)) {
        total.ms += ms;
        total.samples += 1;
        return;
    };
    if (total_count == max_scopes) return;
    totals[total_count] = .{ .name = name, .ms = ms, .samples = 1 };
    total_count += 1;
}

/// Start of the slot's draw recording: collect what the slot measured last time round, then
/// reset its queries. `waited_ms` is how long the CPU waited for that slot.
pub fn frameStart(cmd: c.VkCommandBuffer, waited_ms: f64) void {
    const slot = &slots[vk.frame_index];
    if (slot.pool == null) return;
    if (slot.recorded and slot.count > 0) {
        var values: [max_scopes * 2][2]u64 = undefined;
        const result = vk.d.GetQueryPoolResults.?(vk.s.device, slot.pool, 0, slot.count * 2, @sizeOf(@TypeOf(values)), &values, @sizeOf([2]u64), c.VK_QUERY_RESULT_64_BIT | c.VK_QUERY_RESULT_WITH_AVAILABILITY_BIT);
        if (result == c.VK_SUCCESS or result == c.VK_NOT_READY) {
            for (0..slot.count) |k| {
                const a = values[k * 2];
                const b = values[k * 2 + 1];
                if (a[1] == 0 or b[1] == 0 or b[0] < a[0]) continue;
                add(slot.names[k], @as(f64, @floatFromInt(b[0] - a[0])) * period_ns / 1e6);
                if (std.mem.eql(u8, slot.names[k], "frame")) {
                    if (last_frame_end != 0 and a[0] > last_frame_end) add("idle before frame (uploads, late submit)", @as(f64, @floatFromInt(a[0] - last_frame_end)) * period_ns / 1e6);
                    frame_end = b[0];
                }
                if (std.mem.eql(u8, slot.names[k], "swapchain composite")) {
                    if (frame_end != 0 and a[0] > frame_end) add("idle before swapchain composite (acquire wait)", @as(f64, @floatFromInt(a[0] - frame_end)) * period_ns / 1e6);
                    last_frame_end = b[0];
                }
            }
        }
    }
    slot.count = 0;
    slot.recorded = enabled();
    if (slot.recorded) vk.d.CmdResetQueryPool.?(cmd, slot.pool, 0, max_scopes * 2);
    const now = common.nanoseconds();
    if (enabled()) {
        if (last_frame_ns != 0) {
            const interval = @as(f64, @floatFromInt(now - last_frame_ns)) / 1e6;
            cpu_ms += interval;
            max_interval_ms = @max(max_interval_ms, interval);
            if (last_interval_ms > 0) interval_change_ms += @abs(interval - last_interval_ms);
            last_interval_ms = interval;
        }
        wait_ms += waited_ms;
        frames += 1;
    }
    last_frame_ns = now;
}

/// Opens a timed scope; returns its index for `end` (or null when not timing).
pub fn begin(cmd: c.VkCommandBuffer, name: []const u8) ?u32 {
    const slot = &slots[vk.frame_index];
    if (!slot.recorded or slot.count == max_scopes) return null;
    const index = slot.count;
    slot.names[index] = name;
    slot.count += 1;
    vk.d.CmdWriteTimestamp2.?(cmd, c.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, slot.pool, index * 2);
    return index;
}

pub fn end(cmd: c.VkCommandBuffer, index: ?u32) void {
    const k = index orelse return;
    vk.d.CmdWriteTimestamp2.?(cmd, c.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, slots[vk.frame_index].pool, k * 2 + 1);
}

/// Prints and clears the averages every r_vkStats frames.
pub fn report() void {
    const every = cvars.vkStats.integer;
    if (every <= 0 or frames < @as(u32, @intCast(every))) return;
    const n: f64 = @floatFromInt(frames);
    common.info("vk timing: frames={d} frame_ms={d:.2} fps={d:.1} gpu_wait_ms={d:.2} max_frame_ms={d:.2} pacing_ms={d:.2}\n", .{ frames, cpu_ms / n, if (cpu_ms > 0) 1000.0 * n / cpu_ms else 0, wait_ms / n, max_interval_ms, interval_change_ms / n });
    max_interval_ms = 0;
    interval_change_ms = 0;
    // Largest first.
    std.mem.sort(Total, totals[0..total_count], {}, struct {
        fn more(_: void, a: Total, b: Total) bool {
            return a.ms > b.ms;
        }
    }.more);
    for (totals[0..total_count]) |total| common.info("  gpu {s}: {d:.3} ms ({d} samples/frame)\n", .{ total.name, total.ms / n, @divTrunc(total.samples, frames) });
    for (cpu_totals[0..cpu_count]) |total| common.info("  cpu {s}: {d:.3} ms\n", .{ total.name, @as(f64, @floatFromInt(total.ns)) / 1e6 / n });
    total_count = 0;
    cpu_count = 0;
    frames = 0;
    cpu_ms = 0;
    wait_ms = 0;
}
