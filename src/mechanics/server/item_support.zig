// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Resting collection triggers acquire exact brush support before it moves.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const v = @import("../../core/domain/vector.zig");
const Move = @import("attachments.zig").Move;

pub fn bind(world: *data.World, projections: []const abi.EntityProjection, moves: []const Move) !void {
    for (moves) |move| {
        const slot = (try world.get(move.entity, data.Binding)).slot;
        const parent = &projections[slot];
        const old = (try world.get(move.entity, data.Transform)).*;
        if (std.meta.eql(old, move.destination)) continue;
        var query = world.queryAccess(data.World.mask(.{ data.Pickup, data.ItemMotion, data.Transform, data.Body }), 0, data.World.mask(.{data.ItemMotion}));
        defer query.deinit();
        while (query.next()) |view| for (view.read(data.Pickup), view.write(data.ItemMotion), view.read(data.Transform), view.read(data.Body)) |pickup, *motion, pose, body| {
            if (!pickup.visible or motion.ground != @as(?u16, abi.c.ENTITYNUM_WORLD)) continue;
            const mins = v.add(pose.position, body.mins);
            const maxs = v.add(pose.position, body.maxs);
            const below: v.Vec3 = .{ 0, 0, -2 };
            var overlaps = true;
            for (0..3) |axis| if (maxs[axis] + below[axis] <= parent.shared.absmin[axis] or mins[axis] + below[axis] >= parent.shared.absmax[axis]) {
                overlaps = false;
                break;
            };
            if (!overlaps) continue;
            // Query only this brush: a separate authored cover can enclose
            // a pickup without hiding the platform directly beneath it.
            if (engine.entityContact(parent, mins, maxs)) continue;
            if (!engine.entityContact(parent, v.add(mins, below), v.add(maxs, below))) continue;
            motion.ground = slot;
            motion.support_pose = .{ .position = old.position, .angles = old.angles };
            motion.base = pose.position;
        };
    }
}

test "world-pinned pickups acquire moving support and follow it exactly once" {
    const Fixture = struct {
        fn syscall(operation: isize, ...) callconv(.c) isize {
            var args = @cVaStart();
            defer @cVaEnd(&args);
            if (operation != abi.c.G_ENTITY_CONTACT) return 0;
            const mins = @cVaArg(&args, *const v.Vec3);
            const maxs = @cVaArg(&args, *const v.Vec3);
            const brush = @cVaArg(&args, *const abi.EntityProjection);
            for (0..3) |axis| if (maxs[axis] <= brush.shared.absmin[axis] or mins[axis] >= brush.shared.absmax[axis]) return 0;
            return 1;
        }
    };
    const previous = engine.gateway;
    defer engine.gateway = previous;
    engine.gateway.bind(Fixture.syscall);
    var world = data.World.init(std.testing.allocator, 8);
    defer world.deinit();
    const parent = try world.create(1, .{ data.Transform{}, data.Binding{ .slot = 0 } });
    const pickup = try world.create(2, .{ data.Transform{ .position = .{ 0, 0, 9 } }, data.Body{ .mins = @splat(-8), .maxs = @splat(8) }, data.ItemMotion{ .base = .{ 0, 0, 9 }, .ground = abi.c.ENTITYNUM_WORLD }, data.Pickup{ .kind = .{ .ammunition = 0 } } });
    const above = try world.create(3, .{ data.Transform{ .position = .{ 0, 0, 12 } }, data.Body{ .mins = @splat(-8), .maxs = @splat(8) }, data.ItemMotion{ .ground = abi.c.ENTITYNUM_WORLD }, data.Pickup{ .kind = .{ .ammunition = 0 } } });
    const hidden = try world.create(4, .{ data.Transform{ .position = .{ 0, 0, 9 } }, data.Body{ .mins = @splat(-8), .maxs = @splat(8) }, data.ItemMotion{ .ground = abi.c.ENTITYNUM_WORLD }, data.Pickup{ .kind = .{ .ammunition = 0 }, .visible = false } });
    var projections = std.mem.zeroes([1]abi.EntityProjection);
    projections[0].shared.absmin = .{ -64, -64, -8 };
    projections[0].shared.absmax = .{ 64, 64, 0 };
    const moves = [_]Move{.{ .entity = parent, .destination = .{ .position = .{ 0, 0, 10 } } }};
    try bind(&world, &projections, &moves);
    try std.testing.expectEqual(@as(?u16, 0), (try world.get(pickup, data.ItemMotion)).ground);
    try std.testing.expectEqual(@as(?u16, abi.c.ENTITYNUM_WORLD), (try world.get(above, data.ItemMotion)).ground);
    try std.testing.expectEqual(@as(?u16, abi.c.ENTITYNUM_WORLD), (try world.get(hidden, data.ItemMotion)).ground);
    (try world.get(parent, data.Transform)).position[2] = 10;
    var slots: @import("../../engine/slots.zig").Slots = .{};
    slots.occupants[0] = parent;
    try std.testing.expect(try @import("items.zig").settle(&world, &slots, pickup, 1000, 50));
    try std.testing.expectApproxEqAbs(@as(f32, 19), (try world.get(pickup, data.Transform)).position[2], 0.001);
    try std.testing.expect(try @import("items.zig").settle(&world, &slots, pickup, 1050, 50));
    try std.testing.expectApproxEqAbs(@as(f32, 19), (try world.get(pickup, data.Transform)).position[2], 0.001);
}
