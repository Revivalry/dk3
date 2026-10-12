// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: civilians. Fear decisions use the existing actor navigation and audio services.
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const catalog = @import("actor_catalog");
const policy = catalog.civilians.workers;
const v = @import("../../../../core/domain/vector.zig");
/// After a cower period: a worker whose enemy is far away (or a fat worker, who only wandered)
/// calms down; one whose enemy is close and in sight runs again. Plays the hide voice.
pub fn think(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, definition: @import("../../../../mechanics/domain/actors.zig").Definition, role: catalog.civilians.Role, mobile: bool, now: i64) !void {
    const thin = role.thin_voice;
    if (actor.worker.phase == .cower and now >= actor.worker.retry_ms) {
        const enemy = @import("../../../../mechanics/server/region_access.zig").find(world, actor.threat);
        if (enemy) |target| {
            const point = (try target.get(data.Transform)).position;
            const distance = v.length(v.subtract(pose.position, point));
            if (distance > definition.sight_range or !role.cower_clips) {
                actor.worker.phase = .calm;
                actor.threat = 0;
            } else if (distance < policy.retry_distance) {
                if (try @import("../../../../mechanics/server/actors.zig").Actors.visible(v.add(pose.position, .{ 0, 0, 16 }), point, (try world.get(entity, data.Binding)).slot, (try target.get(data.Binding)).slot)) @import("civilians.zig").panic(actor, actor.threat, point, mobile, now);
            }
        } else {
            actor.worker.phase = .calm;
            actor.threat = 0;
        }
    }
    if (actor.worker.voice_pending) {
        actor.worker.voice_pending = false;
        const random = try world.get(entity, data.Random);
        actor.worker.variant = if (random.next() < 0.5) 0 else 1;
        const chance = random.next();
        const choice = random.next();
        if (catalog.hide_voice.choose(thin, chance, choice)) |name| {
            try @import("../../../../mechanics/server/actor_audio.zig").play(world, slots, projections, entity, definition, name, now);
            if (@import("../../../../engine/server.zig").integer("developer") != 0) {
                var message: [160]u8 = undefined;
                @import("../../../../engine/server.zig").print(try @import("std").fmt.bufPrintZ(&message, "dk3 worker: fear voice id={d} sound={s}\n", .{ try world.persistentId(entity), name }));
            }
        }
    }
}
