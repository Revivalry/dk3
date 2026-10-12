// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: World controls execute authored contracts through normal routing and collision.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
//! Each control's behaviour belongs to its map-entity class adapter (entity_classes/registry.zig).
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const Router = @import("targets.zig").Router;
const classes = @import("entity_classes/registry.zig");

pub fn owns(name: []const u8) bool {
    return classes.classOf(name) != null;
}
pub fn spawn(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, now: i64) !void {
    var ids: [ecs.max_entities]ecs.Entity = undefined;
    var count: usize = 0;
    {
        var query = world.queryAccess(data.World.mask(.{data.MapObject}), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, object| if (owns(object.classname)) {
            ids[count] = entity;
            count += 1;
        };
    }
    for (ids[0..count]) |entity| try spawnOne(world, slots, projections, entity, now);
    classes.finishStep(world, now);
}
/// Spawns one entity of a world-control class (`owns`), authored or created at run time.
pub fn spawnOne(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, now: i64) !void {
    const object = (try world.get(entity, data.MapObject)).*;
    var spawning: classes.Spawn = .{ .world = world, .slots = slots, .projections = projections, .entity = entity, .object = object, .now = now };
    switch (try classes.spawn(classes.classOf(object.classname).?, &spawning)) {
        .keep => {},
        .remove => if ((world.get(entity, data.Binding) catch null) != null) try @import("weapon_entities.zig").remove(world, slots, projections, entity) else try world.destroy(entity),
        .control => |action| {
            try world.put(entity, data.WorldControl{ .action = action });
            var publishing: classes.Publish = .{ .world = world, .slots = slots, .projections = projections, .entity = entity, .now = now };
            try classes.bind(action, &publishing);
        },
    }
}
fn controlOf(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *Router, entity: ecs.Entity, now: i64) !classes.Control {
    return .{ .world = world, .slots = slots, .projections = projections, .router = router, .entity = entity, .control = try world.get(entity, data.WorldControl), .now = now };
}
pub fn use(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *Router, entity: ecs.Entity, activator: u32, now: i64) !void {
    var control = try controlOf(world, slots, projections, router, entity, now);
    if (now < control.control.ready_ms) return;
    try classes.use(&control, activator);
}
pub fn touches(world: *data.World, entity: ecs.Entity, other: ecs.Entity) !bool {
    return classes.touches(.{ .world = world, .entity = entity, .control = (try world.get(entity, data.WorldControl)).*, .object = (try world.get(entity, data.MapObject)).*, .other = other });
}
pub fn touch(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *Router, entity: ecs.Entity, other: ecs.Entity, now: i64) !void {
    var control = try controlOf(world, slots, projections, router, entity, now);
    if (now < control.control.ready_ms or !@import("locks.zig").allows(world, (try world.get(entity, data.MapObject)).*, try world.persistentId(other))) return;
    try classes.touch(&control, other);
}
pub fn step(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *Router, now: i64) !void {
    try classes.prepareStep(world, now);
    var ids: [ecs.max_entities]ecs.Entity = undefined;
    var count: usize = 0;
    {
        var query = world.queryAccess(data.World.mask(.{data.WorldControl}), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities()) |entity| {
            ids[count] = entity;
            count += 1;
        };
    }
    for (ids[0..count]) |entity| {
        if (!world.alive(entity)) continue;
        var control = try controlOf(world, slots, projections, router, entity, now);
        try classes.step(&control);
    }
    classes.finishStep(world, now);
}
