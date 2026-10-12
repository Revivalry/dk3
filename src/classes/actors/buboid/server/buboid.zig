// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: buboid. Buboid: coffin rising, melting and resurrection.
//! Reference behaviour: BUBOID.CPP (docs/class-porting.md).
const std = @import("std");
const catalog = @import("actor_catalog");
const data = @import("../../../../game/domain/components.zig");
const abi = @import("../../../../engine/abi.zig");
const v = @import("../../../../core/domain/vector.zig");
const Definition = @import("../../../../mechanics/domain/actors.zig").Definition;
const Playback = @import("../../../../core/domain/animation.zig").Playback;
const context = @import("../../../../mechanics/server/actor_classes/frame.zig");
const common = @import("../../../../mechanics/server/actor_classes/common.zig");
const registry = @import("../../../../mechanics/server/actor_classes/registry.zig");
const ground = @import("../../../../mechanics/server/ground_combat.zig");
const Frame = context.Frame;
const Actors = context.Actors;
pub const policy = catalog.buboid;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{ .{ .slot = .death_b, .name = "dieb" }, .{ .slot = .ground_run, .name = "runa" } };
pub const routes: context.Routes = .{ .ground = true };
pub fn spawn(spawning: *context.Spawn) !void {
    try @import("buboids.zig").initialize(spawning.world, spawning.entity, spawning.now);
}
pub fn die(frame: *Frame) !void {
    frame.actor.death_pose = frame.definition.death_b;
}
/// A buboid killed for good bursts.
pub fn mustGib(actor: *const data.Actor) bool {
    return actor.buboid.phase == .terminal;
}
/// Rising from its coffin or resurrecting, it neither runs scripts nor follows paths.
pub fn scriptable(actor: *const data.Actor) bool {
    return actor.buboid.phase == .living or actor.buboid.phase == .coffin;
}
pub fn follows(actor: *const data.Actor) bool {
    return scriptable(actor);
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("buboids.zig").step(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.now, frame.elapsed, frame.slow);
}
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    if (actor.mode == .dead) return;
    const state = decoration.state;
    if (actor.buboid.phase == .melted) state.modelindex = 0;
    state.time2 = policy.melt_tag;
    state.time = @intCast(actor.buboid.started_ms);
    state.origin2 = .{ actor.buboid.alpha, if (actor.buboid.phase == .melting or actor.buboid.phase == .unmelting) @as(f32, 1) else 0, 0 };
}
pub fn admitDamage(actor: *const data.Actor, _: context.Damage) bool {
    return !actor.buboid.invulnerable();
}
pub fn immovable(actor: *const data.Actor) bool {
    return actor.buboid.invulnerable();
}
/// Its health drives the collapse and recovery cycle; collapsing, it turns on whoever hurt it.
pub fn afterDamage(hit: *context.Hit) !void {
    if (hit.result.blood <= 0) return;
    const actor = hit.actor;
    const now = hit.now;
    const previous = actor.buboid.phase;
    hit.result.killed = actor.buboid.damage(&hit.health.current, hit.options.source == try hit.world.persistentId(hit.entity) and hit.amount >= 32000, now);
    if (actor.buboid.phase != .collapsed or previous == .collapsed) return;
    actor.melee.begin(5, now);
    actor.reaction = null;
    actor.reaction_until_ms = null;
    actor.scripted_pose = null;
    actor.mode = .idle;
    actor.changed_ms = now;
    actor.think_ms = now;
    if (@import("../../../../mechanics/server/region_access.zig").find(hit.world, hit.options.source)) |source| if ((source.get(data.Player) catch null) != null or (source.get(data.Companion) catch null) != null) {
        actor.threat = hit.options.source;
        actor.ignore_player = false;
    };
}
