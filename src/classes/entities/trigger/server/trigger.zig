// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: trigger. Relays and touch triggers: once, multiple, relay and counter limits.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const ecs = @import("../../../../core/ecs/world.zig");
pub const classnames = [_][]const u8{ "trigger_once", "trigger_multiple", "trigger_relay", "trigger_counter" };
pub const pass: context.Pass = .triggers;
pub fn prepare(preparing: *context.Prepare) !void {
    const object = preparing.object;
    const counter = std.mem.eql(u8, object.classname, "trigger_counter");
    const limit = try prop.number(object, "count", if (counter) 2 else 0);
    const wait = try prop.milliseconds(object, "wait", 0);
    try preparing.world.put(preparing.entity, data.Trigger{ .limit = if (std.mem.eql(u8, object.classname, "trigger_once")) 1 else if (counter) @intFromFloat(@max(1, limit)) else @intFromFloat(@max(0, limit)), .counter = counter, .wait_ms = if (wait > 0) wait else 200 });
    _ = try shotState(preparing.world, preparing.entity, object);
}

pub fn worldSpawn(frame: *const @import("../../../../mechanics/server/system_context.zig").Spawn) !void {
    var query = frame.world.queryAccess(data.World.mask(.{ data.Trigger, data.Health, data.Binding, data.Body }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.read(data.Binding), view.read(data.Body)) |binding, body| {
        const projection = &frame.projections[binding.slot];
        // Trigger-textured BSP brushes retain trigger-only clip contents.
        // These rectangular hit volumes need a shot-visible runtime box.
        projection.shared.bmodel = 0;
        projection.shared.contents = @bitCast(body.contents);
        engine.link(projection);
    };
}

// Health-bearing trigger brushes are invisible shooting targets, not ordinary
// touch volumes. CORPSE participates in MASK_SHOT without blocking a player.
fn shotState(world: *data.World, entity: ecs.Entity, object: data.MapObject) !bool {
    const maximum: i32 = @intFromFloat(@max(0, try prop.number(object, "health", 0)));
    if (maximum == 0 or (world.get(entity, data.Binding) catch null) == null) return false;
    const trigger = (try world.get(entity, data.Trigger)).*;
    const spent = trigger.limit > 0 and trigger.uses >= trigger.limit;
    if ((world.get(entity, data.Health) catch null) == null)
        try world.put(entity, data.Health{ .current = if (spent) 0 else maximum, .maximum = maximum });
    if ((world.get(entity, data.Hurt) catch null) == null) try world.put(entity, data.Hurt{});
    (try world.get(entity, data.Body)).contents = if (spent) 0 else c.CONTENTS_CORPSE;
    return true;
}

/// Older saves lacked health on these brushes. Recover it from their retained
/// properties, preserving the trigger's saved uses and cooldown.
pub fn restoreBegin(world: *data.World) !void {
    var list: [ecs.max_entities]ecs.Entity = undefined;
    var count: usize = 0;
    {
        var query = world.queryAccess(data.World.mask(.{ data.Trigger, data.MapObject }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities()) |entity| {
            list[count] = entity;
            count += 1;
        };
    }
    for (list[0..count]) |entity| _ = try shotState(world, entity, (try world.get(entity, data.MapObject)).*);
}

pub const projected = .{data.Trigger};
pub fn project(frame: *const @import("../../../../mechanics/server/system_context.zig").Project) !bool {
    const world = frame.world;
    const entity = frame.entity;
    if ((world.get(entity, data.Health) catch null) == null) return false;
    const body = (try world.get(entity, data.Body)).*;
    const pose = (try world.get(entity, data.Transform)).*;
    const slot = (try world.get(entity, data.Binding)).slot;
    const projection = &frame.projections[slot];
    projection.state.eType = c.ET_MOVER;
    projection.shared.svFlags = c.SVF_NOCLIENT;
    projection.shared.bmodel = 0;
    projection.shared.mins = body.mins;
    projection.shared.maxs = body.maxs;
    projection.shared.currentOrigin = pose.position;
    projection.shared.currentAngles = @splat(0);
    projection.shared.contents = @bitCast(body.contents);
    engine.link(projection);
    return true;
}

pub fn prepareDamage(world: *data.World, entity: ecs.Entity, _: i32, now: i64, options: *@import("../../../../mechanics/domain/damage.zig").Options) !void {
    const trigger = world.get(entity, data.Trigger) catch return;
    if (now < trigger.ready_ms or (trigger.limit > 0 and trigger.uses >= trigger.limit)) options.cancelled = true;
}

/// A weapon hit reaches the authored health threshold before the normal target
/// router activates it. This keeps locks, delays, counters and target chains.
pub fn worldStep(frame: *const @import("../../../../mechanics/server/system_context.zig").Step) !void {
    var list: [ecs.max_entities]ecs.Entity = undefined;
    var count: usize = 0;
    {
        var query = frame.world.queryAccess(data.World.mask(.{ data.Trigger, data.Health, data.Hurt, data.Binding }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities(), view.read(data.Trigger), view.read(data.Health)) |entity, trigger, health| {
            if (health.current > 0 or frame.now < trigger.ready_ms or (trigger.limit > 0 and trigger.uses >= trigger.limit)) continue;
            list[count] = entity;
            count += 1;
        };
    }
    for (list[0..count]) |entity| {
        const source = (try frame.world.get(entity, data.Hurt)).source;
        try frame.targets.activate(frame.world, frame.slots, frame.projections, entity, source, frame.now);
        if (!frame.world.alive(entity)) continue;
        const trigger = (try frame.world.get(entity, data.Trigger)).*;
        const spent = trigger.limit > 0 and trigger.uses >= trigger.limit;
        if (spent) {
            (try frame.world.get(entity, data.Body)).contents = 0;
            const slot = (try frame.world.get(entity, data.Binding)).slot;
            frame.projections[slot].shared.contents = 0;
            engine.link(&frame.projections[slot]);
        } else {
            const health = try frame.world.get(entity, data.Health);
            health.current = health.maximum;
        }
    }
}
pub fn traits(classname: []const u8) context.Traits {
    if (std.mem.eql(u8, classname, "trigger_relay")) return .{ .relays = true };
    if (std.mem.eql(u8, classname, "trigger_counter")) return .{ .relays = true, .counter = true };
    return .{ .relays = true, .touch_volume = true };
}

test "shot targets migrate old saves without resetting uses, damage or cooldown" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 8);
    defer world.deinit();
    const object: data.MapObject = .{ .classname = "trigger_once", .properties = &.{.{ .key = "health", .value = "150" }} };
    const entity = try world.create(1, .{ object, data.Trigger{ .limit = 1, .ready_ms = 2100 }, data.Body{}, data.Binding{ .slot = 5 } });
    try restoreBegin(&world);
    try t.expectEqual(@as(i32, 150), (try world.get(entity, data.Health)).current);
    const contents = (try world.get(entity, data.Body)).contents;
    try t.expect(contents & c.MASK_SHOT != 0 and contents & c.MASK_PLAYERSOLID == 0 and contents & c.CONTENTS_TRIGGER == 0);
    (try world.get(entity, data.Health)).current = 75;
    try restoreBegin(&world);
    try t.expectEqual(@as(i32, 75), (try world.get(entity, data.Health)).current);
    try t.expectEqual(@as(i64, 2100), (try world.get(entity, data.Trigger)).ready_ms);
    var options: @import("../../../../mechanics/domain/damage.zig").Options = .{};
    try prepareDamage(&world, entity, 100, 2000, &options);
    try t.expect(options.cancelled);
    (try world.get(entity, data.Trigger)).uses = 1;
    try restoreBegin(&world);
    try t.expectEqual(@as(u32, 0), (try world.get(entity, data.Body)).contents);
}
