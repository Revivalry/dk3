// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Co-op bot locomotion and combat as a client. The shared pilot plans one
//! frame of scripted intent; this adapter encodes it as an ordinary user
//! command (and a "use" when pressed) for the single-player client. Nothing
//! here moves entities or changes inventory; the shared player motor does that.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const nav = @import("../../core/domain/navigation.zig");
const pilot = @import("bot_pilot.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const Clients = @import("clients.zig").Clients;

pub const Frame = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    clients: *Clients,
    service: nav.Service,
    index: u16,
    entity: ecs.Entity,
    now: i64,
    /// Live navigation gates of this world, for planning past closed ones.
    gates: ?*@import("navigation_gates.zig").State = null,
};
pub const Intent = pilot.Intent;
pub const Report = pilot.Report;
pub const Motor = pilot.Pilot;

/// The pilot's view of the client: its own player state, the engine's
/// collision and the client weapon table, with every capability.
pub fn pilotFrame(frame: Frame) !pilot.Frame {
    return .{
        .world = frame.world,
        .slots = frame.slots,
        .projections = frame.projections,
        .service = frame.service,
        .collision = engine.collisionService(),
        .table = &frame.clients.weapon_table,
        .slot = frame.index,
        .entity = frame.entity,
        .state = (try frame.world.get(frame.entity, data.Player)).*,
        .motor = @import("../player_state.zig").characterParametersForMode(frame.index, (try frame.world.get(frame.entity, data.Character)).*, (try frame.world.get(frame.entity, data.Ailments)).*, frame.now, engine.integer("g_gametype") != abi.c.GT_SINGLE_PLAYER),
        .now = frame.now,
        .liquid_mask = pilot.liquidMask(frame.world, frame.entity, frame.clients.episode),
        .gates = frame.gates,
        .turn_rate_limit = 360,
    };
}
pub fn drive(motor: *Motor, frame: Frame, intent: Intent) !Report {
    const steering = try motor.steer(try pilotFrame(frame), intent);
    const used = try @import("bot_input.zig").submit(frame.world, frame.entity, frame.index, steering.command, steering.report.used_slot, (try frame.world.get(frame.entity, data.Player)).delta_angles, frame.now);
    if (steering.report.used and !used) motor.use_ready = frame.now + 50;
    if (engine.integer("dk3_coop_motion_trace") != 0) {
        const pose = (try frame.world.get(frame.entity, data.Transform)).*;
        var message: [192]u8 = undefined;
        engine.print(try std.fmt.bufPrintZ(&message, "dk3 coop motion: now={d} pos={d:.4},{d:.4},{d:.4} angles={d:.4},{d:.4}\n", .{ frame.now, pose.position[0], pose.position[1], pose.position[2], steering.command.angles[0], steering.command.angles[1] }));
    }
    if (engine.integer("developer") >= 2 and steering.command.up != 0) {
        var echoed: [192]u8 = undefined;
        var heard: abi.c.usercmd_t = undefined;
        engine.usercmd(frame.index, &heard);
        engine.print(std.fmt.bufPrintZ(&echoed, "dk3 coop: t={d} event=sent slot={d} up={d} fw={d} echo_up={d} echo_st={d}\n", .{ frame.now, frame.index, steering.command.up, steering.command.forward, heard.upmove, heard.serverTime }) catch "");
    }
    var report = steering.report;
    report.used = used;
    report.input = .{ steering.command.forward, steering.command.right, steering.command.up };
    return report;
}
