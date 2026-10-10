// SPDX-License-Identifier: GPL-2.0-or-later
//! Motion vectors for temporal upscaling (taa.zig, fsr.zig, dlss.zig). The shading pass writes,
//! for every depth-writing surface, where its pixel was in the previous frame (stage.vert
//! computes the previous position, stage.frag the difference in render-target pixels).
//!
//! Model entities carry no identity across frames in the renderer API, so each one is matched to
//! the previous frame's entity of the same model nearest to it: its previous transform, MD3
//! frames and skeleton give moving characters, movers and the view weapon their real motion.
//! Unmatched entities move with the camera only.
const std = @import("std");
const c = @import("c.zig").c;
const common = @import("common.zig");

pub const max_bones = 64;
/// Farther than this from every same-model entity of the last frame is a new entity.
const match_distance: f32 = 96;

pub const History = struct {
    model: c.qhandle_t,
    renderfx: c_int,
    origin: [3]f32,
    axis: [3][3]f32,
    frame: c_int,
    oldframe: c_int,
    backlerp: f32,
    bone_count: u32,
    bones: [max_bones][12]f32,
};

/// The previous frame's entities and which of them this frame has claimed.
var previous: std.ArrayList(History) = .empty;
var claimed: std.ArrayList(bool) = .empty;
var current: std.ArrayList(History) = .empty;

/// Records a model entity as drawn this frame (scene.zig, once per entity of the main view).
pub fn record(e: *const c.refEntity_t) void {
    if (e.reType != c.RT_MODEL) return;
    var h: History = .{
        .model = e.hModel,
        .renderfx = e.renderfx,
        .origin = e.origin,
        .axis = e.axis,
        .frame = e.frame,
        .oldframe = e.oldframe,
        .backlerp = e.backlerp,
        .bone_count = 0,
        .bones = undefined,
    };
    if (e.dk3BoneCount > 0 and e.dk3BoneCount <= max_bones) {
        h.bone_count = @intCast(e.dk3BoneCount);
        for (0..h.bone_count) |i| h.bones[i] = e.dk3BoneMatrices[i];
    }
    current.append(common.gpa, h) catch {};
}

/// The frame's entities become the previous frame's (scene.zig beginFrame).
pub fn endFrame() void {
    std.mem.swap(std.ArrayList(History), &previous, &current);
    current.clearRetainingCapacity();
    claimed.resize(common.gpa, previous.items.len) catch {
        previous.clearRetainingCapacity();
        claimed.clearRetainingCapacity();
        return;
    };
    @memset(claimed.items, false);
}

/// Forgets every entity (camera cuts, map changes): nothing has a previous position.
pub fn reset() void {
    previous.clearRetainingCapacity();
    claimed.clearRetainingCapacity();
    current.clearRetainingCapacity();
}

/// The previous frame's state of `e`, or null for an entity new this frame. Each previous
/// entity is claimed by at most one current entity.
pub fn match(e: *const c.refEntity_t) ?*const History {
    if (e.reType != c.RT_MODEL) return null;
    const first_person = e.renderfx & c.RF_FIRST_PERSON != 0;
    var best: ?usize = null;
    var best_distance: f32 = match_distance * match_distance;
    for (previous.items, 0..) |*h, index| {
        if (claimed.items[index] or h.model != e.hModel) continue;
        if ((h.renderfx & c.RF_FIRST_PERSON != 0) != first_person) continue;
        var d: f32 = 0;
        for (0..3) |k| d += (h.origin[k] - e.origin[k]) * (h.origin[k] - e.origin[k]);
        // The view weapon moves with the camera: it is always its previous self.
        if (first_person) d = 0;
        if (d <= best_distance) {
            best_distance = d;
            best = index;
        }
    }
    const index = best orelse return null;
    claimed.items[index] = true;
    return &previous.items[index];
}

pub fn shutdown() void {
    previous.deinit(common.gpa);
    claimed.deinit(common.gpa);
    current.deinit(common.gpa);
    previous = .empty;
    claimed = .empty;
    current = .empty;
}
