// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: bounded initial model preparation slots; GPU work stays on the owner.
const std = @import("std");
const cext = @import("c.zig");
const c = cext.c;
const common = @import("common.zig");

pub const Prepare = *const fn ([]const u8, *cext.ImageBatch) ?[]u8;
const Slot = struct {
    name: [c.MAX_QPATH]u8 = @splat(0),
    bytes: ?[]u8 = null,
    batch: ?*cext.ImageBatch = null,
    status: c_int = 0,
};
var slots: [4]Slot = .{ .{}, .{}, .{}, .{} };
var names: [c.MAX_MODELS][c.MAX_QPATH]u8 = undefined;
var count: usize = 0;
var cursor: usize = 0;
var prepare: ?Prepare = null;
var selected: ?usize = null;
var slot_limit: usize = 2;
pub const Ticket = struct { index: usize };

fn release(slot: *Slot) void {
    cext.R_FreeImageBatch(slot.batch); // Joins before read/pixel ownership is released.
    if (slot.bytes) |bytes| common.freeFile(bytes);
    slot.* = .{};
}

pub fn cancel() void {
    cext.R_SelectImageBatch(null);
    selected = null;
    for (&slots) |*slot| release(slot);
    count = 0;
    cursor = 0;
    prepare = null;
}

/// Advance reads/decodes during other owner-thread admission work, without filling slots.
pub fn pump() void {
    for (&slots) |*slot| if (slot.batch != null and slot.status == 0) {
        slot.status = cext.R_PollImageBatch(slot.batch);
    };
}

fn fill() void {
    const callback = prepare orelse return;
    for (slots[0..slot_limit]) |*slot| {
        while (slot.batch == null and cursor < count) {
            const path = &names[cursor];
            cursor += 1;
            const batch = cext.R_CreateCachedImageBatch(1024) orelse continue;
            // Active slots precede this one in registration order.
            // Snapshot their queued names; actual loading remains the fallback
            // if that earlier hint is cancelled, fails, or registers out of order.
            for (slots) |earlier| if (earlier.batch) |source| {
                _ = cext.R_ExcludePreparedImages(batch, source);
            };
            const bytes = callback(std.mem.sliceTo(path, 0), batch) orelse {
                cext.R_FreeImageBatch(batch);
                continue;
            };
            slot.* = .{ .name = path.*, .bytes = bytes, .batch = batch };
            var active: usize = 0;
            for (slots) |entry| if (entry.batch != null) {
                active += 1;
            };
            common.developer("dk3 model prefetch: name={s} model_bytes={d} active_slots={d}\n", .{ std.mem.sliceTo(path, 0), bytes.len, active });
            // Start this independent read while the next model metadata loads.
            slot.status = cext.R_PollImageBatch(batch);
            pump(); // Earlier reads can dispatch while later model metadata loads.
        }
    }
    pump();
}

pub fn begin(paths: [*c]const u8, length: c_int, callback: Prepare, requested_slots: c_int) bool {
    cancel();
    if (length < 0 or length > c.MAX_MODELS or (length > 0 and paths == null)) return false;
    for (0..@intCast(length)) |index| {
        const path = paths[index * c.MAX_QPATH ..][0..c.MAX_QPATH];
        const end = std.mem.indexOfScalar(u8, path, 0) orelse {
            cancel();
            return false;
        };
        if (end == 0 or path[0] == '*') continue;
        var duplicate = false;
        for (names[0..count]) |previous| if (std.mem.eql(u8, std.mem.sliceTo(&previous, 0), path[0..end])) {
            duplicate = true;
            break;
        };
        if (duplicate) continue;
        names[count] = @splat(0);
        @memcpy(names[count][0..end], path[0..end]);
        count += 1;
    }
    prepare = callback;
    slot_limit = @intCast(std.math.clamp(requested_slots, 1, @as(c_int, slots.len)));
    fill();
    return true;
}

/// The ordered registration consumes its prepared pixels before doing any GPU
/// work. An unsupported/failed hint keeps normal validated registration available.
pub fn select(name: []const u8) ?Ticket {
    if (selected != null) return null;
    pump();
    for (&slots, 0..) |*slot, index| {
        if (slot.batch == null or !std.mem.eql(u8, std.mem.sliceTo(&slot.name, 0), name)) continue;
        const started = common.milliseconds();
        while (slot.status == 0) {
            pump();
            if (slot.status == 0) c.SDL_Delay(1);
        }
        selected = index;
        if (slot.status > 0) cext.R_SelectImageBatch(slot.batch);
        common.developer("dk3 model preparation: name={s} ready={d} wait_ms={d}\n", .{ name, slot.status, common.milliseconds() - started });
        return .{ .index = index };
    }
    return null;
}

pub fn takeBytes(name: []const u8) ?[]u8 {
    const index = selected orelse return null;
    const slot = &slots[index];
    if (!std.mem.eql(u8, std.mem.sliceTo(&slot.name, 0), name)) return null;
    const bytes = slot.bytes orelse return null;
    slot.bytes = null;
    return bytes;
}

pub fn finish(ticket: Ticket) void {
    std.debug.assert(selected == ticket.index);
    cext.R_SelectImageBatch(null);
    selected = null;
    release(&slots[ticket.index]);
    fill();
}
