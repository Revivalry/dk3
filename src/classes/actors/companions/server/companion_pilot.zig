// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Companions flown by the shared bot pilot. The brain fills an intent; the
//! pilot plans it like the co-op bot (perception at the highest skill, aim,
//! fire discipline, dodging, hazard and drop safety, lift riding); this sink
//! runs the companion's own player motor with the class hull and speed and
//! leaves the trigger to the companion's weapon step. Planning state is
//! transient: keyed by persistent identity, never saved, and reset whenever
//! the companion was not flown for a while or changed worlds.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const c = abi.c;
const v = @import("../../../../core/domain/vector.zig");
const nav = @import("../../../../core/domain/navigation.zig");
const pilot = @import("../../../../mechanics/server/bot_pilot.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const Actors = @import("../../../../mechanics/server/actors.zig").Actors;

const BlockedMove = struct {
    since: ?i64 = null,
    position: v.Vec3 = @splat(0),
    destination: v.Vec3 = @splat(0),

    fn update(self: *BlockedMove, position: v.Vec3, destination: ?v.Vec3, eligible: bool, now: i64) bool {
        const goal = destination orelse {
            self.since = null;
            return false;
        };
        if (!eligible) {
            self.since = null;
            return false;
        }
        if (self.since == null or now < self.since.? or v.length(v.subtract(position, self.position)) > 8 or v.length(v.subtract(goal, self.destination)) > 8) {
            self.* = .{ .since = now, .position = position, .destination = goal };
            return false;
        }
        return now - self.since.? >= 1500;
    }
};

test "a blocked nearby Move requests recovery without a partial area endpoint" {
    const position: v.Vec3 = .{ 1771.482, -245.569, -743.875 };
    const goal: v.Vec3 = .{ 1719.097, -285.349, -730.565 };
    const step: nav.Waypoint = .{ .point = goal };
    var endpoint: nav.EndpointHold = .{};
    try std.testing.expect(!endpoint.update(position, goal, step, true, 100));
    try std.testing.expect(!endpoint.update(position, goal, step, true, 1600));
    var held: BlockedMove = .{};
    try std.testing.expect(!held.update(position, goal, true, 100));
    try std.testing.expect(!held.update(position, goal, true, 1500));
    try std.testing.expect(held.update(position, goal, true, 1600));
    try std.testing.expect(!held.update(v.add(position, .{ -12, 0, 0 }), goal, true, 1700));
    try std.testing.expect(!held.update(position, goal, false, 1800));
    try std.testing.expect(!held.update(position, goal, true, 1900));
    try std.testing.expect(!held.update(position, v.add(goal, .{ 0, 16, 0 }), true, 3500));
    try std.testing.expect(!held.update(position, null, true, 5100));
}

/// Cache the authored ground corridor only when ordinary area routing loses
/// the traveller. Qualify each leg against the live motor, not saved geometry.
const Corridor = struct {
    points: [256]v.Vec3 = undefined,
    count: usize = 0,
    cursor: usize = 0,
    goal: v.Vec3 = @splat(0),
    qualified: ?v.Vec3 = null,
    stroke: ?v.Vec3 = null,
    transfer: bool = false,
    detouring: bool = false,
    retry_ms: i64 = 0,
    progress_ms: i64 = 0,
    mark: v.Vec3 = @splat(0),
    closest: f32 = std.math.inf(f32),

    fn abandon(self: *Corridor, now: i64) void {
        self.count = 0;
        self.qualified = null;
        self.stroke = null;
        self.transfer = false;
        self.detouring = false;
        self.retry_ms = now + 1000;
    }
    fn trailEnd(brain: *const @import("companion_brain.zig").State, wanted: v.Vec3) usize {
        if (brain.crumb_count < 2) return 0;
        if (v.length(v.subtract(brain.footing(brain.crumb_count - 1), wanted)) <= 256) return brain.crumb_count;
        // Move may request a landing the leader has already left. Retain
        // the observed route to that landing without following him beyond it.
        var end = brain.crumb_count;
        while (end > 1) {
            if (v.length(v.subtract(brain.footing(end - 1), wanted)) <= 48) return end;
            end -= 1;
        }
        return 0;
    }
    fn copyTrail(self: *Corridor, brain: *const @import("companion_brain.zig").State, first: usize, end: usize) usize {
        const length = end - first;
        for (self.points[0..length], first..end) |*point, index| point.* = brain.footing(index);
        return length;
    }
    fn fromTrail(self: *Corridor, at: pilot.Frame, position: v.Vec3, wanted: v.Vec3, brain: *const @import("companion_brain.zig").State) !usize {
        const end = trailEnd(brain, wanted);
        if (end < 2) return 0;
        // Join a recent nearby part of the walked trail. An older supply
        // detour can pass a little closer to the same stair than its later
        // clean ascent; repeatedly joining that detour never reaches the goal.
        // Motor qualification still rejects shortcuts across overhead turns.
        var nearest: [8]struct { index: usize, distance: f32 } = undefined;
        var count: usize = 0;
        for (0..end - 1) |index| {
            const point = brain.footing(index);
            const distance = v.length(v.subtract(point, position));
            if (distance < 16 or distance > 224 or @abs(point[2] - position[2]) > 72) continue;
            const rank = distance + @as(f32, @floatFromInt(end - 1 - index)) * 2;
            var insert: usize = 0;
            while (insert < count and nearest[insert].distance < rank) : (insert += 1) {}
            if (insert == nearest.len) continue;
            var shift = @min(count, nearest.len - 1);
            while (shift > insert) : (shift -= 1) nearest[shift] = nearest[shift - 1];
            nearest[insert] = .{ .index = index, .distance = rank };
            count = @min(count + 1, nearest.len);
        }
        // Among nearby joins, prefer progress along the walked trail. A
        // reachable earlier tread must not suppress the short detour around
        // the next corner and repeatedly lead the traveller down again.
        for (0..count) |index| {
            var cursor = index;
            while (cursor > 0 and nearest[cursor].index > nearest[cursor - 1].index) : (cursor -= 1)
                std.mem.swap(@TypeOf(nearest[0]), &nearest[cursor], &nearest[cursor - 1]);
        }
        for (nearest[0..count], 0..) |candidate, ordinal| {
            if (try pilot.motorFooting(at, position, brain.footing(candidate.index))) |arrival| {
                const length = self.copyTrail(brain, candidate.index, end);
                // Retain this body's reachable joining stance instead of
                // tracing the narrower leader's embedded centre again.
                self.points[0] = arrival;
                return length;
            }
            if (ordinal >= 2) continue;
            const approach = try pilot.groundDetourNear(at, position, brain.footing(candidate.index), self.points[0..128], 48);
            if (approach > 0) {
                const length = end - candidate.index;
                for (self.points[approach..][0..length], candidate.index..end) |*point, index| point.* = brain.footing(index);
                return approach + length;
            }
            // A recent landing across a clear gap takes precedence over an
            // older reachable bank. The corridor still asks the shared pilot
            // to qualify the real jump before any departure is authorized.
            const point = brain.footing(candidate.index);
            const across = nav.horizontalDistance(position, point);
            if (across >= 48 and across <= 240 and pilot.transferHeightAllowed(position[2], point[2])) {
                const clear = try at.collision.trace(.{ .start = v.add(position, .{ 0, 0, 18 }), .end = v.add(point, .{ 0, 0, 18 }), .mins = at.hull.mins, .maxs = at.hull.maxs, .slot = at.slot, .mask = at.motionMask() & ~@as(u32, c.CONTENTS_BODY) });
                if (!clear.start_solid and !clear.all_solid and clear.fraction == 1) return self.copyTrail(brain, candidate.index, end);
            }
        }
        // A walked trail can start across a short gap from the waiting
        // companion. Feed that same-height approach through the corridor's
        // existing transfer path: support is checked below, and the shared
        // pilot must qualify an actual jump before it can leave the bank.
        for (nearest[0..count]) |candidate| {
            if (@abs(brain.footing(candidate.index)[2] - position[2]) > 24) continue;
            return self.copyTrail(brain, candidate.index, end);
        }
        return 0;
    }
    fn next(self: *Corridor, at: pilot.Frame, position: v.Vec3, destination: ?v.Vec3, lost: bool, trail: ?*const @import("companion_brain.zig").State) !?v.Vec3 {
        const wanted = destination orelse {
            self.abandon(at.now);
            return null;
        };
        // A stranded brain can temporarily hold its own position. Keep the
        // corridor's original goal through that retry, but respect a new one.
        if (self.count > 0 and v.length(v.subtract(wanted, position)) > 48 and v.length(v.subtract(wanted, self.goal)) > 192) self.abandon(at.now);
        if (self.count == 0) {
            if (!lost or at.now < self.retry_ms or v.length(v.subtract(wanted, position)) < 48) return null;
            self.retry_ms = at.now + 1000;
            self.count = 0;
            // Prefer the leader's actually walked corridor to a new floor
            // search. Close overlapping turns can otherwise offer a shorter
            // route to the underside of the same destination.
            if (trail) |brain| {
                self.count = try self.fromTrail(at, position, wanted, brain);
            }
            if (self.count == 0) self.count = try pilot.groundDetourNear(at, position, wanted, &self.points, 48);
            if (self.count == 0) self.count = @import("../../../../mechanics/server/authored_nodes.zig").route(position, wanted, &self.points, &.{}) catch 0;
            self.cursor = 0;
            self.goal = wanted;
            self.mark = position;
            self.progress_ms = at.now;
            if (self.count == 0) return null;
        }
        while (self.cursor < self.count) {
            if (self.qualified) |point| {
                // Jumping against a pillar moves the body but makes no route
                // progress. Only getting closer to this leg renews its budget.
                const distance = v.length(v.subtract(position, point));
                if (distance + 8 < self.closest) {
                    self.closest = distance;
                    self.progress_ms = at.now;
                } else if (at.now - self.progress_ms > 2500) {
                    self.abandon(at.now);
                    return null;
                }
                // These points already carry a live supported stance. A
                // whole-step tolerance skips a stair while still below it,
                // handing the next leg an unsupported starting height.
                // A wider standing hull can already rest on the next tread
                // while its centre is still over this one. Admit that upward
                // contact, but retain the strict check when still below the
                // requested tread; that must not skip an unfinished ascent.
                // A ground stroke brakes into a two-unit arrival disk. A
                // wider early handoff can discard its lateral correction
                // while still standing on a nearby raised prop.
                const arrival_radius: f32 = if (self.transfer) 12 else 2;
                if (nav.horizontalDistance(position, point) > arrival_radius or point[2] - position[2] > 8 or position[2] - point[2] > 20) return point;
                // Passing through a transfer's arrival disk while airborne
                // is not a landing. Keep its flight controller until actual
                // support instead of replacing it with the next walking leg.
                if (at.state.ground_entity == c.ENTITYNUM_NONE) return point;
                self.qualified = null;
                self.stroke = null;
                self.transfer = false;
                if (!self.detouring) self.cursor += 1;
                self.detouring = false;
                continue;
            }
            // A supplied intermediate node can be embedded in a stair or
            // ornament. A later node is usable only if the complete direct
            // motor rollout from here proves its live corridor safe.
            var transfer: ?struct { point: v.Vec3, cursor: usize } = null;
            for (self.cursor..@min(self.count, self.cursor + 8)) |candidate| {
                const raw = self.points[candidate];
                if (nav.horizontalDistance(position, raw) > 256) continue;
                const contact = try at.collision.trace(.{ .start = position, .end = raw, .mins = at.hull.mins, .maxs = at.hull.maxs, .slot = at.slot, .mask = at.motionMask() & ~@as(u32, c.CONTENTS_BODY) });
                if (contact.fraction < 1 and contact.entity < at.slots.occupants.len) if (at.slots.occupants[contact.entity]) |obstacle| {
                    const object = at.world.get(obstacle, data.MapObject) catch null;
                    if (object) |description| if (@import("../../../../mechanics/server/entity_classes/registry.zig").traitsOf(description.classname).door != .none) {
                        const near = v.add(contact.end, v.scale(contact.normal, 8));
                        if (nav.horizontalDistance(position, near) > 8) if (try pilot.motorRoute(at, position, near)) |point| return point;
                    };
                };
                // The motor can crouch through a low stair turn. A standing
                // floor query must not discard that foothold before the
                // motor gets the chance to qualify its crouched approach.
                for ([_]f32{ at.hull.maxs[2], 4 }) |height| {
                    var floor_maxs = at.hull.maxs;
                    floor_maxs[2] = height;
                    for ([_]f32{ 2, 8, 24, 64 }) |lift| {
                        const supported = try @import("../../../../core/domain/navigation_input.zig").supportedPoint(at.collision, .{
                            .start = v.add(raw, .{ 0, 0, lift }),
                            .end = v.add(raw, .{ 0, 0, -48 }),
                            .mins = at.hull.mins,
                            .maxs = floor_maxs,
                            .slot = at.slot,
                            .mask = at.motionMask() & ~@as(u32, c.CONTENTS_BODY),
                        });
                        const floor = supported.floor orelse continue;
                        const point = try pilot.motorFooting(at, position, floor.end) orelse {
                            if (transfer == null and nav.horizontalDistance(position, floor.end) <= 240 and pilot.transferHeightAllowed(position[2], floor.end[2])) transfer = .{ .point = floor.end, .cursor = candidate };
                            continue;
                        };
                        self.cursor = candidate;
                        self.qualified = point;
                        // motorFooting forecasts steering at floor.end and
                        // admits the actual supported arrival nearby. Aiming
                        // at that arrival instead changes the curved path.
                        self.stroke = floor.end;
                        if (!@import("builtin").is_test and @import("../../../../engine/server.zig").integer("developer") >= 3) {
                            var text: [256]u8 = undefined;
                            @import("../../../../engine/server.zig").print(try std.fmt.bufPrintZ(&text, "dk3 companion leg: t={d} cursor={d}/{d} raw={d:.2},{d:.2},{d:.2} floor={d:.2},{d:.2},{d:.2} arrival={d:.2},{d:.2},{d:.2}\n", .{ at.now, candidate, self.count, raw[0], raw[1], raw[2], floor.end[0], floor.end[1], floor.end[2], point[0], point[1], point[2] }));
                        }
                        self.closest = std.math.inf(f32);
                        self.progress_ms = at.now;
                        break;
                    }
                    if (self.qualified != null) break;
                }
                if (self.qualified != null) break;
            }
            if (self.qualified == null) if (transfer) |candidate| {
                // The leader's hull can pass a corner that this traveller
                // must round on another tread. Recover that local floor
                // connection before treating the gap as a jumping transfer.
                var detour: [128]v.Vec3 = undefined;
                const length = try pilot.groundDetourNear(at, position, candidate.point, &detour, 48);
                for (detour[0..length]) |footing| {
                    if (nav.horizontalDistance(position, footing) < 12) continue;
                    const point = try pilot.motorFooting(at, position, footing) orelse continue;
                    if (nav.horizontalDistance(position, point) < 8) continue;
                    self.qualified = point;
                    self.stroke = footing;
                    self.detouring = true;
                    self.closest = std.math.inf(f32);
                    self.progress_ms = at.now;
                    return point;
                }
                self.cursor = candidate.cursor;
                self.qualified = candidate.point;
                self.stroke = null;
                self.closest = std.math.inf(f32);
                self.progress_ms = at.now;
                self.transfer = true;
            };
            if (self.qualified == null) {
                self.abandon(at.now);
                return null;
            }
        }
        self.abandon(at.now);
        return null;
    }
};

test "an intermediate Move keeps its observed landing after the leader advances" {
    var brain: @import("companion_brain.zig").State = .{};
    const footing = [_]v.Vec3{ .{ 226, 703, -936 }, .{ 226, 505, -912 }, .{ 208, 374, -948 }, .{ 208, 192, -936 } };
    @memcpy(brain.crumbs[0..footing.len], &footing);
    brain.crumb_count = footing.len;
    brain.crumb_cursor = footing.len;
    const end = Corridor.trailEnd(&brain, .{ 242, 496, -912 });
    try std.testing.expectEqual(@as(usize, 2), end);
    var corridor: Corridor = .{};
    try std.testing.expectEqual(@as(usize, 2), corridor.copyTrail(&brain, 0, end));
    try std.testing.expectEqual(footing[1], corridor.points[1]);
    try std.testing.expectEqual(footing.len, Corridor.trailEnd(&brain, footing[3]));
    try std.testing.expectEqual(@as(usize, 0), Corridor.trailEnd(&brain, .{ 900, 900, 24 }));
}

test "cached ground corridor survives a stranded hold and expires without progress or on a new goal" {
    const testing = std.testing;
    var at: pilot.Frame = undefined;
    at.now = 100;
    var corridor: Corridor = .{ .count = 1, .qualified = .{ 80, 0, 24 }, .goal = .{ 400, 0, 24 }, .progress_ms = 100 };
    const position: v.Vec3 = .{ 0, 0, 24 };
    try testing.expectEqual(v.Vec3{ 80, 0, 24 }, (try corridor.next(at, position, position, false, null)).?);
    at.now = 2700;
    try testing.expectEqual(@as(?v.Vec3, null), try corridor.next(at, position, position, false, null));
    try testing.expectEqual(@as(usize, 0), corridor.count);
    try testing.expectEqual(@as(i64, 3700), corridor.retry_ms);
    corridor = .{ .count = 1, .qualified = .{ 80, 0, 24 }, .goal = .{ 400, 0, 24 }, .progress_ms = 2700 };
    try testing.expectEqual(@as(?v.Vec3, null), try corridor.next(at, position, .{ -400, 0, 24 }, false, null));
    try testing.expectEqual(@as(usize, 0), corridor.count);
}

test "ground corridor retains a stair point until the traveller reaches its supported height" {
    var at: pilot.Frame = undefined;
    at.now = 100;
    at.state = .{ .ground_entity = c.ENTITYNUM_NONE };
    const stair: v.Vec3 = .{ -246, -496, -792 };
    const aimed: v.Vec3 = .{ -250, -504, -792 };
    var corridor: Corridor = .{ .count = 1, .qualified = stair, .stroke = aimed, .goal = .{ -203, -309, -680 }, .progress_ms = 100 };
    try std.testing.expectEqual(stair, (try corridor.next(at, .{ -246, -496, -808 }, corridor.goal, false, null)).?);
    try std.testing.expectEqual(aimed, corridor.stroke.?);
    try std.testing.expectEqual(@as(usize, 0), corridor.cursor);
    try std.testing.expectEqual(stair, (try corridor.next(at, .{ -246, -496, -776 }, corridor.goal, false, null)).?);
    at.state.ground_entity = c.ENTITYNUM_WORLD;
    try std.testing.expectEqual(stair, (try corridor.next(at, .{ -255, -496, -776 }, corridor.goal, false, null)).?);
    try std.testing.expectEqual(aimed, corridor.stroke.?);
    try std.testing.expectEqual(@as(usize, 0), corridor.cursor);
    try std.testing.expectEqual(@as(?v.Vec3, null), try corridor.next(at, .{ -246, -496, -776 }, corridor.goal, false, null));
    try std.testing.expectEqual(@as(usize, 0), corridor.count);
    try std.testing.expectEqual(@as(?v.Vec3, null), corridor.stroke);
}
test "jumping in place cannot keep a blocked corridor alive" {
    var at: pilot.Frame = undefined;
    at.now = 100;
    const goal: v.Vec3 = .{ 128, 0, 24 };
    var corridor: Corridor = .{ .count = 1, .qualified = goal, .goal = goal, .progress_ms = 100 };
    _ = try corridor.next(at, .{ 0, 0, 24 }, goal, false, null);
    at.now = 2000;
    _ = try corridor.next(at, .{ 0, 0, 72 }, goal, false, null);
    at.now = 2700;
    try std.testing.expectEqual(@as(?v.Vec3, null), try corridor.next(at, .{ 0, 0, 24 }, goal, false, null));
    try std.testing.expectEqual(@as(usize, 0), corridor.count);
}

/// Companions see, react, turn and aim at the top of the bot ladder.
pub const skill_level = 10;
/// The trigger decision the companion weapon step consumes this frame.
pub const Output = struct { at_ms: i64 = -1, fire: bool = false, weapon: u5 = 0 };
pub const Entry = struct {
    id: u32 = 0,
    world: ?*data.World = null,
    last_ms: i64 = 0,
    pilot: pilot.Pilot = .{ .level = skill_level },
    intent: pilot.Intent = .{},
    report: pilot.Report = .{},
    output: Output = .{},
    brain: @import("companion_brain.zig").State = .{},
    status_ms: i64 = 0,
    gait: @import("../domain/companion_pose.zig").GaitFilter = .{},
    corridor: Corridor = .{},
    endpoint: nav.EndpointHold = .{},
    blocked_move: BlockedMove = .{},
};
var entries: [4]Entry = @splat(.{});

/// Keep physical door contact aimed along the active ground corridor even
/// when the area graph has no waypoint through the closed doorway.
pub fn corridorGoal(id: u32) ?v.Vec3 {
    const flown = find(id) orelse return null;
    return if (flown.corridor.cursor < flown.corridor.count) flown.corridor.points[flown.corridor.cursor] else null;
}

/// The companion's planning state, fresh after an absence, a rewind or a
/// world change (another area graph, other slots).
pub fn entry(world: *data.World, id: u32, identity: u8, now: i64) *Entry {
    var oldest: usize = 0;
    for (&entries, 0..) |*candidate, index| {
        if (candidate.id == id) {
            if (candidate.world != world or now < candidate.last_ms or now - candidate.last_ms > 500) start(candidate, world, id, identity);
            candidate.last_ms = now;
            return candidate;
        }
        if (candidate.last_ms < entries[oldest].last_ms or candidate.id == 0 and entries[oldest].id != 0) oldest = index;
    }
    const chosen = &entries[oldest];
    start(chosen, world, id, identity);
    chosen.last_ms = now;
    return chosen;
}
fn start(target: *Entry, world: *data.World, id: u32, identity: u8) void {
    target.* = .{ .id = id, .world = world };
    // The two companions break to opposite sides when strafing and detouring.
    target.pilot.vary(identity);
}
pub fn find(id: u32) ?*Entry {
    for (&entries) |*candidate| if (candidate.id == id and id != 0) return candidate;
    return null;
}
/// Placement and travel invalidate both planning and remembered footing.
pub fn forget(id: u32) void {
    const found = find(id) orelse return;
    found.pilot.reset();
    found.brain = .{};
    found.intent = .{};
    found.corridor = .{};
    found.endpoint = .{};
    found.output = .{};
}
/// An ordinary order replaces the task, not the route the leader walked.
/// In particular Come after Stay must retain the approach to a raised stair.
pub fn replan(id: u32) void {
    const found = find(id) orelse return;
    const previous = found.brain;
    forget(id);
    found.brain.crumbs = previous.crumbs;
    found.brain.crumb_count = previous.crumb_count;
    found.brain.crumb_cursor = previous.crumb_cursor;
    found.brain.crumb_ms = previous.crumb_ms;
    found.brain.leader_mark = previous.leader_mark;
}
/// A new map, a restore or shutdown: nothing planned survives.
/// Companion planning is transient (session_classes.zig).
pub const sessionReset = reset;
pub fn reset() void {
    entries = @splat(.{});
}
/// This frame's trigger decision, if the companion was flown this frame.
pub fn output(id: u32, now: i64) ?Output {
    const found = find(id) orelse return null;
    if (found.output.at_ms != now) return null;
    return found.output;
}

pub fn frame(actors: *const Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, service: nav.Service, definition: @import("../../../../mechanics/domain/actors.zig").Definition, now: i64) !pilot.Frame {
    const companion = try world.get(entity, data.Companion);
    const retaliation = if (companion.anger.retaliating) @import("../../../../mechanics/server/region_access.zig").find(world, companion.owner) else null;
    var result: pilot.Frame = .{
        .world = world,
        .slots = slots,
        .projections = projections,
        .service = service,
        .collision = @import("../../../../mechanics/server/actor_collision.zig").probe(),
        .table = &actors.weapons,
        .slot = (try world.get(entity, data.Binding)).slot,
        .entity = entity,
        .state = companion.motor,
        .hull = .{ .mins = definition.mins, .maxs = definition.maxs },
        .now = now,
        .region = true,
        .targets = if (retaliation) |target| .{ .specified = target } else .actors,
        .capabilities = .{ .controls = false, .operate_lifts = false, .passages = false, .exits = false, .use = false, .nuisance = false, .ignore_ambient = true, .duck_to_shoot = false, .careful_footing = true, .tread_water = true },
        .exclusion = .{ .context = actors, .mask = exclusion },
        // Companions keep out of anything that hurts, not only what kills.
        .hazard_damage = 5,
        .label = "sidekick",
    };
    if (companion.order == .follow and companion.authored == .none) if (@import("../../../../mechanics/server/region_access.zig").find(world, companion.owner)) |owner| if (owner.get(data.Player) catch null) |leader| {
        if (leader.water_level == 0) result.liquid_mask |= c.CONTENTS_WATER;
    };
    return result;
}
fn exclusion(context: *const anyopaque, at: pilot.Frame, enemy: ?v.Vec3) anyerror!i32 {
    const actors: *const Actors = @ptrCast(@alignCast(context));
    return @import("companion_weapons.zig").excluded(at.world, at.entity, actors.episode, enemy);
}

/// Plan the brain's intent and move the companion with its own player motor.
pub fn drive(actors: *const Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: *data.Transform, body: *data.Body, velocity: *data.Velocity, service: nav.Service, definition: @import("../../../../mechanics/domain/actors.zig").Definition, speed: f32, now: i64, elapsed: u32) !void {
    const movement = @import("../../../../mechanics/domain/player_move.zig");
    const companion = try world.get(entity, data.Companion);
    if (companion.parked) {
        velocity.linear = @splat(0);
        companion.motor.command_ms = now;
        actor.route = .{};
        return;
    }
    // Forecasts must see the same command interval as the eventual motor.
    // A monitor/cinematic can leave an old command timestamp while actors
    // are paused. Clamping only after steering makes its safety forecasts
    // simulate the pause as one long movement command and reject safe steps.
    companion.motor.command_ms = @max(companion.motor.command_ms, now - elapsed);
    const id = try world.persistentId(entity);
    const flown = entry(world, id, @intFromEnum(companion.identity), now);
    var plan_frame = try frame(actors, world, slots, projections, entity, service, definition, now);
    const hull = try motorHull(body.*, .{ .mins = definition.mins, .maxs = definition.maxs }, pose.position, plan_frame.slot, plan_frame.collision);
    plan_frame.hull = hull;
    const parameters: movement.Parameters = .{ .speed = speed, .jump_speed = definition.upward_speed, .slot = plan_frame.slot, .mask = body.collision_mask, .water_mask = c.MASK_WATER, .solid_mask = c.CONTENTS_SOLID, .currents = @import("../../../../mechanics/player_state.zig").currents, .mins = hull.mins, .maxs = hull.maxs, .snap_velocity = false };
    plan_frame.motor = parameters;
    var intent = flown.intent;
    if ((companion.order == .follow or companion.order == .come or companion.order == .move) and companion.authored == .none and !companion.stopped and !companion.anger.retaliating and companion.collecting == 0 and flown.report.enemy == 0) {
        const held_endpoint = flown.endpoint.update(pose.position, intent.destination, flown.report.waypoint, companion.motor.ground_entity != c.ENTITYNUM_NONE, now);
        // A nearby blocked Move can have a valid area waypoint at its goal
        // while its small height difference bypasses raised-approach recovery.
        // Give the existing qualified corridor a chance after actual stasis.
        const held_move = flown.blocked_move.update(pose.position, intent.destination, companion.order == .move and companion.motor.ground_entity != c.ENTITYNUM_NONE and companion.motor.water_level == 0 and flown.report.blocked, now);
        // Recover a raised, indirect approach before ordinary graph steering
        // can take an unsupported chord across a curved stair. Waiting for
        // a no-route report is too late once the traveller has fallen off.
        const raised_approach = if (intent.destination) |goal|
            companion.motor.ground_entity != c.ENTITYNUM_NONE and companion.motor.water_level == 0 and
                @abs(goal[2] - pose.position[2]) > 18 and nav.horizontalDistance(goal, pose.position) > 48 and
                !try pilot.walkable(plan_frame, pose.position, goal)
        else
            false;
        if (try flown.corridor.next(plan_frame, pose.position, intent.destination, flown.report.no_route or flown.report.routeless or held_endpoint or held_move or raised_approach, &flown.brain)) |point| {
            intent.destination = point;
            intent.direct = !flown.corridor.transfer;
            intent.authored_corridor = !flown.corridor.transfer;
            if (!flown.corridor.transfer) intent.ground_stroke = flown.corridor.stroke orelse point;
            if (flown.corridor.transfer) plan_frame.transfer_goal = point;
            intent.brake = true;
            intent.leash = null;
        }
    } else {
        flown.corridor = .{};
        flown.endpoint = .{};
        flown.blocked_move = .{};
    }
    // Another traveller's head is temporary support, not a stair landing.
    // The ordinary floor route refuses its56-unit descent and can leave a
    // companion standing on its owner forever. Walk toward the nearby clear
    // destination with the actual motor; the command guard below still
    // checks the complete descent, hazards and collisions.
    if (intent.destination) |goal| if (companion.motor.ground_entity < slots.occupants.len) {
        if (slots.occupants[companion.motor.ground_entity]) |support| {
            const support_body = world.get(support, data.Body) catch null;
            const descent = pose.position[2] - goal[2];
            if (support_body != null and support_body.?.contents & c.CONTENTS_BODY != 0 and
                descent > 18 and descent <= 80 and nav.horizontalDistance(pose.position, goal) <= 128)
            {
                intent.direct = true;
                intent.authored_corridor = true;
                intent.brake = true;
            }
        }
    };
    const steering = try flown.pilot.steer(plan_frame, intent);
    if (@import("../../../../engine/server.zig").integer("developer") >= 3 and @mod(now, 1000) == 0) {
        var text: [320]u8 = undefined;
        const point = intent.destination orelse pose.position;
        @import("../../../../engine/server.zig").print(try std.fmt.bufPrintZ(&text, "dk3 companion corridor: t={d} count={d} cursor={d} retry={d} progress={d} transfer={d} direct={d} goal={d:.1},{d:.1},{d:.1}\n", .{ now, flown.corridor.count, flown.corridor.cursor, flown.corridor.retry_ms, flown.corridor.progress_ms, @intFromBool(flown.corridor.transfer), @intFromBool(intent.direct), point[0], point[1], point[2] }));
    }
    flown.report = steering.report;
    // The shared pilot qualifies empty-weapon melee too. Do not force an
    // attack after it has rejected the owner's body in the striking lane.
    const command = steering.command;
    flown.output = .{ .at_ms = now, .fire = command.attack, .weapon = command.weapon };
    // The weapon step checks its leader-safety lane against this frame's target.
    if (flown.intent.fight) actor.threat = steering.report.enemy;
    if (@import("../../../../engine/server.zig").integer("developer") >= 1 and now >= flown.status_ms) {
        flown.status_ms = now + 1000;
        const health = (try world.get(entity, data.Health)).*;
        const destination = flown.intent.destination orelse pose.position;
        const waypoint = if (steering.report.waypoint) |point| point.point else pose.position;
        var liquid_text: [32]u8 = undefined;
        const liquid = std.fmt.bufPrint(&liquid_text, "water={d} escaping={d}", .{ companion.motor.water_level, @as(u8, @intFromBool(steering.report.escaping)) + @as(u8, @intFromBool(steering.report.escape_failed)) * 2 }) catch "";
        var text: [512]u8 = undefined;
        @import("../../../../engine/server.zig").print(std.fmt.bufPrintZ(&text, "dk3 sidekick: t={d} who={s} health={d}/{d} pos={d:.0},{d:.0},{d:.0} goal={d:.0},{d:.0},{d:.0} leash={d} fire={s} enemy={d} range={d:.0} fired={d} dodging={d} avoided={d} weapon={d} waypoint={d:.0},{d:.0},{d:.0} blocked={d} no_route={d} routeless={d} ground={d} {s} lost={d} stranded={d} retracing={d} routable={d} collecting={d} why={s}\n", .{ now, @tagName(companion.identity), health.current, health.maximum, pose.position[0], pose.position[1], pose.position[2], destination[0], destination[1], destination[2], @intFromBool(flown.intent.leash != null), @tagName(flown.intent.fire), steering.report.enemy, steering.report.enemy_distance, @intFromBool(command.attack), @intFromBool(steering.report.dodging), steering.report.avoided_exit, command.weapon, waypoint[0], waypoint[1], waypoint[2], @intFromBool(steering.report.blocked), @intFromBool(steering.report.no_route), @intFromBool(steering.report.routeless), companion.motor.ground_entity, liquid, if (flown.brain.lost_ms) |since| now - since else -1, @max(0, flown.brain.stranded_until - now), @intFromBool(flown.brain.retracing), @intFromBool(flown.brain.routable != null), companion.collecting, flown.brain.why }) catch "dk3 sidekick: status\n");
    }
    // Item pursuit judges reachability by the route's progress.
    actor.route = flown.pilot.route;
    pose.angles = .{ command.angles[0], command.angles[1], 0 };
    var input: movement.Command = .{ .time_ms = now, .angles = .{ command.angles[0], command.angles[1], 0 }, .forward = command.forward, .right = command.right, .up = command.up };
    if (body.motion_owner != null) input = .{ .time_ms = now, .angles = input.angles };
    companion.motor.mode = if (body.motion_owner != null) .frozen else .normal;
    var motion: @import("../../../../core/domain/slide.zig").State = .{ .position = pose.position, .velocity = velocity.linear };
    // A ground stroke or planned flight already qualifies its complete
    // feedback-steered movement, including braking at the destination.
    // The drop guard predicts a held command instead; applying it to that
    // flight can replace its qualified takeoff with an unrelated sidestep.
    // Keep it for unqualified strides, coasting and unplanned falls.
    if (body.motion_owner == null and !flown.intent.direct and intent.ground_stroke == null and flown.pilot.runup == null and flown.pilot.flight == null and companion.motor.water_level < 2 and (companion.motor.ground_entity == c.ENTITYNUM_NONE or input.up > 0 or input.forward != 0 or input.right != 0 or nav.horizontalDistance(motion.velocity, @splat(0)) > 48)) {
        const proposed = input;
        const forbidden = plan_frame.liquid_mask & (if (companion.motor.water_level > 0) ~@as(u32, c.CONTENTS_WATER) else std.math.maxInt(u32));
        const goal = if (steering.report.waypoint) |waypoint| waypoint.point else flown.intent.destination;
        const descent = if (goal) |point| @max(32, motion.position[2] - point[2] + 24) else 32;
        input = try @import("../../../../mechanics/domain/motion_forecast.zig").protectDrop(companion.motor, motion, input, parameters, @import("../../../../mechanics/server/actor_collision.zig").probe(), forbidden, goal, descent);
        if ((input.forward != proposed.forward or input.right != proposed.right or input.up != proposed.up) and @import("../../../../engine/server.zig").integer("developer") >= 2) {
            var text: [192]u8 = undefined;
            @import("../../../../engine/server.zig").print(try std.fmt.bufPrintZ(&text, "dk3 landing guard: who={s} t={d} pos={d:.0},{d:.0},{d:.0} input={d},{d},{d} guarded={d},{d},{d}\n", .{ @tagName(companion.identity), now, pose.position[0], pose.position[1], pose.position[2], proposed.forward, proposed.right, proposed.up, input.forward, input.right, input.up }));
        }
    }
    const prior_motor = companion.motor;
    const prior_motion = motion;
    const result = try movement.run(&companion.motor, &motion, input, parameters, @import("../../../../mechanics/server/actor_collision.zig").service());
    if (intent.ground_stroke != null and @import("../../../../engine/server.zig").integer("developer") >= 3 and @mod(now, 1000) == 0) {
        var predicted_player = prior_motor;
        var predicted_motion = prior_motion;
        var prediction_parameters = parameters;
        prediction_parameters.mask &= ~@as(u32, c.CONTENTS_BODY);
        _ = try movement.run(&predicted_player, &predicted_motion, input, prediction_parameters, @import("../../../../mechanics/server/actor_collision.zig").probe());
        var text: [384]u8 = undefined;
        @import("../../../../engine/server.zig").print(try std.fmt.bufPrintZ(&text, "dk3 companion motor comparison: t={d} ms={d} elapsed={d} before={d:.3},{d:.3},{d:.3} actual={d:.3},{d:.3},{d:.3} unoccupied={d:.3},{d:.3},{d:.3} input={d},{d},{d}\n", .{ now, prior_motor.command_ms, elapsed, prior_motion.position[0], prior_motion.position[1], prior_motion.position[2], motion.position[0], motion.position[1], motion.position[2], predicted_motion.position[0], predicted_motion.position[1], predicted_motion.position[2], input.forward, input.right, input.up }));
    }
    if (@import("../../../../engine/server.zig").integer("developer") >= 3 and (flown.pilot.flight != null or (companion.jump_started_ms > 0 and now - companion.jump_started_ms < 1800))) {
        var text: [320]u8 = undefined;
        @import("../../../../engine/server.zig").print(try std.fmt.bufPrintZ(&text, "dk3 actual jump: at={d} sample={d} elapsed={d} pos={d:.3},{d:.3},{d:.3} vel={d:.3},{d:.3},{d:.3} input={d},{d},{d} angles={d:.2},{d:.2} ground={d}\n", .{ now, companion.motor.command_ms, elapsed, motion.position[0], motion.position[1], motion.position[2], motion.velocity[0], motion.velocity[1], motion.velocity[2], input.forward, input.right, input.up, input.angles[0], input.angles[1], companion.motor.ground_entity }));
    }
    for (result.events[0..result.event_count]) |event| switch (event) {
        .jump => companion.jump_started_ms = now,
        else => {},
    };
    body.mins = result.mins;
    body.maxs = result.maxs;
    actor.ground_entity = companion.motor.ground_entity;
    body.grounded = actor.ground_entity != c.ENTITYNUM_NONE;
    pose.position = motion.position;
    velocity.linear = motion.velocity;
}

/// Old saves can place the smaller table hull under a lintel. Walk out with
/// that saved footprint before adopting the corrected standing hull; expanding
/// inside a solid would leave the motor unable to recover its initial pose.
fn motorHull(body: data.Body, desired: pilot.Hull, position: v.Vec3, slot: u16, service: @import("../../../../core/domain/collision.zig").Collision) !pilot.Hull {
    if (body.mins[0] == desired.mins[0] and body.mins[1] == desired.mins[1] and body.maxs[0] == desired.maxs[0] and body.maxs[1] == desired.maxs[1]) return desired;
    var maxs = desired.maxs;
    if (body.maxs[2] <= 4) maxs[2] = 4;
    const clearance = try service.trace(.{ .start = position, .end = position, .mins = desired.mins, .maxs = maxs, .slot = slot, .mask = body.collision_mask });
    if (!clearance.start_solid and !clearance.all_solid) return desired;
    var saved = body.maxs;
    if (saved[2] <= 4) saved[2] = desired.maxs[2];
    return .{ .mins = body.mins, .maxs = saved };
}

test "saved party footprint expands only after clearing its surrounding solids" {
    const collision = @import("../../../../core/domain/collision.zig");
    const Fixture = struct {
        blocked: bool = true,
        fn trace(raw: *anyopaque, request: collision.Request) !collision.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            return .{ .end = request.end, .normal = @splat(0), .fraction = if (self.blocked) 0 else 1, .start_solid = self.blocked };
        }
    };
    var fixture: Fixture = .{};
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Fixture.trace };
    const body: data.Body = .{ .mins = .{ -12, -12, -24 }, .maxs = .{ 12, 12, 30 } };
    const desired: pilot.Hull = .{ .mins = .{ -16, -16, -24 }, .maxs = .{ 16, 16, 32 } };
    try std.testing.expectEqual(body.maxs, (try motorHull(body, desired, @splat(0), 0, service)).maxs);
    fixture.blocked = false;
    try std.testing.expectEqualDeep(desired, try motorHull(body, desired, @splat(0), 0, service));
}

test "an unsupported authored staging hold preserves its pose until placement releases it" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    const entity = try world.create(7, .{ data.Companion{ .identity = .mikiko, .parked = true }, data.Actor{ .definition = 0 }, data.Transform{ .position = .{ 408, 1208, 54 } }, data.Velocity{ .linear = .{ 0, 0, -800 } }, data.Body{} });
    const actor = try world.get(entity, data.Actor);
    const pose = try world.get(entity, data.Transform);
    const velocity = try world.get(entity, data.Velocity);
    try drive(undefined, &world, undefined, &.{}, entity, actor, pose, try world.get(entity, data.Body), velocity, undefined, undefined, 320, 1000, 50);
    try std.testing.expectEqual(v.Vec3{ 408, 1208, 54 }, pose.position);
    try std.testing.expectEqual(v.Vec3{ 0, 0, 0 }, velocity.linear);
    try @import("companion_triggers.zig").place(&world, entity, actor, pose, .{ 32, 64, 24 }, 1050);
    try std.testing.expect(!(try world.get(entity, data.Companion)).parked);
    try std.testing.expectEqual(v.Vec3{ 32, 64, 24 }, pose.position);
}

test "companion planning state is per identity and fresh after an absence or a world change" {
    reset();
    defer reset();
    var first = data.World.init(std.testing.allocator, 1);
    defer first.deinit();
    var second = data.World.init(std.testing.allocator, 1);
    defer second.deinit();
    const mikiko = entry(&first, 7, 0, 1000);
    mikiko.pilot.target = 99;
    try std.testing.expectEqual(@as(u32, 99), entry(&first, 7, 0, 1050).pilot.target);
    try std.testing.expectEqual(@as(u32, 0), entry(&first, 7, 0, 1700).pilot.target);
    entry(&first, 7, 0, 1750).pilot.target = 99;
    try std.testing.expectEqual(@as(u32, 0), entry(&second, 7, 0, 1800).pilot.target);
    const superfly = entry(&first, 8, 1, 1800);
    try std.testing.expect(superfly != entry(&second, 7, 0, 1800));
    try std.testing.expectEqual(@as(i32, skill_level), superfly.pilot.level);
    try std.testing.expect(superfly.pilot.strafe_side != entry(&second, 7, 0, 1800).pilot.strafe_side);
    entry(&second, 7, 0, 1850).output = .{ .at_ms = 1850, .fire = true, .weapon = 3 };
    try std.testing.expect(output(7, 1850).?.fire);
    try std.testing.expectEqual(@as(?Output, null), output(7, 1900));
}
test "orders retain remembered footing while placement forgets it and both cancel firing" {
    reset();
    defer reset();
    var world = data.World.init(std.testing.allocator, 1);
    defer world.deinit();
    const flown = entry(&world, 7, 0, 1000);
    flown.brain.crumbs[0] = .{ 40, 80, 24 };
    flown.brain.crumb_count = 1;
    flown.brain.crumb_cursor = 1;
    flown.brain.crumb_ms = 1000;
    flown.brain.leader_mark = .{ 40, 80, 24 };
    flown.brain.retracing = true;
    flown.corridor.count = 1;
    flown.output = .{ .at_ms = 1000, .fire = true };
    replan(7);
    try std.testing.expectEqual(v.Vec3{ 40, 80, 24 }, flown.brain.footing(0));
    try std.testing.expectEqual(@as(i64, 1000), flown.brain.crumb_ms);
    try std.testing.expect(!flown.brain.retracing);
    try std.testing.expectEqual(@as(usize, 0), flown.corridor.count);
    try std.testing.expectEqual(@as(?Output, null), output(7, 1000));
    forget(7);
    try std.testing.expectEqual(@as(usize, 0), flown.brain.crumb_count);
    try std.testing.expectEqual(@as(?v.Vec3, null), flown.brain.leader_mark);
}
