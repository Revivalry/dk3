// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: nharre. Nharre: summoning, the reaper, retreat and fading.
//! Reference behaviour: nharre.cpp (docs/class-porting.md).
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
pub const policy = catalog.nharre;
pub const attacks: []const []const u8 = &policy.attacks;
pub const requires = [_][]const u8{ "monster_buboid", "monster_doombat", "monster_plague_rat" };
pub const routes: context.Routes = .{ .ground = true };
/// Until it lets go, the reaper owns its victim's motion and holds a player frozen.
pub fn validateSavedAttack(saved: *const @import("../../../../mechanics/domain/snapshot.zig").Saved, attack: data.ActorAttack) !void {
    const reaper = switch (attack.attack) {
        .nharre_reaper => |reaper| reaper,
        else => return,
    };
    if (reaper.released) return;
    const target = saved.find(reaper.target) orelse return error.InvalidSavedActorAttack;
    try target.require(.{ data.Body, data.Velocity, data.Health, data.Transform, data.Binding });
    if ((target.get(data.Actor) catch null) == null and (target.get(data.Player) catch null) == null) return error.InvalidSavedActorAttack;
    if ((try target.get(data.Body)).motion_owner != try saved.world.persistentId(saved.entity)) return error.InvalidSavedActorAttack;
    if (target.get(data.Player) catch null) |victim| if (victim.mode != .frozen and victim.mode != .dead) return error.InvalidSavedActorAttack;
}
pub fn spawn(spawning: *context.Spawn) !void {
    @import("nharres.zig").initialize(spawning.world, spawning.slots, spawning.now);
}
/// Outside combat the boss runs its own phases, not paths.
pub fn follows(actor: *const data.Actor) bool {
    return actor.nharre.phase == .combat;
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("nharres.zig").step(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.now, frame.elapsed, frame.slow);
}
pub fn decorate(decoration: *context.Decoration) !void {
    const actor = decoration.view.actor;
    if (actor.mode == .dead) return;
    decoration.state.time2 = catalog.fade.fade_tag;
    decoration.state.origin2[0] = actor.nharre.alpha;
}
pub fn admitDamage(actor: *const data.Actor, _: context.Damage) bool {
    return !actor.nharre.invulnerable();
}
pub fn immovable(actor: *const data.Actor) bool {
    return actor.nharre.invulnerable();
}

test "a saved reaper must still own its unreleased victim's motion" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 4);
    defer world.deinit();
    const victim = try world.create(1, .{ data.Transform{}, data.Velocity{}, data.Player{ .mode = .frozen }, data.Body{ .motion_owner = 3 }, data.Binding{ .slot = 0 }, data.Health{} });
    const entity = try world.create(3, .{data.Transform{}});
    const attack: data.ActorAttack = .{ .owner = 2, .born_ms = 500, .stepped_ms = 1200, .attack = .{ .nharre_reaper = .{ .target = 1, .next_ms = 1300 } } };
    var entries = [_]*data.World{&world};
    const header: @import("../../../../mechanics/domain/snapshot.zig").Header = undefined;
    const saved: @import("../../../../mechanics/domain/snapshot.zig").Saved = .{ .world = &world, .entity = entity, .references = .{ .entries = &entries }, .header = &header };
    try validateSavedAttack(&saved, attack);
    (try world.get(victim, data.Body)).motion_owner = null;
    try t.expectError(error.InvalidSavedActorAttack, validateSavedAttack(&saved, attack));
    (try world.get(victim, data.Body)).motion_owner = 3;
    (try world.get(victim, data.Player)).mode = .normal;
    try t.expectError(error.InvalidSavedActorAttack, validateSavedAttack(&saved, attack));
}
