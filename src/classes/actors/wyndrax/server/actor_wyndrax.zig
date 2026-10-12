// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: wyndrax. Wyndrax: wisps, the power station and zaps.
//! Reference behaviour: wyndrax.cpp (docs/class-porting.md).
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
pub const policy = catalog.wyndrax;
pub const attacks: []const []const u8 = &policy.attacks;
pub const clips = [_]context.Clip{.{ .slot = .ground_run, .name = "runa" }};
pub const routes: context.Routes = .{ .ground = true };
/// His clips have no supplied event rows; they strike on their second frame and he plays his own zaps.
pub fn attackLoad(_: catalog.Kind, _: usize) context.AttackLoad {
    return .{ .events = .first_frame };
}
/// A charge bolt hangs from Wyndrax himself; the others from his zap or one of his wisps.
pub fn validateSavedAttack(saved: *const @import("../../../../mechanics/domain/snapshot.zig").Saved, attack: data.ActorAttack) !void {
    const bolt = switch (attack.attack) {
        .wyndrax_bolt => |bolt| bolt,
        else => return,
    };
    const parent = saved.find(bolt.parent) orelse return error.InvalidSavedActorAttack;
    if (bolt.kind == .charge) {
        try parent.require(.{data.Actor});
        if (bolt.parent != attack.owner) return error.InvalidSavedActorAttack;
    } else {
        const source = parent.get(data.ActorAttack) catch return error.InvalidSavedActorAttack;
        if (source.owner != attack.owner or (if (bolt.kind == .zap) source.attack != .wyndrax_zap else source.attack != .npc_wisp)) return error.InvalidSavedActorAttack;
    }
}
pub fn spawn(spawning: *context.Spawn) !void {
    (try spawning.actor()).wyndrax.start_position = try spawning.position();
}
/// Outside combat the boss runs its own phases, not paths.
pub fn follows(actor: *const data.Actor) bool {
    return actor.wyndrax.phase == .combat;
}
pub fn move(frame: *Frame) !void {
    if (frame.dead) return common.move(frame);
    try @import("wyndrax_actor.zig").step(frame.actors, frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.body, frame.velocity, frame.navigation, frame.now, frame.elapsed, frame.slow);
}
