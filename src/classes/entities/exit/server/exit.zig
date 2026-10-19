// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: exit. Level exits.
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const Entity = @import("../../../../core/ecs/world.zig").Entity;
pub const classnames = [_][]const u8{"trigger_changelevel"};
pub const traits: context.Traits = .{ .level_exit = true };
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
    exit.ready_ms = using.now + 1000;
    using.router.travel = .{ .exit = try world.persistentId(using.entity), .player = try world.persistentId(player) };
}
