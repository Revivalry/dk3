// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: ground melee. Perception, pain, facing, attack choice and authored strike
//! events for classes that fight on foot; each class supplies a `Spec` from its adapter.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const Ref = @import("../domain/world_references.zig").Ref;
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const v = @import("../../core/domain/vector.zig");
const rules = @import("../domain/actors.zig");
const c = abi.c;
const catalog = @import("actor_catalog");
const Frame = @import("actor_classes/frame.zig").Frame;
const Admission = @import("actor_classes/frame.zig").Admission;
const Slots = @import("../../engine/slots.zig").Slots;

/// The engagement a class decides on.
pub const Choice = struct {
    target: Ref,
    distance: f32,
    visible: bool,
    /// The previous attack clip finished this step.
    completed: bool,
};
/// One authored strike being delivered.
pub const Strike = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    entity: ecs.Entity,
    actor: *data.Actor,
    pose: data.Transform,
    definition: *const rules.Definition,
    target: Ref,
    now: i64,
};
/// How a hit may interrupt the class with its pain clip.
pub const Pain = union(enum) {
    /// The reference's generic pain handler with this chance (percent) and damage limit.
    generic: struct { chance: u8, limit: i32 },
    /// Any damage plays the pain clip with this chance; damage of at least `heavy` plays the
    /// second clip. The reference's `AI_StartPain` skips the hit that makes a player the enemy;
    /// a class whose own pain callback flinches regardless clears `skips_acquiring`.
    roll: struct { chance: f32, heavy: ?i32 = null, skips_acquiring: bool = true },
};
/// What a ground melee class supplies. Unset hooks keep the shared behaviour.
pub const Spec = struct {
    pain: Pain,
    /// Chooses the attack clip to start.
    select: *const fn (*Frame, Choice, f32) anyerror!u3,
    /// Holds the step while it returns true (dormant or waking classes).
    gate: ?*const fn (*Frame, bool) anyerror!bool = null,
    /// No enemy in sight.
    calm: ?*const fn (*Frame) anyerror!void = null,
    /// An enemy is in sight.
    alert: ?*const fn (*Frame) void = null,
    /// Degrees within which the actor counts as facing its enemy.
    facing_degrees: f32 = 8,
    /// Distance within which an attack can start; the aidata attack distance by default.
    reach: ?*const fn (*const rules.Definition) f32 = null,
    /// For a class whose reach is a random roll: while no attack starts it keeps closing in until
    /// this distance (its sure reach) instead of standing at `reach`.
    sure_reach: ?*const fn (*const rules.Definition) f32 = null,
    /// A final say over an admitted attack: class range rolls, or evading instead.
    admit: ?*const fn (*Frame, Choice) anyerror!Admission = null,
    /// A transition clip to play before `to`, when the model has one.
    transition: ?*const fn (*const rules.Definition, u3, u3) ?u3 = null,
    /// Attack clips during which the actor keeps moving.
    moving: ?*const fn (u3) bool = null,
    /// After an attack begins.
    begun: ?*const fn (*Frame, Choice, u3) anyerror!void = null,
    /// A moving attack always chases; otherwise it chases only beyond `close_distance`.
    moving_chases: bool = false,
    close_distance: f32 = 40,
    events: Events = .{},
};
/// How a class's authored strike events land. Also used by classes that run their own think.
pub const Events = struct {
    /// Attack clips from this index on carry no events.
    silent_from: ?u3 = null,
    /// Only each clip's first strike lands.
    single_strike: bool = false,
    /// The clip whose strike is a leap: it is timed by the jump strike, lands once, and lands
    /// without facing.
    jump_pose: ?u3 = null,
    /// Strikes land whether or not the actor faces its enemy.
    unfaced: bool = false,
    /// A clip whose strike lands without facing.
    unfaced_pose: ?u3 = null,
    /// Strikes aim where the enemy is going.
    leading: bool = false,
    /// Before strikes: launches a leap at the clip's sound frame.
    leap: ?*const fn (*const Strike) anyerror!void = null,
    /// Replaces the strike with a class launch when it returns true.
    launch: ?*const fn (*const Strike) anyerror!bool = null,
    /// The reference's punch: when a strike's trace hits anything (a wall too) the clip's second
    /// sound plays. A class whose weapon is silent on impact clears it.
    hit_sound: bool = true,
    /// After a strike damaged the enemy (its health before the strike).
    struck: ?*const fn (*const Strike, i32) anyerror!void = null,
};

pub fn think(comptime spec: Spec, frame: *Frame) !void {
    const world = frame.world;
    const entity = frame.entity;
    const actor = frame.actor;
    const pose = frame.pose;
    const definition = frame.definition;
    const now = frame.now;
    const hurt = frame.hurt;
    const newly_hurt = hurt.revision != actor.receipt;
    const previous_threat = actor.threat;
    const perceived = try @import("actor_perception.zig").perceive(world, frame.slots, entity, actor, pose.*, definition.*, now);
    if (spec.gate) |gate| if (try gate(frame, perceived.visible)) return;
    if (actor.reaction_until_ms) |deadline| {
        if (now < deadline) {
            actor.mode = .idle;
            return;
        }
        actor.reaction = null;
        actor.reaction_until_ms = null;
    }
    switch (spec.pain) {
        .generic => |generic| if (newly_hurt and try @import("actor_pain.zig").generic(world, entity, actor, definition.*, hurt, previous_threat, generic.chance, generic.limit, now)) return,
        // A single roll (the reference's `AI_StartPain`); the hit that makes a player the enemy
        // only acquires him.
        .roll => |roll| if (newly_hurt and hurt.amount > 0 and !(roll.skips_acquiring and @import("actor_pain.zig").acquiring(world, hurt, previous_threat))) {
            const random = (try world.get(entity, data.Random)).next();
            const heavy = if (roll.heavy) |limit| hurt.amount >= limit else false;
            if (random < roll.chance) if (definition.pain[if (heavy) @as(usize, 1) else 0]) |sequence| {
                actor.reaction = sequence;
                actor.reaction_started_ms = now;
                actor.reaction_until_ms = now + sequence.lastFrameMs();
                actor.melee.active = false;
                actor.mode = .idle;
                return;
            };
        },
    }
    const target = perceived.enemy orelse {
        if (spec.calm) |calm| try calm(frame);
        actor.mode = .idle;
        actor.melee.active = false;
        return;
    };
    if (spec.alert) |alert| alert(frame);
    if (@import("actor_evasion.zig").update(actor, pose.*, now)) return;
    const delta = v.subtract(actor.threat_position, pose.position);
    const yaw = std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi;
    const turn = @mod(yaw - pose.angles[1] + 180, 360) - 180;
    const decision_tick = now >= actor.think_ms;
    if (decision_tick) {
        pose.angles[1] += std.math.clamp(turn, -definition.yaw_speed, definition.yaw_speed);
        actor.think_ms = now + 100;
    }
    const facing = @abs(@mod(yaw - pose.angles[1] + 180, 360) - 180) <= spec.facing_degrees;
    const reach = if (spec.reach) |reach| reach(definition) else definition.attack_range;
    const reachable = perceived.visible and perceived.distance < reach;
    // Deliver every crossed authored event before completing its animation. A
    // slow frame must not erase a final strike or sound.
    if (actor.melee.active) try emit(spec.events, strikeOf(frame, target), facing);
    const completed = actor.melee.active and now - actor.melee.started_ms >= definition.attacks[actor.melee.pose].lastFrameMs();
    if (completed) {
        if (actor.melee.next_pose) |next| actor.melee.begin(next, now) else actor.melee.active = false;
    }
    const choice: Choice = .{ .target = target, .distance = perceived.distance, .visible = perceived.visible, .completed = completed };
    var admitted = decision_tick and !actor.melee.active and facing and reachable;
    if (admitted) if (spec.admit) |admit| switch (try admit(frame, choice)) {
        .admit => {},
        .refuse => admitted = false,
        .stop => return,
    };
    if (admitted) {
        const random = (try world.get(entity, data.Random)).next();
        const chosen = try spec.select(frame, choice, random);
        const transition = if (spec.transition) |transition| transition(definition, actor.melee.pose, chosen) else null;
        actor.melee.begin(transition orelse chosen, now);
        actor.melee.next_pose = if (transition != null) chosen else null;
        actor.melee.moving = if (spec.moving) |moving| moving(chosen) else false;
        if (spec.begun) |begun| try begun(frame, choice, chosen);
        actor.changed_ms = now;
    }
    actor.mode = if (actor.melee.active) if (actor.melee.moving and (spec.moving_chases or perceived.distance >= spec.close_distance)) .chase else .attack else if (!reachable or (if (spec.sure_reach) |sure| perceived.distance >= sure(definition) else false)) .chase else .idle;
    if (actor.melee.active) try emit(spec.events, strikeOf(frame, target), facing);
}
/// Delivers the current attack clip's crossed sound and strike events.
pub fn emit(comptime events: Events, strike: Strike, facing: bool) !void {
    const world = strike.world;
    const entity = strike.entity;
    const actor = strike.actor;
    const pose = strike.pose;
    const definition = strike.definition;
    const target = strike.target;
    const now = strike.now;
    const index = actor.melee.pose;
    if (events.silent_from) |silent| if (index >= silent) return;
    const sequence = definition.attacks[index];
    const slot = (try world.get(entity, data.Binding)).slot;
    try @import("actor_attack_sounds.zig").emit(world, strike.slots, strike.projections, entity, actor, pose.position, definition.*, now);
    if (events.leap) |launch_leap| try launch_leap(&strike);
    const jump = events.jump_pose != null and index == events.jump_pose.?;
    const unfaced = events.unfaced or jump or (events.unfaced_pose != null and index == events.unfaced_pose.?);
    const strikes = [_]?u16{ definition.strikes[index], definition.second_strikes[index] };
    for (strikes, 0..) |strike_frame, i| if (strike_frame) |frame| {
        if ((events.single_strike or jump) and i == 1) continue;
        const at = if (jump) definition.jump_strike_ms orelse continue else @divTrunc(@as(i64, frame) * 1000, sequence.fps);
        if (!actor.melee.event(@as(u2, 1) << @intCast(i), at, now, false) or (!facing and !unfaced)) continue;
        if (events.launch) |launch| if (try launch(&strike)) continue;
        const axes = v.basis(pose.angles);
        const start = v.add(pose.position, v.add(v.scale(axes.right, definition.offset[0]), v.add(v.scale(axes.forward, definition.offset[1]), .{ 0, 0, definition.offset[2] })));
        const body = (try target.get(data.Body)).*;
        const aim = v.add((try target.get(data.Transform)).position, v.scale(v.add(body.mins, body.maxs), 0.5));
        const leading: ?@import("actor_aim.zig").Aim = if (events.leading) try @import("actor_aim.zig").lead(world, target, pose, definition.offset, try world.get(entity, data.Random)) else null;
        const hit = try @import("region_collision.zig").from(if (leading) |value| value.world else try @import("actor_aim.zig").originOwner(world, pose.position, start), .{ .start = if (leading) |value| value.origin else start, .end = if (leading) |value| v.add(value.origin, v.scale(value.direction, definition.range)) else v.add(start, v.scale(v.normalize(v.subtract(aim, start)), definition.range)), .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = c.MASK_SHOT }, try world.persistentId(entity));
        if (events.hit_sound and (hit.fraction < 1 or hit.start_solid)) try @import("events.zig").soundAt(world, strike.slots, strike.projections, entity, definition.second_attack_sounds[index], now);
        if (@import("region_access.zig").victim(world, strike.slots, hit)) |victim| {
            const random = (try world.get(entity, data.Random)).next();
            const before = if (target.get(data.Health) catch null) |health| health.current else 0;
            _ = try @import("damage.zig").apply(victim.world, victim.entity, @intFromFloat(@ceil(definition.damage + random * definition.random_damage)), now, .{ .source = try world.persistentId(entity), .attacker_class = catalog.entries[actor.definition].classname });
            if (events.struck) |struck| try struck(&strike, before);
        }
    };
}
pub fn strikeOf(frame: *Frame, target: Ref) Strike {
    return .{ .world = frame.world, .slots = frame.slots, .projections = frame.projections, .entity = frame.entity, .actor = frame.actor, .pose = frame.pose.*, .definition = frame.definition, .target = target, .now = frame.now };
}
/// Gives the actor a leap along its facing at `speed`, leaving the ground.
pub fn leap(strike: *const Strike, speed: f32) !void {
    const velocity = try strike.world.get(strike.entity, data.Velocity);
    velocity.linear = v.scale(v.basis(strike.pose.angles).forward, speed);
    velocity.linear[2] = strike.definition.upward_speed;
    strike.actor.ground_entity = c.ENTITYNUM_NONE;
}
