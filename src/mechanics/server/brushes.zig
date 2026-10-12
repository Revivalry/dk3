// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: BSP submodels receive explicit ECS bindings and transport projections.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const std = @import("std");
const classes = @import("entity_classes/registry.zig");
const data = @import("../../game/domain/components.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const c = abi.c;
const Slots = @import("../../engine/slots.zig").Slots;
/// Trigger angles describe directional behavior, not brush rotation. The reference
/// engine expands rotated bounds only for SOLID_BSP; ioquake uses bmodel instead.
/// Keep the authored transform for gameplay and project an unrotated trigger hull.
pub fn collisionAngles(classname: []const u8, angles: data.Vec3) data.Vec3 {
    return if (std.mem.startsWith(u8, classname, "trigger_")) @splat(0) else angles;
}

/// An authored brush model is bound unless its class says otherwise.
pub fn binds(object: data.MapObject) bool {
    return object.model.len > 1 and object.model[0] == '*' and classes.brushOf(object.classname).bound;
}

/// Gold never sends trigger volumes, nor brushes whose class hides them (clips, event
/// generators): invisible volumes, often textured "trigger".
pub fn hiddenClass(classname: []const u8) bool {
    return std.mem.startsWith(u8, classname, "trigger_") or classes.brushOf(classname).hidden;
}

pub fn spawn(world: *data.World, slots: *Slots, projections: []abi.EntityProjection) !void {
    // Collect handles before adding components: no structural edits in a query epoch.
    var entities: [@import("../../core/ecs/world.zig").max_entities]@import("../../core/ecs/world.zig").Entity = undefined;
    var count: usize = 0;
    var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Transform }), 0, 0);
    {
        defer query.deinit();
        while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, object| {
            if (binds(object)) {
                entities[count] = entity;
                count += 1;
            }
        };
    }
    for (entities[0..count]) |entity| {
        const object = (try world.get(entity, data.MapObject)).*;
        var transform = (try world.get(entity, data.Transform)).*;
        const brush = classes.brushOf(object.classname);
        if (brush.angles == .zeroed) {
            transform.angles = @splat(0);
            (try world.get(entity, data.Transform)).angles = transform.angles;
        }
        const model = try std.fmt.parseInt(u16, object.model[1..], 10);
        const index = try slots.acquire(entity, null);
        errdefer slots.release(index, entity) catch unreachable;
        var name: [16]u8 = undefined;
        const path = try std.fmt.bufPrintZ(&name, "*{d}", .{model});
        const projection = &projections[index];
        _ = engine.gateway.call(c.G_SET_BRUSH_MODEL, .{ projection, path.ptr });
        const trigger = std.mem.startsWith(u8, object.classname, "trigger_");
        const hidden = hiddenClass(object.classname);
        const contents: u32 = if (trigger) c.CONTENTS_TRIGGER else switch (brush.contents) {
            .solid => c.CONTENTS_SOLID,
            .none => 0,
        };
        try world.put(entity, data.Binding{ .slot = index, .model = model });
        try world.put(entity, data.Body{ .mins = projection.shared.mins, .maxs = projection.shared.maxs, .contents = contents, .collision_mask = c.MASK_SOLID });
        projection.state.eType = c.ET_MOVER;
        projection.state.pos.trType = c.TR_STATIONARY;
        projection.state.pos.trBase = transform.position;
        projection.state.apos.trType = c.TR_STATIONARY;
        projection.state.apos.trBase = transform.angles;
        projection.shared.currentOrigin = transform.position;
        projection.shared.currentAngles = collisionAngles(object.classname, transform.angles);
        projection.shared.contents = @bitCast(contents);
        if (hidden) projection.shared.svFlags |= c.SVF_NOCLIENT;
        engine.link(projection);
    }
}

test "directional trigger hulls stay unrotated while real rotating brushes retain orientation" {
    try std.testing.expectEqual(data.Vec3{ 0, 0, 0 }, collisionAngles("trigger_changelevel", .{ 0, 180, 0 }));
    try std.testing.expectEqual(data.Vec3{ 0, 0, 0 }, collisionAngles("trigger_once", .{ 0, 270, 0 }));
    try std.testing.expectEqual(data.Vec3{ 0, 45, 0 }, collisionAngles("func_rotating", .{ 0, 45, 0 }));
    try std.testing.expectEqual(data.Vec3{ 0, 0, 0 }, collisionAngles("func_door", .{ 0, 0, 0 }));
}

test "retained e1m2b portal metadata cannot become a wall while authored doors still bind" {
    try std.testing.expect(!binds(.{ .classname = "func_areaportalass", .model = "*40", .targetname = "eledoor" }));
    try std.testing.expect(!binds(.{ .classname = "func_areaportal", .model = "*40" }));
    try std.testing.expect(binds(.{ .classname = "func_door", .model = "*40", .targetname = "eledoor" }));
    try std.testing.expect(binds(.{ .classname = "func_wall", .model = "*40" }));
    try std.testing.expect(!binds(.{ .classname = "func_group" }));
}

test "invisible authored volumes stay hidden after spawn and restoration" {
    try std.testing.expect(hiddenClass("trigger_once") and hiddenClass("func_clip") and hiddenClass("func_monsterclip"));
    try std.testing.expect(hiddenClass("func_event_generator"));
    try std.testing.expect(!hiddenClass("func_wall") and !hiddenClass("func_door"));
}
