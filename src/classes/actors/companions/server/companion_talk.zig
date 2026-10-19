// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Authored sidekick lines: a sidekick that reaches one of its talk nodes
//! while its owner is near and in sight says the node's line, once a level.
//! Reference behaviour: Sidekick.cpp talk nodes and its say-something task (docs/class-porting.md).
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const v = @import("../../../../core/domain/vector.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const Ref = @import("../../../../mechanics/domain/world_references.zig").Ref;
const nodes = @import("../../../../mechanics/server/authored_nodes.zig");
const policy = @import("actor_catalog").companions;

/// How near the node counts as reaching it (sidekicks route by area, not through the nodes).
const reach: f32 = 128;
const rise: f32 = 64;
/// The owner must be this near, and in sight.
const hearing: f32 = 800;

/// The line's volume by the owner's distance: full within 512, fading to a tenth at 1500.
pub fn volume(distance: f32) f32 {
    if (distance <= 512) return 1;
    return std.math.clamp((1500 - distance) / 1000, 0.1, 1);
}
/// Superfly waits a second after speaking, Mikiko five.
pub fn pause(identity: policy.Identity) i64 {
    return if (identity == .mikiko) 5000 else 1000;
}

pub fn speak(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, companion: *data.Companion, position: v.Vec3, owner: Ref, now: i64) !void {
    if (now < companion.talk_ready_ms) return;
    const flag = if (companion.identity == .mikiko) nodes.mikiko_talk_flag else nodes.superfly_talk_flag;
    const leader = (try owner.get(data.Transform)).position;
    const distance = v.length(v.subtract(leader, position));
    if (distance >= hearing) return;
    for (nodes.talkNodes()) |*talk| {
        if (talk.said or talk.flags & flag == 0) continue;
        if (@import("../../../../core/domain/navigation.zig").horizontalDistance(position, talk.position) > reach or @abs(position[2] - talk.position[2]) > rise) continue;
        const sight = try @import("../../../../mechanics/server/region_collision.zig").trace(.{ .start = v.add(position, .{ 0, 0, 22 }), .end = v.add(leader, .{ 0, 0, 22 }), .mins = @splat(0), .maxs = @splat(0), .slot = (try world.get(entity, data.Binding)).slot, .mask = abi.c.MASK_OPAQUE });
        if (sight.fraction < 1 and !@import("../../../../mechanics/server/region_collision.zig").reaches(world, sight, owner)) return;
        talk.said = true;
        companion.talk_ready_ms = now + pause(companion.identity);
        if (@import("../../../../engine/server.zig").integer("developer") >= 1) {
            var text: [160]u8 = undefined;
            @import("../../../../engine/server.zig").print(std.fmt.bufPrintZ(&text, "dk3 companion talk: {s} says {s}\n", .{ @tagName(companion.identity), talk.sound() }) catch "dk3 companion talk\n");
        }
        try @import("../../../../mechanics/server/events.zig").configuredSound(world, slots, projections, talk.sound(), position, (try world.get(entity, data.Binding)).slot, abi.c.CHAN_VOICE, now, .{ .volume = volume(distance), .nondirectional = true });
        return;
    }
}

/// The line of a stop node this sidekick was first to heed (SIDEKICK_DoStopGoingFurther, order 1).
pub fn stopLine(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, identity: policy.Identity, position: v.Vec3, now: i64) !void {
    for (nodes.stopNodes()) |*stop| {
        if (stop.speaker != @intFromEnum(identity)) continue;
        stop.speaker = null;
        try @import("../../../../mechanics/server/events.zig").configuredSound(world, slots, projections, stop.sound(), position, (try world.get(entity, data.Binding)).slot, abi.c.CHAN_VOICE, now, .{ .nondirectional = true });
    }
}

test "a talk line is full within 512 and fades to a tenth by 1500" {
    const t = std.testing;
    try t.expectEqual(@as(f32, 1), volume(400));
    try t.expectApproxEqAbs(@as(f32, 0.5), volume(1000), 0.001);
    try t.expectEqual(@as(f32, 0.1), volume(2000));
    try t.expect(pause(.mikiko) > pause(.superfly));
}
