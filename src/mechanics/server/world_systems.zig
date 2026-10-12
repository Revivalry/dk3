// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Explicit owner-thread barriers: activation, deadlines, collision, arrival, targets.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const data = @import("../../game/domain/components.zig");
const abi = @import("../../engine/abi.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const Router = @import("targets.zig").Router;
const systems = @import("../../game/server/world_system_classes.zig");
const system_context = @import("system_context.zig");
/// Runs one phase's class hooks in registry order.
fn run(comptime list: anytype, comptime hook: []const u8, context: anytype) !void {
    inline for (list) |System| try @field(System, hook)(context);
}
pub const State = struct {
    multiplayer: @import("multiplayer.zig").State = .{},
    inline_models: u16 = 1,
    cinematics: @import("cinematics.zig").State = .{},
    scripts: @import("scripts.zig").State = .{},
    actors: @import("actors.zig").Actors = .{},
    navigation: @import("../../engine/navigation.zig").Navigation = .{},
    gates: @import("navigation_gates.zig").State = .{},
    pub fn deinit(self: *State, restart: bool) void {
        self.gates.deinit();
        self.navigation.deinit(restart);
    }
    pub fn spawn(self: *State, allocator: @import("std").mem.Allocator, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, now: i64, episode: u8, table: *const @import("../domain/weapons.zig").Table, restart: bool, resident: bool) !void {
        {
            var query = world.queryAccess(data.World.mask(.{data.MapObject}), 0, 0);
            defer query.deinit();
            while (query.next()) |view| for (view.read(data.MapObject)) |object| if (object.model.len > 1 and object.model[0] == '*') {
                self.inline_models = @max(self.inline_models, 1 + try @import("std").fmt.parseInt(u16, object.model[1..], 10));
            };
        }
        const spawning: system_context.Spawn = .{ .allocator = allocator, .world = world, .slots = slots, .projections = projections, .now = now };
        try @import("spawn_filter.zig").apply(world);
        try @import("brushes.zig").spawn(world, slots, projections);
        try run(systems.spawn_movers, "worldSpawn", &spawning);
        try @import("targets.zig").spawn(world);
        try @import("world_controls.zig").spawn(world, slots, projections, now);
        try @import("music.zig").restore(world, allocator);
        try run(systems.spawn_triggers, "worldSpawn", &spawning);
        try @import("campaign.zig").spawn(world);
        try @import("world_actions.zig").spawn(allocator, world, projections);
        try run(systems.spawn_paths, "worldSpawn", &spawning);
        try @import("items.zig").spawn(world, slots, projections, now, episode);
        try run(systems.spawn_fixtures, "worldSpawn", &spawning);
        self.actors.weapons = table.*;
        try self.actors.spawn(allocator, world, slots, projections, now, episode);
        try run(systems.spawn_ambient, "worldSpawn", &spawning);
        try @import("attachments.zig").spawn(world, projections);
        try self.multiplayer.spawn(world, slots, projections, episode, now);
        try self.cinematics.spawn(allocator, world);
        try self.scripts.init(allocator, world);
        try self.navigation.init(allocator, now, restart, resident);
    }
    pub fn step(self: *State, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, targets: *Router, now: i64, elapsed: u32, table: *const @import("../domain/weapons.zig").Table) !void {
        try @import("events.zig").expire(world, slots, projections, now);
        try @import("interactions.zig").touch(world, slots, projections, targets, now);
        const frame: system_context.Step = .{ .world = world, .slots = slots, .projections = projections, .targets = targets, .actors = &self.actors, .table = table, .now = now, .elapsed = elapsed };
        try run(systems.motion, "worldPrepare", &frame);
        try run(systems.motion, "worldMove", &frame);
        try @import("pusher.zig").staticRoots(world, slots, projections, now, elapsed);
        var arrivals: [systems.motion.len]system_context.Arrivals = undefined;
        inline for (systems.motion, 0..) |System, index| arrivals[index] = try System.worldFinish(&frame);
        inline for (systems.arrivals) |System| try System.worldArrive(&frame, &arrivals[comptime motionIndex(System)]);
        try @import("projectiles.zig").step(world, slots, projections, now);
        var weapon_step: @import("weapon_classes/registry.zig").Step = .{ .world = world, .slots = slots, .projections = projections, .table = table, .now = now };
        try @import("weapon_classes/registry.zig").step(&weapon_step);
        try @import("weapon_launches.zig").step(world, slots, projections, table, now);
        try @import("melee.zig").step(world, slots, projections, table, now);
        try run(systems.missiles, "worldStep", &frame);
        try @import("actor_lasers.zig").step(world, slots, projections, now);
        try @import("environment.zig").step(world, slots, projections, self.actors.episode, now);
        try @import("ailments.zig").step(world, now);
        try run(systems.observers, "worldStep", &frame);
        try self.navigation.frame(now);
        self.navigation.sync(projections);
        if (self.navigation.started) try self.gates.step(world, projections);
        if (!@import("cinematics.zig").active(world)) try self.actors.step(world, slots, projections, targets, self.navigation.service(), now, elapsed);
        if (!@import("cinematics.zig").active(world)) try @import("actor_audio.zig").step(&self.actors, world, slots, projections, now);
        if (!@import("cinematics.zig").active(world)) try run(systems.party, "worldStep", &frame);
        try @import("actor_attacks.zig").step(world, slots, projections, now);
        try run(systems.ambient, "worldStep", &frame);
        try @import("items.zig").step(world, slots, projections, targets, table, now, elapsed);
        try targets.step(world, slots, projections, now);
        try @import("world_controls.zig").step(world, slots, projections, targets, now);
        if (!@import("cinematics.zig").active(world)) try self.scripts.step(world, slots, projections, &self.actors, targets, now);
        try @import("world_actions.zig").step(world, slots, projections, targets, now);
        try self.multiplayer.step(world, slots, projections, targets, now);
    }
};
/// A motion system's index in `systems.motion`, pairing its finish with its arrivals.
fn motionIndex(comptime System: type) usize {
    inline for (systems.motion, 0..) |Other, index| if (Other == System) return index;
    @compileError("arriving system without a motion phase");
}
