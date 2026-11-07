// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: authoritative goal evaluation uses saved acquisition and target emission evidence.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const rules = @import("../domain/campaign_objectives.zig");
const v = @import("../../core/domain/vector.zig");
const c = @import("../../engine/abi.zig").c;
const engine = @import("../../engine/server.zig");
const Context = @import("world_context.zig").Context;

fn authored(world: *data.World, local: u24) ?ecs.Entity {
    return world.find((world.id_first & 0xff000000) | @as(u32, local));
}
pub fn satisfied(world: *data.World, keys: data.Keys, rule: rules.Rule, id: u24) bool {
    if (rule == .owned) return id > 0 and id <= 32 and keys.acquired(@intCast(id - 1));
    const entity = authored(world, id) orelse return rule == .broken or rule == .defeated;
    const object = world.get(entity, data.MapObject) catch return false;
    switch (rule) {
        .used, .exit => {
            if (object.objective_uses > 0) return true;
            if (world.get(entity, data.Trigger) catch null) |trigger| if (trigger.uses >= @max(1, trigger.limit)) return true;
            if (world.get(entity, data.WorldControl) catch null) |control| if (control.uses > 0) return true;
            if (world.get(entity, data.TargetSequence) catch null) |sequence| if (sequence.used) return true;
            // Saves made before the journal existed retain a mover's last user,
            // even after its button pops back out. An opening press has not fired yet.
            if (rule == .used) if (world.get(entity, data.Mover) catch null) |part| {
                const master = world.find(part.group) orelse entity;
                const mover = world.get(master, data.Mover) catch part;
                if (mover.owner != 0 and mover.state != .opening) return true;
            };
        },
        .taken => {
            if (object.objective_uses > 0) return true;
            if (world.get(entity, data.Pickup) catch null) |pickup| if (pickup.kind == .key) return keys.acquired(pickup.kind.key);
        },
        .broken => {
            if (world.get(entity, data.Destructible) catch null) |wall| if (wall.broken) return true;
            if (world.get(entity, data.Health) catch null) |health| return health.current <= 0;
        },
        .defeated => {
            if (world.get(entity, data.Health) catch null) |health| return health.current <= 0;
        },
        .owned => unreachable,
    }
    return false;
}
fn position(world: *data.World, entity: ecs.Entity) ?v.Vec3 {
    const pose = world.get(entity, data.Transform) catch return null;
    // Brush origins are often zero. Their admitted hull gives the actual panel/exit center.
    const body = world.get(entity, data.Body) catch return pose.position;
    return v.add(pose.position, v.scale(v.add(body.mins, body.maxs), 0.5));
}
fn add(view: *rules.View, goal: usize, point: v.Vec3) void {
    if (view.count == view.markers.len) return;
    view.markers[view.count] = .{ .goal = @intCast(goal), .rule = rules.forMap(view.name())[goal].rule, .position = point };
    view.count += 1;
}
pub fn evaluate(world: *data.World, name: []const u8, keys: data.Keys) rules.View {
    var result: rules.View = .{};
    const goals = rules.forMap(name);
    if (name.len >= result.map.len or goals.len == 0) return result;
    @memcpy(result.map[0..name.len], name);
    const ledger = if (world.find(world.id_first)) |entity| world.get(entity, data.MapObject) catch null else null;
    if (ledger) |entry| if (entry.objective_revision == rules.revision) {
        result.done = entry.objective_done;
    };
    for (goals, 0..) |goal, i| {
        if (result.complete(i)) {
            result.progress[i] = goal.required();
        } else if (goal.quantity > 0) {
            if (satisfied(world, keys, goal.rule, goal.ids[0])) {
                result.progress[i] = goal.required();
            } else if (authored(world, goal.ids[0])) |entity| {
                if (world.get(entity, data.Trigger) catch null) |counter| result.progress[i] = @intCast(@min(goal.quantity, counter.uses));
            }
        } else for (goal.ids[0..goal.count]) |id| if (satisfied(world, keys, goal.rule, id)) {
            result.progress[i] += 1;
        };
        if (result.progress[i] == goal.required()) result.done |= @as(u64, 1) << @intCast(i);
    }
    // A later, completed action on a return visit is evidence that an earlier
    // outbound leg was traversed, including saves predating departure counters.
    for (goals, 0..) |goal, i| if (goal.rule == .exit and !result.complete(i)) {
        for (goals[i + 1 ..], i + 1..) |later, j| if (later.stage > goal.stage and result.complete(j)) {
            result.done |= @as(u64, 1) << @intCast(i);
            result.progress[i] = goal.required();
            break;
        };
    };
    if (ledger) |entry| {
        entry.objective_done = result.done;
        entry.objective_revision = rules.revision;
    }
    const stage = result.stage();
    for (goals, 0..) |goal, i| {
        if (goal.stage != stage or result.complete(i)) continue;
        if (goal.quantity > 0) {
            // A death counter is backstage wiring. Mark its living inputs,
            // including dynamically spawned bodies, rather than inviting the
            // player to operate the hidden counter brush.
            if (authored(world, goal.ids[0])) |counter| {
                const name_ = (world.get(counter, data.MapObject) catch continue).targetname;
                if (name_.len == 0) continue;
                var inputs = world.queryAccess(data.World.mask(.{ data.MapObject, data.Health, data.Transform }), 0, 0);
                defer inputs.deinit();
                while (inputs.next()) |chunk| for (chunk.entities(), chunk.read(data.MapObject), chunk.read(data.Health)) |entity, object, health| {
                    if (health.current <= 0 or ((world.persistentId(entity) catch continue) & 0xff000000) != (world.id_first & 0xff000000)) continue;
                    const output = @import("properties.zig").text(object, "deathtarget") orelse continue;
                    if (!std.mem.eql(u8, output, name_)) continue;
                    if (position(world, entity)) |point| {
                        add(&result, i, point);
                        if (result.count > 0) result.markers[result.count - 1].rule = .defeated;
                    }
                };
            }
            continue;
        }
        for (goal.ids[0..goal.count]) |id| {
            if (satisfied(world, keys, goal.rule, id)) continue;
            if (goal.rule == .owned) {
                var query = world.queryAccess(data.World.mask(.{data.Pickup}), 0, 0);
                defer query.deinit();
                while (query.next()) |chunk| for (chunk.entities(), chunk.read(data.Pickup)) |entity, pickup| {
                    if (pickup.kind != .key or @as(u24, pickup.kind.key) + 1 != id) continue;
                    if (position(world, entity)) |point| add(&result, i, point);
                };
            } else if (authored(world, id)) |entity| {
                if (position(world, entity)) |point| add(&result, i, point);
            }
        }
    }
    return result;
}
// Where a missing inventory goal is authored. These are campaign facts, not item behavior.
const key_maps = [_][]const u8{
    "e1m6a", "e4m4a", "e4m4a", "e4m4b", "e1m3b", "",      "e3m4a", "e3m1c",
    "e3m1b", "e3m1c", "e3m4b", "e2m1c", "e3m4b", "e2m1c", "e4m1c", "e4m1c",
    "e4m1c", "e4m1a", "",      "",      "e2m4b", "e2m4c", "e2m4d", "e2m4d",
    "e2m4e", "e3m2a", "e3m1c", "e3m1c", "e3m3b", "e3m4a", "e3m5a", "e3m5a",
};
fn guideToMissingKey(active: *Context, view: *rules.View, keys: data.Keys) !void {
    if (view.count > 0) return;
    const access = @import("region_access.zig");
    const region = access.region orelse return;
    const manifest = region.manifest;
    const source = manifest.find(view.name()) orelse return;
    for (rules.forMap(view.name()), 0..) |goal, goal_index| {
        if (goal.rule != .owned or goal.stage != view.stage() or view.complete(goal_index)) continue;
        for (goal.ids[0..goal.count]) |id| {
            if (keys.acquired(@intCast(id - 1))) continue;
            const destination = manifest.find(key_maps[id - 1]) orelse continue;
            // Breadth-first traversal retains the first physical exit, including return routes.
            var queue: [128]u7 = undefined;
            var first: [128]u24 = @splat(0);
            var seen: [128]bool = @splat(false);
            queue[0] = source;
            seen[source] = true;
            var head: usize = 0;
            var tail: usize = 1;
            while (head < tail and !seen[destination]) : (head += 1) {
                const at = queue[head];
                for (manifest.edges[0..manifest.edge_count]) |edge| {
                    if (edge.source != at or seen[edge.destination]) continue;
                    first[edge.destination] = if (at == source) edge.exit else first[at];
                    seen[edge.destination] = true;
                    queue[tail] = edge.destination;
                    tail += 1;
                }
            }
            if (first[destination] != 0) if (authored(&active.world.?, first[destination])) |entity| {
                if (position(&active.world.?, entity)) |point| add(view, goal_index, point);
                if (view.count > 0) view.markers[view.count - 1].rule = .exit;
            };
        }
    }
}
pub fn publish(active: *Context, now: i64) !void {
    if (engine.integer("g_gametype") != c.GT_SINGLE_PLAYER) {
        engine.config(c.CS_DK3_CAMPAIGN, "");
        return;
    }
    const hero = active.clients.entities[0] orelse return;
    const keys = (try active.world.?.get(hero, data.Keys)).*;
    var view = evaluate(&active.world.?, std.mem.sliceTo(&active.map_name, 0), keys);
    if (now >= active.campaign_hud_at and now - active.campaign_hud_at < 250) return;
    active.campaign_hud_at = now;
    if (rules.forMap(view.name()).len == 0) {
        engine.config(c.CS_DK3_CAMPAIGN, "");
        return;
    }
    try guideToMissingKey(active, &view, keys);
    // The same authored gate planner used by ordinary movement resolves nested
    // physical prerequisites. It only queries controls; the player still performs
    // every use, shot, timed crossing and companion order.
    if (view.count > 0 and active.systems.gates.built) {
        const origin = (try active.world.?.get(hero, data.Transform)).position;
        var best: usize = 0;
        for (view.markers[0..view.count], 0..) |marker, i| if (v.length(v.subtract(marker.position, origin)) < v.length(v.subtract(view.markers[best].position, origin))) {
            best = i;
        };
        const route = @import("bot_routes.zig").unblock(&active.world.?, &active.slots, &active.projection, &active.systems.gates, hero, view.markers[best].position, active.systems.navigation.service(), now, 0) catch null;
        if (route) |control| if (active.world.?.find(control.id)) |entity| if (position(&active.world.?, entity)) |point| {
            view.markers[best].position = point;
            view.markers[best].rule = switch (control.action) {
                .use => .used,
                .shoot => .broken,
                .touch => .exit,
            };
        };
    }
    var buffer: [1000]u8 = undefined;
    engine.config(c.CS_DK3_CAMPAIGN, try view.encode(&buffer));
}

/// Capture evidence before an output destroys its own source or another goal's item.
pub fn fired(world: *data.World) void {
    const context = @import("region_access.zig").contextFor(world) orelse return;
    const hero = context.clients.entities[0] orelse return;
    const keys = world.get(hero, data.Keys) catch return;
    _ = evaluate(world, std.mem.sliceTo(&context.map_name, 0), keys.*);
}
pub fn report(active: *Context) !void {
    const hero = active.clients.entities[0] orelse return;
    const view = evaluate(&active.world.?, std.mem.sliceTo(&active.map_name, 0), (try active.world.?.get(hero, data.Keys)).*);
    var buffer: [512]u8 = undefined;
    engine.print(try std.fmt.bufPrintZ(&buffer, "dk3 objectives: map={s} goals={d} done={x} stage={d} markers={d}\n", .{ view.name(), rules.forMap(view.name()).len, view.done, view.stage(), view.count }));
    for (rules.forMap(view.name()), 0..) |goal, i| engine.print(try std.fmt.bufPrintZ(&buffer, "dk3 goal: index={d} stage={d} rule={s} progress={d}/{d} done={d} text={s}\n", .{ i, goal.stage, @tagName(goal.rule), view.progress[i], goal.required(), @intFromBool(view.complete(i)), goal.text }));
}

test "authored counter progress survives HUD transport and latches only after its final activation" {
    const t = std.testing;
    var world = data.World.initNamespaced(t.allocator, 16, 3);
    defer world.deinit();
    _ = try world.create(0x03000001, .{data.MapObject{ .classname = "test_world" }});
    const counter = try world.create(0x0300002b, .{ data.MapObject{ .classname = "test_counter" }, data.Transform{}, data.Trigger{ .counter = true, .limit = 10, .uses = 7 } });
    const partial = evaluate(&world, "e2m5e", .{});
    try t.expectEqual(@as(u4, 7), partial.progress[1]);
    try t.expect(!partial.complete(1));
    var buffer: [1000]u8 = undefined;
    const restored = try rules.View.decode(try partial.encode(&buffer));
    try t.expectEqual(@as(u4, 7), restored.progress[1]);
    (try world.get(counter, data.Trigger)).uses = 10;
    const complete = evaluate(&world, "e2m5e", .{});
    try t.expect(complete.complete(1));
    try t.expectEqual(@as(u4, 10), (try rules.View.decode(try complete.encode(&buffer))).progress[1]);
    (try world.get(counter, data.Trigger)).uses = 0;
    try t.expect(evaluate(&world, "e2m5e", .{}).complete(1));
}
test "wave markers follow living death outputs instead of a hidden counter or its dead inputs" {
    const t = std.testing;
    var world = data.World.initNamespaced(t.allocator, 16, 3);
    defer world.deinit();
    _ = try world.create(0x03000001, .{data.MapObject{ .classname = "test_world" }});
    _ = try world.create(0x03000020, .{ data.MapObject{ .classname = "test_body" }, data.Health{ .current = 0 } });
    _ = try world.create(0x0300002b, .{ data.MapObject{ .classname = "test_counter", .targetname = "wave_done" }, data.Transform{}, data.Trigger{ .counter = true, .limit = 10, .uses = 3 } });
    const properties = &.{data.Property{ .key = "deathtarget", .value = "wave_done" }};
    const living = try world.create(0x03001000, .{ data.MapObject{ .classname = "test_body", .properties = properties }, data.Health{ .current = 30 }, data.Transform{ .position = .{ 64, 32, 24 } } });
    _ = try world.create(0x03001001, .{ data.MapObject{ .classname = "test_body", .properties = properties }, data.Health{ .current = 0 }, data.Transform{} });
    _ = try world.create(0x04001002, .{ data.MapObject{ .classname = "test_body", .properties = properties }, data.Health{ .current = 30 }, data.Transform{} });
    const view = evaluate(&world, "e2m5e", .{});
    try t.expectEqual(@as(usize, 1), view.count);
    try t.expectEqual(rules.Rule.defeated, view.markers[0].rule);
    try t.expectEqual(v.Vec3{ 64, 32, 24 }, view.markers[0].position);
    (try world.get(living, data.Health)).current = 0;
    try t.expectEqual(@as(usize, 0), evaluate(&world, "e2m5e", .{}).count);
}
test "hidden keys do not count; target evidence persists after a panel resets; namespaces stay local" {
    const t = std.testing;
    var world = data.World.initNamespaced(t.allocator, 16, 3);
    defer world.deinit();
    const key = try world.create(0x03000002, .{ data.MapObject{ .classname = "test_key" }, data.Transform{}, data.Pickup{ .kind = .{ .key = 0 }, .visible = false } });
    try t.expect(!satisfied(&world, .{}, .taken, 2));
    try t.expect(satisfied(&world, .{ .mask = 1 }, .taken, 2));
    (try world.get(key, data.MapObject)).objective_uses = 1;
    try t.expect(satisfied(&world, .{}, .taken, 2));
    const panel = try world.create(0x0300000f, .{ data.MapObject{ .classname = "test_panel", .objective_uses = 1 }, data.Transform{} });
    _ = panel;
    try t.expect(satisfied(&world, .{}, .used, 15));
    try t.expect(satisfied(&world, .{ .quest = 1 }, .owned, 15));
    const old_button = try world.create(0x03000010, .{ data.MapObject{ .classname = "test_old_control" }, data.Mover{ .closed = @splat(0), .opened = .{ 0, 0, 2 }, .motion = .{}, .owner = 7 } });
    try t.expect(satisfied(&world, .{}, .used, 16));
    (try world.get(old_button, data.Mover)).state = .opening;
    try t.expect(!satisfied(&world, .{}, .used, 16));
}

test "group progress latches before a completed switch is removed and ignores stale catalog revisions" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 16);
    defer world.deinit();
    const ledger = try world.create(1, .{data.MapObject{ .classname = "test_world" }});
    _ = try world.create(57, .{data.MapObject{ .classname = "test_control", .objective_uses = 1 }});
    const ids = [_]u32{ 265, 562, 563, 564 };
    for (ids[0..3]) |id| _ = try world.create(id, .{data.MapObject{ .classname = "test_control", .objective_uses = 1 }});
    var view = evaluate(&world, "e4m5a", .{});
    try t.expectEqual(@as(u4, 3), view.progress[1]);
    try t.expect(!view.complete(1));
    const last = try world.create(ids[3], .{data.MapObject{ .classname = "test_control", .objective_uses = 1 }});
    view = evaluate(&world, "e4m5a", .{});
    try t.expect(view.complete(1));
    try world.destroy(last);
    view = evaluate(&world, "e4m5a", .{});
    try t.expect(view.complete(1));
    (try world.get(ledger, data.MapObject)).objective_revision = rules.revision +% 1;
    view = evaluate(&world, "e4m5a", .{});
    try t.expect(!view.complete(1));
}
