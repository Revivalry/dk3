// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: rockgat. Rock turret: authored activation, rising, bursts; destroyed turrets vanish.
//! Reference behaviour: rockgat.cpp (docs/class-porting.md).
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
pub const policy = catalog.rockgat;
pub const vanish_on_death = true;
pub fn spawn(spawning: *context.Spawn) !void {
    (try spawning.actor()).rockgat = try @import("rockgats.zig").configure(spawning.object, spawning.now, spawning.definition.idle.last);
}
/// The turret runs its whole step itself and never moves.
pub fn preempt(frame: *Frame) !bool {
    try @import("rockgats.zig").step(frame.world, frame.slots, frame.projections, frame.entity, frame.actor, frame.pose, frame.now);
    common.hold(frame);
    return true;
}
/// The turret rises frame by frame to its authored height and lowers in reverse.
pub fn playback(view: context.View) !?Playback {
    const gun = view.actor.rockgat;
    return .{ .sequence = .{ .last = if (gun.height == 0) 0 else if (gun.raised) gun.height else gun.height - 1, .fps = 1000 / policy.frame_period_ms }, .started = gun.pose_ms, .looping = false, .reverse = !gun.raised };
}
pub fn decorate(decoration: *context.Decoration) !void {
    for (decoration.view.actor.rockgat.bursts) |burst| if (burst != null) {
        decoration.state.time2 = policy.flash_tag;
        return;
    };
}
pub fn diagnose(view: context.View, writer: *std.Io.Writer) !void {
    const gun = view.actor.rockgat;
    var pending: usize = 0;
    for (gun.bursts) |burst| if (burst != null) {
        pending += 1;
    };
    try writer.print(" gun={s} gun_shots={d} gun_pending={d} gun_frame={d}", .{ @tagName(gun.phase), gun.shots, pending, gun.frame(view.now) });
}
/// Its pain callback deducts extra damage.
pub fn afterDamage(hit: *context.Hit) !void {
    if (hit.result.blood <= 0) return;
    const extra = policy.painDamage(hit.amount);
    hit.health.current -= extra;
    hit.result.blood += extra;
    hit.result.killed = hit.health.current <= 0;
}
/// Triggered, a living turret pops up.
pub fn use(using: *context.Use) !bool {
    if ((try using.world.get(using.entity, data.Health)).current > 0) {
        using.actor.rockgat.use();
        using.actor.think_ms = using.now + 100;
    }
    return true;
}
