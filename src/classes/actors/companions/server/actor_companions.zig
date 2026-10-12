// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Sidekicks: party spawning, orders, the shared bot pilot, pain voices and weapon-driven poses.
//! Reference behaviour: Sidekick.cpp (docs/class-porting.md).
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
pub const policy = catalog.companions;
pub const preload = true;
pub const varied_idle = false;
pub const upright = true;
pub const audio_follows_playback = true;
/// Its weapons' sounds come from its attack frames.
pub const frame_attack_audio = true;
pub const clips = [_]context.Clip{.{ .slot = .walk, .name = "walka", .fallback = .run }};
pub const helpers = [_][]const u8{"pose"};
const companion_pose = @import("../domain/companion_pose.zig");
/// Each companion class's weapon pose sets, and the reference teleport nodes already used.
pub const Store = struct {
    poses: [catalog.entries.len]?companion_pose.Set = @splat(null),
    nodes: @import("sidekick_nodes.zig").State = .{},
};
pub fn enterMap(store: *Store, _: *Actors) !void {
    // A map entered or a save of it restored: its teleport nodes are unused.
    store.nodes = .{};
}
pub fn tick(store: *Store, _: *Actors, world: *data.World, slots: *@import("../../../../engine/slots.zig").Slots) !void {
    if (@import("../../../../engine/server.zig").integer("g_gametype") == abi.c.GT_SINGLE_PLAYER) try @import("sidekick_nodes.zig").step(&store.nodes, world, slots);
}
pub fn loadAnimations(load: context.Load) !void {
    registry.store(@This(), &load.actors.stores).poses[load.id] = try companion_pose.Set.read(load.metadata, std.mem.eql(u8, load.classname, "mikikofly"));
    load.definition.attacks[0] = try load.find("ataka") orelse load.definition.idle;
}
pub fn spawn(spawning: *context.Spawn) !void {
    try @import("companions.zig").initialize(spawning.world, spawning.entity, spawning.actors.episode, &spawning.actors.weapons, spawning.definition.health, spawning.now);
}
pub fn die(frame: *Frame) !void {
    try @import("companion_damage.zig").death(frame.world, frame.slots, frame.projections, frame.entity, frame.actors.episode, frame.now);
}
pub fn sense(frame: *Frame) !void {
    try @import("companion_damage.zig").react(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.now);
}
/// In pain, a companion neither runs scripts nor follows paths.
pub fn scriptable(actor: *const data.Actor) bool {
    return actor.reaction == null;
}
pub fn follows(actor: *const data.Actor) bool {
    return actor.reaction == null;
}
pub const perceive = common.perceiveNothing;
pub fn pathMove(frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    if (point) |destination| frame.actor.threat_position = destination;
    try @import("companion_navigation.zig").move(frame.world, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.definition.*, speed, frame.actor.threat_position, frame.slot, frame.now, frame.elapsed);
}
pub fn think(frame: *Frame) !void {
    const previous = frame.actor.mode;
    try @import("companion_brain.zig").think(frame.actors, frame.navigation, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.definition.*, frame.now);
    try @import("companion_navigation.zig").prepare(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose.*, frame.body.*, frame.now);
    if (frame.actor.mode != previous) frame.actor.changed_ms = frame.now;
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("companion_pilot.zig").drive(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.definition.*, frame.definition.speed * frame.slow, frame.now, frame.elapsed);
}
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    decoration.state.time2 = policy.render_tag;
    const companion = (try decoration.view.world.get(decoration.view.entity, data.Companion)).*;
    const loadout = (try decoration.view.world.get(decoration.view.entity, data.Weapons)).*;
    decoration.state.weapon = if (companion.carrying or actor.mode == .dead) 0 else loadout.weapon;
}
/// Free of pain and scripts, a companion shows the pose its weapon, gait, jump and fire choose.
pub fn playback(view: context.View) !?Playback {
    const actor = view.actor;
    if (actor.mode == .dead or actor.reaction != null or actor.scripted_pose != null) return null;
    return try pose(view.actors, view.world, view.entity, view.now);
}
/// The pose a companion's weapon, gait, jump and fire choose.
pub fn pose(actors: *const Actors, world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, now: i64) !Playback {
    const actor = try world.get(entity, data.Actor);
    const poses = registry.store(@This(), &actors.stores).poses[actor.definition] orelse return error.MissingCompanionPoses;
    const companion = try world.get(entity, data.Companion);
    const loadout = try world.get(entity, data.Weapons);
    const body = try world.get(entity, data.Body);
    const velocity = (try world.get(entity, data.Velocity)).linear;
    const definition = actors.table.definitions[actor.definition];
    const speed = @sqrt(velocity[0] * velocity[0] + velocity[1] * velocity[1]);
    const motion = if (@import("companion_pilot.zig").find(try world.persistentId(entity))) |flown| flown.gait.update(speed, definition.walk_speed, definition.speed, now) else companion_pose.gait(speed, definition.walk_speed, definition.speed);
    return poses.select(loadout.weapon, motion, !body.grounded and @abs(velocity[2]) > 1 and companion.motor.water_level < 2, companion.motor.ducked, companion.motor.water_level > 1, companion.jump_started_ms, loadout.last_fire_ms, actor.changed_ms, now);
}
/// In pain, its script waits.
pub fn pausesScript(actor: *const data.Actor) bool {
    return actor.reaction != null;
}
