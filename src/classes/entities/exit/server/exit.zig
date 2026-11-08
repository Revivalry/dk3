// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: exit. Level exits.
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const Entity = @import("../../../../core/ecs/world.zig").Entity;
pub const classnames = [_][]const u8{"trigger_changelevel"};
pub const traits: context.Traits = .{ .level_exit = true };
/// Sustained contact retries after a party refusal; arrival latches stay disarmed.
/// Keep target routing (locks and authored uses) on the normal activation path.
pub fn touchAuthored(using: *context.Use) !void {
    const world = using.world;
    const exit = world.get(using.entity, data.Exit) catch return;
    const projection = &using.projections[(try world.get(using.entity, data.Binding)).slot];
    for (using.slots.occupants[0..c.MAX_CLIENTS]) |maybe| {
        const actor = maybe orelse continue;
        const state = world.get(actor, data.Player) catch continue;
        if (state.mode != .normal or (try world.get(actor, data.Health)).current <= 0) continue;
        const player_projection = &using.projections[(try world.get(actor, data.Binding)).slot];
        if (!@import("../../../../mechanics/server/interactions.zig").overlap(player_projection, projection, 0)) continue;
        if (!exit.latched and using.now >= exit.ready_ms) {
            exit.latched = true;
            try using.router.activate(world, using.slots, using.projections, using.entity, try world.persistentId(actor), using.now);
        }
        return;
    }
    exit.latched = false;
}
/// The player leaving. A use that a non-client began (e1m7b's dk_end, fired through a
/// counter by the last psyclaw's deathtarget) passes, as in the reference, to the client.
fn traveler(world: *data.World, activator: u32) ?Entity {
    if (world.find(activator)) |entity| if ((world.get(entity, data.Player) catch null) != null) return entity;
    if (engine.integer("g_gametype") != c.GT_SINGLE_PLAYER) return null;
    var people = world.queryAccess(data.World.mask(.{data.Player}), 0, 0);
    defer people.deinit();
    while (people.next()) |view| for (view.entities()) |entity| return entity;
    return null;
}
/// Using a ready exit asks the campaign to travel, once a living, free player activated it
/// (a player frozen by a cinematic may still leave).
pub fn useAuthored(using: *context.Use) !void {
    const world = using.world;
    const exit = world.get(using.entity, data.Exit) catch return;
    if (using.now < exit.ready_ms or using.router.travel != null) return;
    const player = traveler(world, using.activator) orelse return;
    const state = world.get(player, data.Player) catch return;
    if ((state.mode != .normal and !(state.mode == .frozen and @import("../../../../mechanics/server/cinematics.zig").active(world))) or (try world.get(player, data.Health)).current <= 0) return;
    if (!try @import("../../../../game/server/session_classes.zig").party.required(world, player, using.object.flags)) {
        try @import("../../../../game/server/session_classes.zig").party.summonForExit(world, player, using.object.flags);
        exit.latched = false;
        exit.ready_ms = using.now + 2500;
        engine.send((try world.get(player, data.Binding)).slot, "cp \"Your companions must be nearby before you can leave.\"");
        return;
    }
    exit.ready_ms = using.now + 1000;
    using.router.travel = .{ .exit = try world.persistentId(using.entity), .player = try world.persistentId(player) };
}

test "arrival overlap stays disarmed until leaving and reentering the exit" {
    const std = @import("std");
    const t = std.testing;
    const Fixture = struct {
        fn syscall(operation: isize, ...) callconv(.c) isize {
            // Routing may query diagnostic verbosity. Other engine calls
            // would be an unexpected side effect of this arrival fixture.
            return switch (operation) {
                c.G_CVAR_VARIABLE_INTEGER_VALUE => 0,
                else => unreachable,
            };
        }
    };
    const previous_gateway = engine.gateway;
    defer engine.gateway = previous_gateway;
    engine.gateway.bind(Fixture.syscall);
    var world = data.World.init(t.allocator, 4);
    defer world.deinit();
    const player = try world.create(7, .{ data.Transform{}, data.Player{}, data.Health{ .current = 100, .maximum = 100 }, data.Binding{ .slot = 0 } });
    const object: data.MapObject = .{ .classname = "trigger_changelevel" };
    const exit = try world.create(8, .{ object, data.Binding{ .slot = 64 }, data.Exit{ .latched = true } });
    var slots: @import("../../../../engine/slots.zig").Slots = .{};
    slots.occupants[0] = player;
    slots.occupants[64] = exit;
    var projections = std.mem.zeroes([65]@import("../../../../engine/abi.zig").EntityProjection);
    var router: context.Router = .{};
    var using: context.Use = .{ .world = &world, .slots = &slots, .projections = &projections, .router = &router, .entity = exit, .object = object, .source = null, .activator = 0, .now = 5000 };
    try touchAuthored(&using);
    try t.expect(router.travel == null);
    try t.expect((try world.get(exit, data.Exit)).latched);
    projections[0].shared.absmin = .{ 128, 128, 128 };
    projections[0].shared.absmax = .{ 160, 160, 160 };
    try touchAuthored(&using);
    try t.expect(!(try world.get(exit, data.Exit)).latched);
    projections[0].shared.absmin = .{ 0, 0, 0 };
    projections[0].shared.absmax = .{ 0, 0, 0 };
    try touchAuthored(&using);
    try t.expectEqual(@as(u32, 7), router.travel.?.player);
    try t.expectEqual(@as(u32, 8), router.travel.?.exit);
}
