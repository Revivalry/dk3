// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: exit. Level exits.
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const data = @import("../../../../game/domain/components.zig");
pub const classnames = [_][]const u8{"trigger_changelevel"};
pub const traits: context.Traits = .{ .level_exit = true };
/// Using a ready exit asks the campaign to travel, once a living, free player activated it
/// (a player frozen by a cinematic may still leave).
pub fn useAuthored(using: *context.Use) !void {
    const world = using.world;
    const exit = world.get(using.entity, data.Exit) catch return;
    if (using.now < exit.ready_ms or using.router.travel != null) return;
    const player = world.find(using.activator) orelse return;
    const state = world.get(player, data.Player) catch return;
    if ((state.mode != .normal and !(state.mode == .frozen and @import("../../../../mechanics/server/cinematics.zig").active(world))) or (try world.get(player, data.Health)).current <= 0) return;
    exit.ready_ms = using.now + 1000;
    using.router.travel = .{ .exit = try world.persistentId(using.entity), .player = using.activator };
}
