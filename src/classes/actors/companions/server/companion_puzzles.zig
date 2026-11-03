// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Automatic physical duties offered by authored entity classes.
//! Walk onto the station, hold while its class asks, then follow again. No
//! target activation, teleport or elapsed-time guess replaces physical contact.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const v = @import("../../../../core/domain/vector.zig");
const nav = @import("../../../../core/domain/navigation.zig");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/server.zig");
const pilot = @import("../../../../mechanics/server/bot_pilot.zig");
const classes = @import("../../../../mechanics/server/entity_classes/registry.zig");
const access = @import("../../../../mechanics/server/region_access.zig");

pub fn available(companion: data.Companion) bool {
    return companion.enabled and !companion.carrying and !companion.stopped and companion.authored == .none and companion.order == .follow and !companion.collect_forced;
}

/// One helper owns a station even before reaching it. Both party members
/// remain free to take different stations when a map requires that.
fn claimed(world: *data.World, station: u32, self: ecs.Entity) !bool {
    var query = world.queryAccess(data.World.mask(.{data.Companion}), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.Companion)) |entity, state| {
        if (entity.index == self.index) continue;
        if (state.puzzle) |puzzle| if (puzzle.control == station and (try world.get(entity, data.Health)).current > 0) return true;
    };
    return false;
}

fn announce(identity: @import("actor_catalog").companions.Identity, holding: bool) void {
    var text: [160]u8 = undefined;
    engine.send(0, std.fmt.bufPrintZ(&text, "cp \"{s}: {s}\"", .{
        if (identity == .mikiko) "Mikiko" else "Superfly",
        if (holding) "I'll hold this switch. Go ahead." else "The way is open. I'm coming with you.",
    }) catch unreachable);
}

pub fn step(frame: pilot.Frame, entity: ecs.Entity, companion: *data.Companion, position: v.Vec3, leader: data.Transform, scan_ms: *i64, intent: *pilot.Intent) !bool {
    if (!available(companion.*)) {
        companion.puzzle = null;
        return false;
    }
    if (companion.puzzle == null and frame.now >= scan_ms.*) {
        scan_ms.* = frame.now + 500;
        var best_distance: f32 = 256;
        for (frame.slots.occupants) |maybe| {
            const station = maybe orelse continue;
            const offer = try classes.companionDuty(frame.world, station) orelse continue;
            const id = try frame.world.persistentId(station);
            if (offer.occupant != 0 and offer.occupant != try frame.world.persistentId(entity)) continue;
            if (try claimed(frame.world, id, entity)) continue;
            const center = v.scale(v.add(offer.mins, offer.maxs), 0.5);
            const distance = v.length(v.subtract(center, leader.position));
            if (distance >= best_distance or v.length(v.subtract(center, position)) > 1024) continue;
            // The owner has encountered this station, rather than a puzzle
            // on another floor or behind a wall in the same map.
            const eye = v.add(leader.position, .{ 0, 0, 22 });
            const visible = try frame.collision.trace(.{ .start = eye, .end = v.add(center, .{ 0, 0, 40 }), .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_SOLID });
            if (visible.start_solid or visible.fraction < 0.98) continue;
            var above = center;
            above[2] = offer.maxs[2] - frame.hull.mins[2] + 32;
            var below = above;
            below[2] = offer.mins[2] - 64;
            const floor = try frame.collision.trace(.{ .start = above, .end = below, .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = c.MASK_PLAYERSOLID });
            if (floor.start_solid or floor.all_solid or floor.fraction == 1 or floor.normal[2] < 0.7) continue;
            if (try frame.collision.contents(v.add(floor.end, .{ 0, 0, frame.hull.mins[2] + 1 }), frame.slot) & (c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO) != 0) continue;
            companion.puzzle = .{ .control = id, .point = floor.end };
            best_distance = distance;
        }
        if (companion.puzzle != null) {
            companion.collecting = 0;
            companion.yielding_until_ms = 0;
            announce(companion.identity, true);
        }
    }
    const puzzle = if (companion.puzzle) |*value| value else return false;
    const station = access.find(frame.world, puzzle.control);
    const offer = if (station) |ref| try classes.companionDuty(ref.world, ref.entity) else null;
    if (offer == null) {
        companion.puzzle = null;
        announce(companion.identity, false);
        return false;
    }
    puzzle.holding = offer.?.occupant == try frame.world.persistentId(entity);
    const distance = nav.horizontalDistance(position, puzzle.point);
    intent.* = .{
        .destination = if (distance > 4 or !puzzle.holding) puzzle.point else null,
        .direct = distance < 96,
        .brake = true,
        .fight = false,
        .fire = .hold,
        .close_in = false,
    };
    return true;
}

test "automatic duties respect explicit orders, carrying and authored scenes" {
    const t = std.testing;
    var state: data.Companion = .{ .identity = .mikiko };
    try t.expect(available(state));
    state.order = .stay;
    try t.expect(!available(state));
    state.order = .come;
    try t.expect(!available(state));
    state.order = .follow;
    state.carrying = true;
    try t.expect(!available(state));
    state.carrying = false;
    state.authored = .stop;
    try t.expect(!available(state));
}

test "stations have one living helper and cannot steal a second companion" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 8);
    defer world.deinit();
    const first = try world.create(null, .{ data.Companion{ .identity = .mikiko, .puzzle = .{ .control = 99, .point = @splat(0) } }, data.Health{ .current = 100 } });
    const second = try world.create(null, .{ data.Companion{ .identity = .superfly }, data.Health{ .current = 100 } });
    try t.expect(!try claimed(&world, 99, first));
    try t.expect(try claimed(&world, 99, second));
    try t.expect(!try claimed(&world, 100, second));
    (try world.get(first, data.Health)).current = 0;
    try t.expect(!try claimed(&world, 99, second));
}

test "old companions load without a duty and a held duty survives JSON and identity migration" {
    const t = std.testing;
    var old = try std.json.parseFromSlice(data.Companion, t.allocator, "{\"identity\":\"mikiko\"}", .{});
    defer old.deinit();
    try t.expectEqual(null, old.value.puzzle);
    old.value.puzzle = .{ .control = 99, .point = .{ 576, -3488, 304 }, .holding = true };
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, old.value, .{});
    defer t.allocator.free(bytes);
    var restored = try std.json.parseFromSlice(data.Companion, t.allocator, bytes, .{});
    defer restored.deinit();
    try restored.value.remapIds(@import("../../../../mechanics/domain/snapshot_ids.zig").Mapping{ .from = 99, .to = 199 });
    try t.expectEqual(@as(u32, 199), restored.value.puzzle.?.control);
    try t.expect(restored.value.puzzle.?.holding);
    try t.expectEqual(old.value.puzzle.?.point, restored.value.puzzle.?.point);
}
