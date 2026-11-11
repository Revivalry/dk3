// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: A pilot command as ordinary client input: the user command a bot client
//! submits (view relative to the server's delta angles) and the "use" it
//! presses. Shared by the co-op bot and the multiplayer bots.
const std = @import("std");
const engine = @import("../../engine/server.zig");
const c = @import("../../engine/abi.zig").c;
const pilot = @import("bot_pilot.zig");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");

/// BOTLIB_USER_COMMAND calls GAME_CLIENT_THINK synchronously. A visible bot
/// client also sends idle keyboard commands; distinguish the pilot's input.
pub var submitting: ?u16 = null;

pub fn submit(world: *data.World, entity: ecs.Entity, index: u16, command: pilot.Command, wanted_use: u16, delta_angles: [3]i32, now: i64) !bool {
    var input = encode(command, delta_angles, now);
    const previous = submitting;
    submitting = index;
    defer submitting = previous;
    _ = engine.gateway.call(c.BOTLIB_USER_COMMAND, .{ @as(isize, index), &input });
    // Client think applies movement and stance before the separate use command.
    // The pilot's earlier eye ray can cease to hit a small control during that
    // movement. Count only a press qualified from the resulting player view.
    if (!command.use) return false;
    const hit = try @import("interactions.zig").aimTrace(world, entity);
    if (!useHits(hit, wanted_use, @intFromEnum(@import("../../engine/worlds.zig").current()))) return false;
    _ = engine.gateway.call(c.BOTLIB_EA_COMMAND, .{ @as(isize, index), @as([*:0]const u8, "use") });
    return true;
}
fn useHits(hit: @import("../../core/domain/collision.zig").Trace, wanted: u16, owner: u32) bool {
    return wanted != c.ENTITYNUM_NONE and (hit.world == 0 or hit.world == owner) and hit.entity == wanted and !hit.start_solid and !hit.all_solid;
}

test "use qualification rejects movement carrying the view off the intended control" {
    const collision = @import("../../core/domain/collision.zig");
    var hit: collision.Trace = .{ .fraction = 0.4, .end = .{ 0, 0, 0 }, .normal = @splat(0), .entity = 197 };
    try std.testing.expect(useHits(hit, 197, 1));
    hit.entity = c.ENTITYNUM_WORLD;
    try std.testing.expect(!useHits(hit, 197, 1));
    hit.entity = c.ENTITYNUM_NONE;
    try std.testing.expect(!useHits(hit, 197, 1));
    hit.entity = 197;
    hit.start_solid = true;
    try std.testing.expect(!useHits(hit, 197, 1));
    hit.start_solid = false;
    hit.world = 2;
    try std.testing.expect(!useHits(hit, 197, 1));
}
/// A client command carries its view relative to the server's delta angles.
pub fn encode(command: pilot.Command, delta_angles: [3]i32, now: i64) c.usercmd_t {
    var input = std.mem.zeroes(c.usercmd_t);
    input.serverTime = @intCast(now);
    for (command.angles, 0..) |angle, axis| input.angles[axis] = @as(i32, @intFromFloat(angle * 65536 / 360)) -% delta_angles[axis];
    input.forwardmove = command.forward;
    input.rightmove = command.right;
    input.upmove = command.up;
    input.weapon = command.weapon;
    if (command.attack) input.buttons |= c.BUTTON_ATTACK;
    if (command.any) input.buttons |= c.BUTTON_ANY;
    return input;
}

test "client commands carry view relative to delta angles and every pressed button" {
    const input = encode(.{ .angles = .{ 10, 90, 0 }, .forward = 127, .right = -64, .up = -127, .attack = true, .any = true, .weapon = 3 }, .{ 0, 16384, 0 }, 4000);
    try std.testing.expectEqual(@as(i32, 4000), input.serverTime);
    try std.testing.expectEqual(@as(i32, @intFromFloat(10.0 * 65536.0 / 360.0)), input.angles[0]);
    try std.testing.expectEqual(@as(i32, 0), input.angles[1]);
    try std.testing.expectEqual(@as(i8, 127), input.forwardmove);
    try std.testing.expectEqual(@as(i8, -64), input.rightmove);
    try std.testing.expectEqual(@as(u8, 3), input.weapon);
    try std.testing.expect(input.buttons & c.BUTTON_ATTACK != 0 and input.buttons & c.BUTTON_ANY != 0);
}
