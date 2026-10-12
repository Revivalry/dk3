// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: burst fire in progress, by style (actors/bursts.zig); cadence follows the
//! reference server tick.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const Ref = @import("../domain/world_references.zig").Ref;
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const c = abi.c;
const v = @import("../../core/domain/vector.zig");
const Slots = @import("../../engine/slots.zig").Slots;
/// The mechanism whose `attack_payloads` this module steps and publishes (attack_classes.zig).
pub const policy = @import("actor_catalog").bursts;
const lifecycle = @import("weapon_entities.zig");
pub fn launch(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, owner: ecs.Entity, target: Ref, pose: data.Transform, kind: policy.Kind, two_hands: bool, tuning: @import("actor_catalog").weapon.Tuning, now: i64) !void {
    // The reference's temporary gun entity shoots once before its think callbacks. Use the
    // owner's muzzle; its unplaced temporary origin is not a valid firing location in maps whose
    // world origin is outside playable space.
    if (policy.style(kind).opening_shot) _ = try @import("actor_bullets.zig").fire(world, slots, projections, owner, target, pose, tuning, now);
    const entity = try world.create(null, .{ pose, data.Velocity{}, data.Body{ .mins = @splat(0), .maxs = @splat(0) }, data.ActorAttack{ .owner = try world.persistentId(owner), .born_ms = now, .stepped_ms = now, .attack = .{ .gunner_burst = .{ .kind = kind, .tuning = tuning, .two_hands = two_hands, .next_ms = now + policy.firstDelay(kind) } } } });
    errdefer world.destroy(entity) catch unreachable;
    try lifecycle.bind(world, slots, projections, entity, "");
    try publish(world, entity, projections, now);
}
pub fn publish(world: *data.World, entity: ecs.Entity, projections: []abi.EntityProjection, now: i64) !void {
    _ = now;
    const attack = (try world.get(entity, data.ActorAttack)).*;
    const burst = attack.attack.gunner_burst;
    const owner = world.find(attack.owner) orelse return;
    const pose = (try world.get(owner, data.Transform)).*;
    const binding = (try world.get(entity, data.Binding)).*;
    const projection = &projections[binding.slot];
    projection.state.number = binding.slot;
    projection.state.eType = c.ET_GENERAL;
    projection.state.generic1 = policy.render_tag;
    projection.state.weapon = @intFromEnum(burst.kind);
    projection.state.otherEntityNum = (try world.get(owner, data.Binding)).slot;
    projection.state.frame = @intFromBool(burst.two_hands);
    projection.state.time = @intCast(attack.born_ms);
    projection.state.time2 = @intCast(burst.shots);
    projection.state.pos = @import("../../engine/trajectory.zig").stationary(pose.position);
    projection.shared.currentOrigin = pose.position;
    projection.shared.ownerNum = projection.state.otherEntityNum;
    projection.shared.contents = 0;
    engine.link(projection);
}
pub fn step(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, now: i64) !void {
    var attack = (try world.get(entity, data.ActorAttack)).*;
    var burst = attack.attack.gunner_burst;
    const owner = world.find(attack.owner) orelse return lifecycle.remove(world, slots, projections, entity);
    const actor = (world.get(owner, data.Actor) catch return lifecycle.remove(world, slots, projections, entity)).*;
    const target = @import("region_access.zig").find(world, actor.threat) orelse return lifecycle.remove(world, slots, projections, entity);
    while (burst.next_ms <= now) {
        const style = policy.style(burst.kind);
        if (style.flash_only) return lifecycle.remove(world, slots, projections, entity);
        _ = try @import("actor_bullets.zig").fire(world, slots, projections, owner, target, (try world.get(owner, data.Transform)).*, burst.tuning, burst.next_ms);
        attack.stepped_ms = burst.next_ms;
        burst.next_ms += policy.tick_ms;
        burst.shots +|= 1;
        // A frame stop is an absolute model frame, including non-attack poses.
        const frame = projections[(try world.get(owner, data.Binding)).slot].state.frame;
        if (if (style.shots != 0) burst.shots >= style.shots else frame >= style.stop_frame) return lifecycle.remove(world, slots, projections, entity);
    }
    attack.attack.gunner_burst = burst;
    (try world.get(entity, data.ActorAttack)).* = attack;
    try publish(world, entity, projections, now);
}
/// A burst is its shooter's running action (actor_attacks.zig dispatches only bursts here).
pub fn actionOwner(attack: *const data.ActorAttack) ?u32 {
    return attack.owner;
}
/// A burst's projection names its shooter (actor_attacks.zig).
pub fn linkedOwner(attack: *const data.ActorAttack) ?u32 {
    return attack.owner;
}
