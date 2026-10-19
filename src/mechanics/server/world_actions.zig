// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Destructible controls, switchable geometry, hurt volumes and authored target timelines.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const rules = @import("../domain/world_actions.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const c = abi.c;
const Slots = @import("../../engine/slots.zig").Slots;
const Router = @import("targets.zig").Router;
const prop = @import("properties.zig");
const v = @import("../../core/domain/vector.zig");
/// Shows or hides a volume and sets its contents.
pub fn publishVolume(world: *data.World, entity: ecs.Entity, projections: []abi.EntityProjection, visible: bool, contents: u32) !void {
    const slot = (try world.get(entity, data.Binding)).slot;
    (try world.get(entity, data.Body)).contents = contents;
    projections[slot].shared.contents = @bitCast(contents);
    if (visible) projections[slot].shared.svFlags &= ~@as(i32, c.SVF_NOCLIENT) else projections[slot].shared.svFlags |= c.SVF_NOCLIENT;
    engine.link(&projections[slot]);
}
/// Hazards, walls, destructibles and target timelines are prepared by their classes.
pub fn spawn(allocator: std.mem.Allocator, world: *data.World, projections: []abi.EntityProjection) !void {
    try @import("entity_classes/registry.zig").prepareAll(.volumes, allocator, world, projections);
}
/// What a breakable brush class's hooks receive (destructible_classes.zig).
pub const Destructing = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    router: *Router,
    entity: ecs.Entity,
    activator: u32,
    now: i64,
};
const destructibles = @import("../../game/server/destructible_classes.zig").classes;
fn slotsBinding(world: *data.World, entity: ecs.Entity) ?data.Binding {
    return if (world.get(entity, data.Binding)) |binding| binding.* else |_| null;
}
pub fn activate(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *Router, entity: ecs.Entity, activator: u32, now: i64) anyerror!bool {
    if (world.get(entity, data.Hazard)) |hazard| {
        if (hazard.toggleable) {
            hazard.enabled = !hazard.enabled;
            try publishVolume(world, entity, projections, false, if (hazard.enabled) c.CONTENTS_TRIGGER else 0);
        }
        return true;
    } else |_| {}
    if (world.get(entity, data.Wall)) |wall| {
        if (wall.used and !wall.toggleable) return true;
        wall.used = true;
        wall.visible = !wall.visible;
        try publishVolume(world, entity, projections, wall.visible, if (wall.visible and !wall.nonsolid) c.CONTENTS_SOLID else 0);
        try router.fire(world, slots, projections, entity, activator, now);
        return true;
    } else |_| {}
    if ((world.get(entity, data.Destructible) catch null) != null) {
        var destructing: Destructing = .{ .world = world, .slots = slots, .projections = projections, .router = router, .entity = entity, .activator = activator, .now = now };
        inline for (destructibles) |Class| if (try Class.destructibleUse(&destructing)) return true;
        return true;
    }
    if (world.get(entity, data.TargetSequence)) |sequence| {
        // The reference admits a use by flags alone: a dying monster's deathtarget starts a
        // monster-allowed generator (e1m7b's end_count -> end_events frees the Daikatana).
        // Dead bodies are already excluded where the volume is touched.
        const owner = world.find(activator) orelse return true;
        if ((world.get(owner, data.Player) catch null) == null and (!sequence.actor_allowed or (world.get(owner, data.Actor) catch null) == null)) return true;
        if (sequence.start(activator, now)) {
            const sound = sequence.sound;
            if (sound.len > 0) {
                const position = (try world.get(entity, data.Transform)).position;
                const slot: u16 = if (slotsBinding(world, entity)) |binding| binding.slot else c.ENTITYNUM_NONE;
                try @import("events.zig").sound(world, slots, projections, sound, position, slot, c.CHAN_AUTO, now);
            }
        }
        return true;
    } else |_| {}
    return false;
}
pub fn step(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *Router, now: i64) !void {
    var sequences: [ecs.max_entities]ecs.Entity = undefined;
    var count: usize = 0;
    var query = world.queryAccess(data.World.mask(.{data.TargetSequence}), 0, 0);
    {
        defer query.deinit();
        while (query.next()) |view| for (view.entities()) |entity| {
            sequences[count] = entity;
            count += 1;
        };
    }
    for (sequences[0..count]) |entity| while (world.alive(entity)) {
        const state = try world.get(entity, data.TargetSequence);
        const name = state.next(now) orelse break;
        const owner = state.activator;
        try router.fireNamed(world, slots, projections, name, entity, owner, now);
    };
    const occupants = slots.occupants;
    for (occupants) |occupant| {
        const entity = occupant orelse continue;
        if (!world.alive(entity)) continue;
        if ((world.get(entity, data.Destructible) catch null) != null) {
            var destructing: Destructing = .{ .world = world, .slots = slots, .projections = projections, .router = router, .entity = entity, .activator = 0, .now = now };
            var stepped = false;
            inline for (destructibles) |Class| if (!stepped) {
                stepped = try Class.destructibleStep(&destructing);
            };
            if (stepped) continue;
        }
        if (!world.alive(entity)) continue;
    }
    try @import("campaign_rules.zig").repairHazards(world, projections);
    for (occupants) |occupant| {
        const entity = occupant orelse continue;
        if (!world.alive(entity)) continue;
        const hazard = (world.get(entity, data.Hazard) catch continue).*;
        if (!hazard.enabled or now < hazard.ready_ms) continue;
        const slot = (try world.get(entity, data.Binding)).slot;
        var contacted = false;
        for (occupants, 0..) |candidate, target_slot| {
            const target = candidate orelse continue;
            if (!world.alive(target)) continue;
            const health = world.get(target, data.Health) catch continue;
            if (health.current <= 0) continue;
            if (world.get(target, data.Player)) |player| {
                if (player.mode != .normal) continue;
            } else |_| if ((world.get(target, data.Actor) catch null) == null) continue;
            if (!@import("interactions.zig").overlap(&projections[slot], &projections[target_slot], 1)) continue;
            const result = try @import("damage.zig").apply(world, target, hazard.damage, now, .{ .source = try world.persistentId(entity), .environmental = true });
            if (engine.integer("developer") != 0 and result.blood > 0) {
                var text: [140]u8 = undefined;
                engine.print(try std.fmt.bufPrintZ(&text, "dk3 zig hazard hit: id={d} target={d} blood={d}\n", .{ try world.persistentId(entity), try world.persistentId(target), result.blood }));
            }
            contacted = true;
        }
        if (contacted) {
            (try world.get(entity, data.Hazard)).ready_ms = now + hazard.interval_ms;
            if (hazard.sound.len > 0) try @import("events.zig").sound(world, slots, projections, hazard.sound, projections[slot].shared.currentOrigin, slot, c.CHAN_AUTO, now);
        }
    }
}
