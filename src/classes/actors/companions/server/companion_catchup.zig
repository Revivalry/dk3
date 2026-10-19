// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Catch-up: a companion stuck far from its leader (no way on, left behind,
//! in lava or slime it cannot climb out of, out of air under a ceiling)
//! reappears on safe footing beside the leader, where the leader sees
//! neither the companion leave nor arrive. Gold has no such warp (only
//! authored teleport nodes); this is the reviewed deviation.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const c = abi.c;
const engine = @import("../../../../engine/server.zig");
const v = @import("../../../../core/domain/vector.zig");
const pilot = @import("../../../../mechanics/server/bot_pilot.zig");
const Ref = @import("../../../../mechanics/domain/world_references.zig").Ref;

/// Further than this from the leader for `far_ms`: catch up.
const far_distance: f32 = 1536;
const far_ms: i64 = 3000;
/// Further than this without closing in for `stuck_ms`: catch up.
const stuck_distance: f32 = 512;
const stuck_ms: i64 = 8000;
/// Closing in by this much counts as headway.
const headway: f32 = 64;
/// In lava or slime this long (or with no way out found): catch up.
const liquid_ms: i64 = 2500;
/// Under water with this little air left: catch up.
const air_margin_ms: i64 = 2500;
/// Between placement attempts while nowhere hidden is free.
const retry_ms: i64 = 500;
/// Cosine of the half-angle of the leader's view treated as seen (65
/// degrees: a wide screen's field of view and a margin).
const view_cos: f32 = 0.42;

pub const Reason = enum { none, far, stuck, liquid, drowning };
pub const State = struct {
    /// Nearest it has been to the leader lately, and when it got there.
    best: f32 = std.math.inf(f32),
    best_ms: i64 = 0,
    far_since: ?i64 = null,
    liquid_since: ?i64 = null,
    next_try_ms: i64 = 0,
};
/// What the companion's situation looks like this frame.
pub const Observation = struct {
    now: i64,
    /// Free to follow (no order, authored hold, cinematic or carrying keeps it).
    eligible: bool,
    distance: f32,
    in_harmful_liquid: bool = false,
    escape_failed: bool = false,
    submerged: bool = false,
    air_left_ms: i64 = std.math.maxInt(i64),
    /// In water the leader is not in: stuck there counts however near.
    misplaced: bool = false,
};

/// Whether the companion is due to catch up, and why.
pub fn due(state: *State, seen: Observation) Reason {
    if (!seen.eligible) {
        state.* = .{ .next_try_ms = state.next_try_ms };
        return .none;
    }
    if ((seen.distance < stuck_distance and !seen.misplaced) or seen.distance < state.best - headway or state.best_ms == 0) {
        state.best = seen.distance;
        state.best_ms = seen.now;
    }
    if (seen.distance > far_distance) {
        if (state.far_since == null) state.far_since = seen.now;
    } else state.far_since = null;
    if (seen.in_harmful_liquid) {
        if (state.liquid_since == null) state.liquid_since = seen.now;
    } else state.liquid_since = null;
    if (seen.submerged and seen.air_left_ms <= air_margin_ms) return .drowning;
    if (state.liquid_since) |since| if (seen.escape_failed or seen.now - since >= liquid_ms) return .liquid;
    if (state.far_since) |since| if (seen.now - since >= far_ms) return .far;
    if ((seen.distance > stuck_distance or seen.misplaced) and seen.now - state.best_ms >= stuck_ms) return .stuck;
    return .none;
}

/// Whether the leader, looking along `view` from `eye`, sees `point`.
pub fn inView(collision: anytype, slot: u16, eye: v.Vec3, view: v.Vec3, point: v.Vec3) !bool {
    const offset = v.subtract(point, eye);
    if (v.length(offset) < 1) return true;
    if (v.dot(v.normalize(offset), view) < view_cos) return false;
    // Head, chest and feet of a standing body.
    for ([_]f32{ 28, 8, -20 }) |height| {
        const target = v.add(point, .{ 0, 0, height });
        const line = try collision.trace(.{ .start = eye, .end = target, .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = @as(u32, c.MASK_OPAQUE) });
        if (line.fraction == 1) return true;
    }
    return false;
}

/// Catch up when due: true when the companion was put down beside the leader.
pub fn step(state: *State, frame: pilot.Frame, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, owner: Ref, leader: data.Transform, leader_state: ?data.Player, trail: []const v.Vec3, report: pilot.Report, now: i64) !bool {
    const world = frame.world;
    const companion = try world.get(entity, data.Companion);
    const body = (try world.get(entity, data.Body)).*;
    const health = (try world.get(entity, data.Health)).*;
    const liquid = actor.liquid;
    const harmful = liquid.initialized and liquid.level > 0 and (liquid.kind == .lava or liquid.kind == .slime);
    const eligible = owner.world == world and health.current > 0 and companion.order == .follow and !companion.stopped and !companion.carrying and companion.collecting == 0 and companion.authored == .none and body.motion_owner == null and actor.scripted_pose == null and (world.get(entity, data.Performer) catch null) == null and !@import("../../../../mechanics/server/cinematics.zig").active(world) and (leader_state == null or leader_state.?.mode == .normal);
    const reason = due(state, .{
        .now = now,
        .eligible = eligible,
        .distance = v.length(v.subtract(leader.position, pose.position)),
        .in_harmful_liquid = harmful,
        .escape_failed = report.escape_failed,
        .submerged = frame.state.water_level == 3,
        .air_left_ms = if (liquid.initialized) liquid.air_until_ms - now else std.math.maxInt(i64),
        .misplaced = frame.state.water_level > 0 and !(if (leader_state) |player| player.water_level > 0 else false),
    });
    if (reason == .none or now < state.next_try_ms) return false;
    state.next_try_ms = now + retry_ms;
    const eye = v.add(leader.position, .{ 0, 0, if (leader_state) |player| player.view_height else 22 });
    const view = v.basis(leader.angles).forward;
    // Leaving in plain view is as jarring as arriving there; a rescue from
    // lava or drowning goes ahead regardless.
    const rescue = reason == .liquid or reason == .drowning;
    if (!rescue and try inView(frame.collision, frame.slot, eye, view, pose.position)) {
        pending(companion.identity, reason, "departure in view");
        return false;
    }
    const point = try hiddenSpot(frame, entity, leader, trail, eye, view) orelse {
        pending(companion.identity, reason, "no hidden spot");
        return false;
    };
    const from = pose.position;
    try @import("companion_triggers.zig").place(world, entity, actor, pose, point, now);
    const toward = v.subtract(leader.position, point);
    pose.angles = .{ 0, std.math.atan2(toward[1], toward[0]) * 180 / std.math.pi, 0 };
    if (engine.integer("developer") >= 1) {
        var text: [192]u8 = undefined;
        engine.print(std.fmt.bufPrintZ(&text, "dk3 sidekick: catch-up who={s} reason={s} from={d:.0},{d:.0},{d:.0} to={d:.0},{d:.0},{d:.0}\n", .{ @tagName(companion.identity), @tagName(reason), from[0], from[1], from[2], point[0], point[1], point[2] }) catch "dk3 sidekick: catch-up\n");
    }
    return true;
}

fn pending(identity: anytype, reason: Reason, why: []const u8) void {
    if (engine.integer("developer") < 2) return;
    var text: [128]u8 = undefined;
    engine.print(std.fmt.bufPrintZ(&text, "dk3 sidekick: catch-up pending who={s} reason={s} ({s})\n", .{ @tagName(identity), @tagName(reason), why }) catch "dk3 sidekick: catch-up pending\n");
}
/// Safe footing near the leader, behind it first, that the leader cannot
/// see and the companion's hull fits; else a spot the leader walked
/// recently that it cannot see.
fn hiddenSpot(frame: pilot.Frame, entity: ecs.Entity, leader: data.Transform, trail: []const v.Vec3, eye: v.Vec3, view: v.Vec3) !?v.Vec3 {
    // Behind the leader first, then round to its sides and ahead.
    const bearings = [_]f32{ 180, 150, 210, 120, 240, 90, 270, 60, 300, 30, 330, 0 };
    for ([_]f32{ 64, 112, 176, 256, 352 }) |radius| for (bearings) |bearing| {
        const angle = (leader.angles[1] + bearing) * std.math.pi / 180;
        const candidate = v.add(leader.position, .{ @cos(angle) * radius, @sin(angle) * radius, 0 });
        if (try hidden(frame, entity, leader, candidate, eye, view)) |spot| return spot;
    };
    for (trail) |crumb| if (try hidden(frame, entity, leader, crumb, eye, view)) |spot| return spot;
    return null;
}
fn hidden(frame: pilot.Frame, entity: ecs.Entity, leader: data.Transform, candidate: v.Vec3, eye: v.Vec3, view: v.Vec3) !?v.Vec3 {
    const body = (try frame.world.get(entity, data.Body)).*;
    const spot = try @import("companion_brain.zig").standable(frame, candidate, leader.position, false, leader.position) orelse return null;
    const clear = try frame.collision.trace(.{ .start = spot, .end = v.add(spot, .{ 0, 0, 6 }), .mins = body.mins, .maxs = body.maxs, .slot = frame.slot, .mask = body.collision_mask });
    if (clear.start_solid or clear.all_solid or clear.fraction < 1) return null;
    if (try inView(frame.collision, frame.slot, eye, view, spot)) return null;
    return spot;
}

const testing = std.testing;
test "a companion left far behind catches up after a while, not at once" {
    var state: State = .{};
    try testing.expectEqual(Reason.none, due(&state, .{ .now = 1000, .eligible = true, .distance = 2000 }));
    try testing.expectEqual(Reason.none, due(&state, .{ .now = 3000, .eligible = true, .distance = 2000 }));
    try testing.expectEqual(Reason.far, due(&state, .{ .now = 4000, .eligible = true, .distance = 2000 }));
}
test "a companion making headway toward the leader is not stuck" {
    var state: State = .{};
    var now: i64 = 0;
    var distance: f32 = 1200;
    while (now < 20000) : (now += 500) {
        try testing.expectEqual(Reason.none, due(&state, .{ .now = now, .eligible = true, .distance = distance }));
        distance -= 30;
    }
}
test "a companion that gets no nearer for eight seconds catches up" {
    var state: State = .{};
    try testing.expectEqual(Reason.none, due(&state, .{ .now = 100, .eligible = true, .distance = 800 }));
    try testing.expectEqual(Reason.none, due(&state, .{ .now = 7000, .eligible = true, .distance = 780 }));
    try testing.expectEqual(Reason.stuck, due(&state, .{ .now = 8200, .eligible = true, .distance = 790 }));
}
test "orders, stops and scripts hold a companion where it is" {
    var state: State = .{};
    try testing.expectEqual(Reason.none, due(&state, .{ .now = 100, .eligible = false, .distance = 4000 }));
    try testing.expectEqual(Reason.none, due(&state, .{ .now = 60000, .eligible = false, .distance = 4000 }));
    // Freed again, it waits out the full delay.
    try testing.expectEqual(Reason.none, due(&state, .{ .now = 60100, .eligible = true, .distance = 4000 }));
}
test "stuck in water the leader is not in catches up however near" {
    var state: State = .{};
    try testing.expectEqual(Reason.none, due(&state, .{ .now = 100, .eligible = true, .distance = 300, .misplaced = true }));
    try testing.expectEqual(Reason.stuck, due(&state, .{ .now = 8200, .eligible = true, .distance = 300, .misplaced = true }));
    var dry: State = .{};
    try testing.expectEqual(Reason.none, due(&dry, .{ .now = 100, .eligible = true, .distance = 300 }));
    try testing.expectEqual(Reason.none, due(&dry, .{ .now = 8200, .eligible = true, .distance = 300 }));
}
test "lava it cannot leave and air running out are rescued" {
    var state: State = .{};
    try testing.expectEqual(Reason.none, due(&state, .{ .now = 100, .eligible = true, .distance = 100, .in_harmful_liquid = true }));
    try testing.expectEqual(Reason.liquid, due(&state, .{ .now = 200, .eligible = true, .distance = 100, .in_harmful_liquid = true, .escape_failed = true }));
    var other: State = .{};
    try testing.expectEqual(Reason.none, due(&other, .{ .now = 0, .eligible = true, .distance = 100, .in_harmful_liquid = true }));
    try testing.expectEqual(Reason.liquid, due(&other, .{ .now = 2600, .eligible = true, .distance = 100, .in_harmful_liquid = true }));
    var water: State = .{};
    try testing.expectEqual(Reason.none, due(&water, .{ .now = 100, .eligible = true, .distance = 100, .submerged = true, .air_left_ms = 6000 }));
    try testing.expectEqual(Reason.drowning, due(&water, .{ .now = 200, .eligible = true, .distance = 100, .submerged = true, .air_left_ms = 2000 }));
}
