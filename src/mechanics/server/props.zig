// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: physical props (domain/props.zig): publishing, expiry, spin, toss and bounce
//! physics, and explosion sprites. Classes that spawn props add their roles through the hooks in
//! prop_classes.zig; this module never names them.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const policy = @import("../domain/props.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const c = abi.c;
const Slots = @import("../../engine/slots.zig").Slots;
const v = @import("../../core/domain/vector.zig");
const roles = @import("../../game/server/prop_classes.zig").roles;
/// What a role's `propTick` receives.
pub const Tick = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    router: *@import("targets.zig").Router,
    entity: ecs.Entity,
    now: i64,
    elapsed: u32,
};
/// A contact's new velocity: the first role answering `propContact`, else the shared clip.
fn contact(world: *data.World, entity: ecs.Entity, state: *data.Scenery, velocity: v.Vec3, normal: v.Vec3) !v.Vec3 {
    inline for (roles) |Role| if (@hasDecl(Role, "propContact")) {
        if (try Role.propContact(world, entity, state, velocity, normal)) |answer| return answer;
    };
    return policy.contact(velocity, normal, state.movement == .bounce);
}
pub fn publish(world: *data.World, entity: ecs.Entity, projections: []abi.EntityProjection, now: i64) !void {
    const state = (try world.get(entity, data.Scenery)).*;
    const binding = (try world.get(entity, data.Binding)).*;
    const pose = (try world.get(entity, data.Transform)).*;
    const body = (try world.get(entity, data.Body)).*;
    const projection = &projections[binding.slot];
    projection.state.number = binding.slot;
    projection.state.eType = c.ET_GENERAL;
    projection.state.modelindex = binding.model;
    @import("../../engine/animation.zig").publish(&projection.state, .{ .sequence = state.sequence, .started = state.started_ms, .looping = state.looping }, now);
    if (state.gib != null or state.explosion) projection.state.time = @intCast(state.started_ms);
    projection.state.generic1 = if (state.explosion) policy.explosion_tag else policy.render_tag;
    projection.state.time2 = @intFromFloat(state.alpha * 255);
    projection.state.clientNum = if (state.gib) |gib| if (gib.skin_model.len > 0) try @import("resources.zig").model(gib.skin_model) else 0 else 0;
    projection.state.weapon = if (state.gib) |gib| @as(i32, 1) | (if (gib.no_blood) @as(i32, 2) else 0) | (if (gib.bone) @as(i32, 4) else 0) else if (state.explosive_fragment) 8 else 0;
    projection.state.angles2 = state.scale;
    projection.state.pos = @import("../../engine/trajectory.zig").interpolated(pose.position);
    projection.state.apos = @import("../../engine/trajectory.zig").interpolated(pose.angles);
    projection.state.pos.trDelta = (try world.get(entity, data.Velocity)).linear;
    if (state.corpse) |corpse| {
        projection.state.eType = c.ET_PLAYER;
        projection.state.eFlags = c.EF_DEAD;
        projection.state.dk3BodyAppearance = @as(i32, corpse.appearance) + 1;
        projection.state.time2 = 0;
        projection.state.modelindex = if ((try world.get(entity, data.Hurt)).feedback.gibbed) 0 else binding.model;
    }
    projection.shared.currentOrigin = pose.position;
    projection.shared.currentAngles = pose.angles;
    projection.shared.mins = body.mins;
    projection.shared.maxs = body.maxs;
    projection.shared.contents = @bitCast(body.contents);
    projection.shared.ownerNum = c.ENTITYNUM_NONE;
    if (state.broken) projection.shared.svFlags |= c.SVF_NOCLIENT;
    engine.link(projection);
}

pub fn step(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *@import("targets.zig").Router, now: i64, elapsed: u32) !void {
    const occupants = slots.occupants;
    for (occupants) |occupant| {
        const entity = occupant orelse continue;
        if (!world.alive(entity)) continue;
        var state = world.get(entity, data.Scenery) catch continue;
        if (state.broken) continue;
        var aged = false;
        inline for (roles) |Role| if (@hasDecl(Role, "propAge")) {
            if (!aged) aged = try Role.propAge(world, entity, state, now);
        };
        if (aged) {
            try @import("weapon_entities.zig").remove(world, slots, projections, entity);
            continue;
        }
        if (state.expires_ms) |deadline| if (now >= deadline) {
            try @import("weapon_entities.zig").remove(world, slots, projections, entity);
            continue;
        };
        var tick: Tick = .{ .world = world, .slots = slots, .projections = projections, .router = router, .entity = entity, .now = now, .elapsed = elapsed };
        var consumed = false;
        inline for (roles) |Role| if (@hasDecl(Role, "propTick")) {
            // A role may add components, moving the prop's state.
            if (!consumed) consumed = try Role.propTick(&tick, try world.get(entity, data.Scenery));
        };
        if (consumed) continue;
        state = try world.get(entity, data.Scenery);
        const pose = try world.get(entity, data.Transform);
        const body = try world.get(entity, data.Body);
        const velocity = try world.get(entity, data.Velocity);
        const slot = (try world.get(entity, data.Binding)).slot;
        if (!@import("attachments.zig").attached(world, entity)) {
            if (!body.grounded or !state.fragment) pose.angles = v.add(pose.angles, v.scale(state.spin, @as(f32, @floatFromInt(elapsed)) * 0.001));
            if (state.movement != .stationary) {
                var remaining = elapsed;
                while (remaining > 0) {
                    const delta = @as(f32, @floatFromInt(@min(remaining, 50))) * 0.001;
                    remaining -= @min(remaining, 50);
                    velocity.linear[2] -= (if (world.get(entity, data.Gravity) catch null) |gravity| gravity.acceleration else 800) * delta;
                    const hit = try engine.collisionService().trace(.{ .start = pose.position, .end = v.add(pose.position, v.scale(velocity.linear, delta)), .mins = body.mins, .maxs = body.maxs, .slot = slot, .mask = body.collision_mask });
                    if (hit.start_solid or hit.all_solid) {
                        velocity.linear = @splat(0);
                        break;
                    }
                    pose.position = hit.end;
                    body.grounded = false;
                    if (hit.fraction < 1) {
                        velocity.linear = try contact(world, entity, state, velocity.linear, hit.normal);
                        body.grounded = hit.normal[2] > 0.7 and velocity.linear[2] == 0;
                        projections[slot].state.groundEntityNum = if (body.grounded) hit.entity else c.ENTITYNUM_NONE;
                    }
                }
            }
        }
        try publish(world, entity, projections, now);
    }
}

pub fn explosion(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, origin: data.Vec3, scale: f32, now: i64) !void {
    try explosionVariant(world, slots, projections, origin, scale, false, now);
}
pub fn explosionOwned(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, owner: u32, origin: data.Vec3, scale: f32, now: i64) !void {
    if (owner == 0) return explosion(world, slots, projections, origin, scale, now);
    const context = @import("region_access.zig").byHandle(@enumFromInt(owner)) orelse return error.ExplosionWorldUnavailable;
    const scope = try context.select();
    defer scope.deinit();
    try explosion(&context.world.?, &context.slots, &context.projection, origin, scale, now);
}
pub fn explosionVariant(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, origin: data.Vec3, scale: f32, alternate: bool, now: i64) !void {
    const model = if (alternate) "models/global/we_expla.sp2" else "models/global/we_expl.sp2";
    const effect = try world.create(null, .{ data.Transform{ .position = origin }, data.Velocity{}, data.Body{ .mins = @splat(0), .maxs = @splat(0) }, data.Scenery{ .model = model, .started_ms = now, .scale = @splat(scale), .explosion = true, .sequence = .{ .last = if (alternate) 7 else 6 }, .expires_ms = now + @as(i64, if (alternate) 800 else 700) } });
    errdefer world.destroy(effect) catch unreachable;
    try @import("weapon_entities.zig").bind(world, slots, projections, effect, model);
    try publish(world, effect, projections, now);
}
/// World-system hook (world_system_classes.zig).
pub fn worldStep(frame: *const @import("system_context.zig").Step) !void {
    try step(frame.world, frame.slots, frame.projections, frame.targets, frame.now, frame.elapsed);
}

/// Restored or transferred entities carrying these components are projected here (projection_classes.zig).
pub const projected = .{data.Scenery};
pub fn project(projecting: *const @import("system_context.zig").Project) !bool {
    try publish(projecting.world, projecting.entity, projecting.projections, projecting.now);
    return true;
}
