// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: skeletal aim (remaster presentation). A living humanoid actor drawn with a
//! skeletal model bends its chest (its arms and weapon follow) and its head toward the pitch the
//! server publishes for the enemy it engages (`state.angles[0]`, degrees, positive up). The
//! reference turns monsters by yaw alone, so its authored clips aim level; nothing changes the
//! simulation. Never names a class: any rigged humanoid model takes part.
const std = @import("std");
const c = @import("../../engine/abi.zig").c;
const engine = @import("../../engine/client.zig");
const v = @import("../../core/domain/vector.zig");
const m = @import("../../core/domain/bone_matrix.zig");
const ragdolls = @import("ragdolls.zig");

/// The chest takes this share of the pitch; the head the rest.
const chest_share: f32 = 0.7;
/// Pitches smaller than this are drawn as authored.
const threshold: f32 = 2;
/// The drawn pitch follows the published one at this rate (degrees per second), so starting
/// and ending an attack eases the body in and out instead of snapping.
const rate: f32 = 120;

/// The pitch each entity number was last drawn with, and when.
var drawn: [c.MAX_GENTITIES]struct { pitch: f32 = 0, ms: i32 = 0 } = @splat(.{});

pub fn reset() void {
    drawn = @splat(.{});
}
/// Moves `current` toward `target` by at most `rate` degrees per second over `elapsed_ms`.
pub fn ease(current: f32, target: f32, elapsed_ms: i32) f32 {
    const step = rate * @as(f32, @floatFromInt(std.math.clamp(elapsed_ms, 0, 250))) / 1000;
    return current + std.math.clamp(target - current, -step, step);
}
pub fn apply(state: c.entityState_t, entity: *c.refEntity_t, now: i32) void {
    const slot: usize = @intCast(state.number);
    const target = if (state.eFlags & c.EF_DEAD != 0) 0 else state.angles[0];
    const previous = drawn[slot];
    const pitch = if (now - previous.ms > 250) target else ease(previous.pitch, target, now - previous.ms);
    drawn[slot] = .{ .pitch = pitch, .ms = now };
    if (@abs(pitch) < threshold or state.eFlags & c.EF_DEAD != 0 or entity.dk3BoneCount != 0) return;
    if (engine.number("cg_skeletalAim", 1) == 0) return;
    const rig = ragdolls.rigOf(entity.hModel) orelse return;
    if (rig.creature_count != 0) return;
    var posed: [64]m.Mat = undefined;
    for (0..rig.count) |i| {
        var tag: c.orientation_t = undefined;
        if (engine.gateway.call(c.CG_R_LERPTAG, .{ &tag, @as(isize, entity.hModel), @as(isize, entity.oldframe), @as(isize, entity.frame), engine.floatArg(1 - entity.backlerp), &rig.names[i] }) == 0) return;
        posed[i] = m.basis(tag.axis[0], tag.axis[1], tag.axis[2], tag.origin);
    }
    const chest = rig.bones[index("chest")];
    const head = rig.bones[index("head")];
    turn(rig, &posed, chest, pitch * chest_share);
    turn(rig, &posed, head, pitch * (1 - chest_share));
    entity.dk3BoneCount = @intCast(rig.count);
    entity.dk3BoneBounds = .{ @splat(100000), @splat(-100000) };
    for (0..rig.count) |i| {
        entity.dk3BoneMatrices[i] = m.mul(posed[i], rig.inverse[i]);
        const position = m.position(posed[i]);
        for (0..3) |axis| {
            entity.dk3BoneBounds[0][axis] = @min(entity.dk3BoneBounds[0][axis], position[axis] - rig.padding);
            entity.dk3BoneBounds[1][axis] = @max(entity.dk3BoneBounds[1][axis], position[axis] + rig.padding);
        }
    }
}
fn index(comptime name: []const u8) usize {
    inline for (@import("../../core/domain/ragdoll.zig").names, 0..) |candidate, i| if (comptime std.mem.eql(u8, candidate, name)) return i;
    @compileError("no humanoid joint " ++ name);
}
/// Turns `joint` and everything below it about the model's left axis, raising its forward
/// direction by `degrees`.
fn turn(rig: *const ragdolls.Rig, posed: *[64]m.Mat, joint: usize, degrees: f32) void {
    const pivot = m.position(posed[joint]);
    const rotation = raise(degrees, pivot);
    for (0..rig.count) |k| if (below(rig, k, joint)) {
        posed[k] = m.mul(rotation, posed[k]);
    };
}
/// The rotation about the left (+Y) axis through `pivot` that lifts +X toward +Z by `degrees`.
pub fn raise(degrees: f32, pivot: v.Vec3) m.Mat {
    const radians = degrees * std.math.pi / 180;
    const cosine = @cos(radians);
    const sine = @sin(radians);
    const rotation: m.Mat = .{ cosine, 0, -sine, 0, 0, 1, 0, 0, sine, 0, cosine, 0 };
    return m.translated(rotation, v.subtract(pivot, m.direction(rotation, pivot)));
}
fn below(rig: *const ragdolls.Rig, joint: usize, ancestor: usize) bool {
    var current: i32 = @intCast(joint);
    while (current >= 0) : (current = rig.parent[@intCast(current)]) if (current == ancestor) return true;
    return false;
}

test "the drawn pitch eases toward the published one" {
    const t = std.testing;
    try t.expectApproxEqAbs(@as(f32, 12), ease(0, 30, 100), 0.001);
    try t.expectApproxEqAbs(@as(f32, 30), ease(25, 30, 100), 0.001);
    try t.expectApproxEqAbs(@as(f32, -6), ease(0, -30, 50), 0.001);
}
test "raising turns forward toward up about the pivot" {
    const t = std.testing;
    const turned = raise(90, .{ 0, 0, 10 });
    const tip = m.point(turned, .{ 1, 0, 10 });
    try t.expectApproxEqAbs(@as(f32, 0), tip[0], 0.001);
    try t.expectApproxEqAbs(@as(f32, 11), tip[2], 0.001);
    const pivot = m.point(turned, .{ 0, 0, 10 });
    try t.expectApproxEqAbs(@as(f32, 10), pivot[2], 0.001);
}
