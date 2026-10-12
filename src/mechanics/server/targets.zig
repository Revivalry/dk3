// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Bounded target routing; authored behavior remains in concrete systems.
const std = @import("std");
const classes = @import("actor_classes/registry.zig");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const named = @import("names.zig").named;
const prop = @import("properties.zig");
const uses = @import("../../game/server/use_classes.zig");
/// Runs one use stage: the first class that handles the use ends it.
fn useStage(comptime stage: anytype, using: *@import("entity_classes/registry.zig").Use) !bool {
    inline for (stage) |Class| if (try Class.useTarget(using)) return true;
    return false;
}
const c = abi.c;
const Trigger = data.Trigger;
pub const Router = struct {
    pending: @import("../domain/target_actions.zig").Queue = @splat(null),
    depth: usize = 0,
    scripts: ?*const @import("scripts.zig").State = null,
    cinematics: ?*@import("cinematics.zig").State = null,
    actors: ?*@import("actors.zig").Actors = null,
    travel: ?@import("../domain/travel.zig").Request = null,
    /// An actor class's own response to being used, before or after authored scripts.
    fn useActor(self: *Router, world: *data.World, slots: *Slots, entity: ecs.Entity, after_scripts: bool, now: i64) !bool {
        const actor = world.get(entity, data.Actor) catch return false;
        const kind = @import("actor_catalog").entries[actor.definition].kind;
        if (classes.useAfterScripts(kind) != after_scripts) return false;
        var using: classes.Use = .{ .actors = self.actors, .world = world, .slots = slots, .entity = entity, .actor = actor, .now = now };
        return classes.use(kind, &using);
    }
    pub fn activate(self: *Router, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, activator: u32, now: i64) anyerror!void {
        return self.activateFrom(world, slots, projections, entity, null, activator, now);
    }
    pub fn activateFrom(self: *Router, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, source: ?@import("../domain/world_references.zig").Ref, activator: u32, now: i64) anyerror!void {
        if (self.depth >= 64) return error.TargetCycle;
        self.depth += 1;
        defer self.depth -= 1;
        const object = (try world.get(entity, data.MapObject)).*;
        if (!@import("locks.zig").allows(world, object, activator)) return;
        if ((world.get(entity, data.WorldControl) catch null) != null) return @import("world_controls.zig").use(world, slots, projections, self, entity, activator, now);
        var using: @import("entity_classes/registry.zig").Use = .{ .router = self, .world = world, .slots = slots, .projections = projections, .entity = entity, .object = object, .source = source, .activator = activator, .now = now };
        if (try useStage(uses.before_actors, &using)) return;
        if (try self.useActor(world, slots, entity, false, now)) return;
        if (self.scripts) |scripts| if (try scripts.use(world, entity, activator, now)) return;
        if (try useStage(uses.after_scripts, &using)) return;
        if (try @import("entity_classes/registry.zig").useAuthored(&using)) return;
        if (try useStage(uses.after_authored, &using)) return;
        if (try @import("world_actions.zig").activate(world, slots, projections, self, entity, activator, now)) return;
        if (try self.useActor(world, slots, entity, true, now)) return;
        if (try useStage(uses.after_actors, &using)) return;
        if (world.get(entity, data.Trigger)) |trigger| {
            if (now < trigger.ready_ms or (trigger.limit > 0 and trigger.uses >= trigger.limit)) return;
            trigger.uses += 1;
            if (trigger.counter and trigger.uses < trigger.limit) return;
            trigger.ready_ms = now + trigger.wait_ms;
            try self.fire(world, slots, projections, entity, activator, now);
        } else |_| {}
    }
    pub fn fire(self: *Router, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, activator: u32, now: i64) anyerror!void {
        const object = (try world.get(entity, data.MapObject)).*;
        const delay = try prop.milliseconds(object, "delay", 0);
        if (delay < 0 or delay > 3600000) return error.InvalidTargetDelay;
        if (delay > 0) {
            for (&self.pending) |*item| if (item.* == null) {
                item.* = .{ .source = try world.persistentId(entity), .activator = activator, .due_ms = now + delay };
                return;
            };
            return error.TargetQueueCapacity;
        }
        try self.dispatch(world, slots, projections, entity, activator, now);
    }
    pub fn fireImmediate(self: *Router, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, activator: u32, now: i64) anyerror!void {
        try self.dispatch(world, slots, projections, entity, activator, now);
    }
    fn dispatch(self: *Router, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, activator: u32, now: i64) anyerror!void {
        const object = (try world.get(entity, data.MapObject)).*;
        const own_id = try world.persistentId(entity);
        const home = try @import("region_access.zig").authored(world, entity);
        const lookup_world = if (home) |context| &context.world.? else world;
        const killed = prop.text(object, "killtarget") orelse "";
        if (killed.len > 0) {
            const victims = try named(lookup_world, killed);
            for (victims.ids[0..victims.count]) |id| {
                if (id == own_id) continue;
                const victim = @import("region_access.zig").find(lookup_world, id) orelse continue;
                if (victim.world != world) {
                    const context = @import("region_access.zig").contextFor(victim.world) orelse return error.TargetWorldUnavailable;
                    const scope = try context.select();
                    defer scope.deinit();
                    inline for (uses.killed) |Class| try Class.killed(victim.world, victim.entity);
                    if (context.slots.find(victim.entity)) |slot| {
                        engine.unlink(&context.projection[slot]);
                        try context.slots.release(slot, victim.entity);
                    }
                    try victim.world.destroy(victim.entity);
                } else {
                    inline for (uses.killed) |Class| try Class.killed(world, victim.entity);
                    if (slots.find(victim.entity)) |slot| {
                        engine.unlink(&projections[slot]);
                        try slots.release(slot, victim.entity);
                    }
                    try world.destroy(victim.entity);
                }
            }
        }
        for ([_][]const u8{ object.target, prop.text(object, "target2") orelse "", prop.text(object, "target3") orelse "", prop.text(object, "target4") orelse "" }) |name| {
            if (name.len == 0) continue;
            const matches = try named(lookup_world, name);
            for (matches.ids[0..matches.count]) |id| {
                if (!world.alive(entity)) return;
                if (id == own_id) continue;
                if (@import("region_access.zig").find(lookup_world, id)) |target| try self.activateReference(world, slots, projections, target, .{ .world = world, .entity = entity }, activator, now);
            }
        }
    }
    pub fn fireNamed(self: *Router, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, name: []const u8, source: ecs.Entity, activator: u32, now: i64) anyerror!void {
        if (name.len == 0) return;
        const access = @import("region_access.zig");
        const home = try access.authored(world, source);
        const lookup_world = if (home) |context| &context.world.? else world;
        const matches = try named(lookup_world, name);
        for (matches.ids[0..matches.count]) |id| {
            if (!world.alive(source)) return;
            const target = access.find(lookup_world, id) orelse continue;
            try self.activateReference(world, slots, projections, target, .{ .world = world, .entity = source }, activator, now);
        }
    }
    pub fn activateReference(self: *Router, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, target: @import("../domain/world_references.zig").Ref, source: ?@import("../domain/world_references.zig").Ref, activator: u32, now: i64) anyerror!void {
        if (target.world == world) return self.activateFrom(world, slots, projections, target.entity, source, activator, now);
        const context = @import("region_access.zig").contextFor(target.world) orelse return error.TargetWorldUnavailable;
        const scope = try context.select();
        defer scope.deinit();
        try context.expose(now);
        try context.targets.activateFrom(target.world, &context.slots, &context.projection, target.entity, source, activator, now);
    }
    pub fn step(self: *Router, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, now: i64) !void {
        // Newly scheduled work waits until the next frame, preserving a bounded barrier.
        const current = self.pending;
        for (current, 0..) |entry, index| if (entry) |action| {
            if (action.due_ms > now) continue;
            self.pending[index] = null;
            if (@import("region_access.zig").find(world, action.source)) |source| {
                if (source.world == world) try self.dispatch(world, slots, projections, source.entity, action.activator, now) else {
                    const context = @import("region_access.zig").contextFor(source.world) orelse return error.TargetWorldUnavailable;
                    const scope = try context.select();
                    defer scope.deinit();
                    try context.targets.dispatch(source.world, &context.slots, &context.projection, source.entity, action.activator, now);
                }
            }
        };
    }
};
/// Trigger limits and counters are prepared by their classes.
pub fn spawn(world: *data.World) !void {
    try @import("entity_classes/registry.zig").prepareAll(.triggers, std.heap.page_allocator, world, &.{});
}
