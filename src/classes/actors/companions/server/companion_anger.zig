// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Party-wide retaliation uses ordinary weapon attacks with a mercy floor.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const access = @import("../../../../mechanics/server/region_access.zig");
const Ref = @import("../../../../mechanics/domain/world_references.zig").Ref;
const engine = @import("../../../../engine/server.zig");
const v = @import("../../../../core/domain/vector.zig");
const pilot = @import("../../../../mechanics/server/bot_pilot.zig");
const damage = @import("../../../../mechanics/domain/damage.zig");

fn changeLocal(world: *data.World, owner: u32, begin: bool) !void {
    var query = world.queryAccess(data.World.mask(.{ data.Companion, data.Health }), 0, data.World.mask(.{data.Companion}));
    defer query.deinit();
    while (query.next()) |view| for (view.write(data.Companion), view.read(data.Health)) |*member, health| {
        if (member.owner != owner or health.current <= 0) continue;
        if (begin) {
            member.anger.begin();
            member.stopped = false;
            member.collecting = 0;
            member.collect_forced = false;
        } else member.anger.forgive();
    };
}
fn changeParty(world: *data.World, owner: u32, begin: bool) !void {
    try changeLocal(world, owner, begin);
    if (access.contextFor(world) == null) return;
    if (access.region) |region| {
        if (region.initial.world) |*initial| if (initial != world) try changeLocal(initial, owner, begin);
        for (region.residents.entries) |maybe| if (maybe) |entry| if (entry.ready) if (entry.context) |context| {
            if (context.world) |*other| if (other != world) try changeLocal(other, owner, begin);
        };
    }
}
/// The damage registry calls this before armor/health accounting, including
/// armor-only contacts. No new entity is created while damage holds pointers.
pub fn prepareDamage(world: *data.World, entity: ecs.Entity, amount: i32, now: i64, options: *damage.Options) !void {
    if (amount <= 0 or options.source == 0) return;
    const source = access.find(world, options.source) orelse return;
    if (world.get(entity, data.Companion) catch null) |member| {
        const owner = member.owner;
        if (owner != options.source or (source.get(data.Player) catch null) == null) return;
        if ((world.get(entity, data.Health) catch return).current <= 0) return;
        if (member.anger.hit(now)) try changeParty(world, owner, true);
    }
    if ((world.get(entity, data.Player) catch null) != null) if (source.get(data.Companion) catch null) |member| {
        if (member.owner == try world.persistentId(entity)) {
            if (member.anger.retaliating) options.minimum_health = @max(options.minimum_health, 5) else options.cancelled = true;
        }
    };
}
/// An empty-handed party member can still physically strike its aggressor.
/// No ammunition is granted; a solid lane and actual reach are required.
pub fn unarmed(world: *data.World, entity: ecs.Entity, table: *const @import("../../../../mechanics/domain/weapons.zig").Table, episode: u8, now: i64) !void {
    const member = try world.get(entity, data.Companion);
    if (!member.anger.retaliating or member.carrying or (member.anger.strike_ms orelse 0) > now) return;
    const owner = access.find(world, member.owner) orelse return;
    if ((try owner.get(data.Health)).current <= 5 or (try owner.get(data.Player)).mode != .normal) return;
    if (@import("../../../../mechanics/server/cinematics.zig").active(world)) return;
    if (try @import("companion_weapons.zig").choose(world, entity, owner, table, episode) != 0) return;
    const from = v.add((try world.get(entity, data.Transform)).position, .{ 0, 0, 12 });
    const to = v.add((try owner.get(data.Transform)).position, .{ 0, 0, 12 });
    if (v.length(v.subtract(to, from)) > 64) return;
    const collision = @import("../../../../mechanics/server/region_collision.zig");
    const hit = try collision.trace(.{ .start = from, .end = to, .mins = @splat(0), .maxs = @splat(0), .slot = (try world.get(entity, data.Binding)).slot, .mask = @import("../../../../engine/abi.zig").c.MASK_SHOT });
    if (!collision.reaches(world, hit, owner)) return;
    member.anger.strike_ms = now + 700;
    (try world.get(entity, data.Weapons)).last_fire_ms = now;
    const source = try world.persistentId(entity);
    _ = try @import("../../../../mechanics/server/damage.zig").apply(owner.world, owner.entity, 10, now, .{ .source = source });
}
pub fn plan(world: *data.World, entity: ecs.Entity, actor: *data.Actor, pose: data.Transform, owner: Ref, intent: *pilot.Intent, now: i64) !bool {
    const owner_health = (try owner.get(data.Health)).current;
    const member = try world.get(entity, data.Companion);
    member.anger.cool(now);
    if (!member.anger.retaliating) return false;
    if (owner_health <= 5) {
        const owner_id = member.owner;
        try changeParty(world, owner_id, false);
        actor.threat = 0;
        actor.mode = .idle;
        // Preserve the exact requested rebuke as dialogue; no anger value is
        // exposed in the HUD or in this message.
        const binding = (try owner.get(data.Binding)).slot;
        engine.send(@intCast(binding), "cp \"You got what's you deserved. Never do that again\"");
        return true;
    }
    const state = (try owner.get(data.Player)).*;
    if (state.mode != .normal or @import("../../../../mechanics/server/cinematics.zig").active(world)) return true;
    const target = (try owner.get(data.Transform)).position;
    actor.threat = member.owner;
    actor.threat_position = target;
    actor.threat_seen_ms = now;
    actor.mode = .attack;
    intent.* = .{ .destination = target, .preferred = member.owner, .look_at = target, .fight = true, .close_in = true };
    _ = pose;
    return true;
}

test "one provoked member recruits its party and delayed owner hits retain mercy" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 8);
    defer world.deinit();
    const player = try world.create(1, .{ data.Player{}, data.Health{} });
    const first = try world.create(2, .{ data.Companion{ .identity = .mikiko, .owner = 1 }, data.Health{} });
    const second = try world.create(3, .{ data.Companion{ .identity = .superfly, .owner = 1 }, data.Health{} });
    for (0..20) |hit| {
        var options: damage.Options = .{ .source = 1 };
        try prepareDamage(&world, first, 1, @intCast(hit * 100), &options);
    }
    try t.expect((try world.get(first, data.Companion)).anger.retaliating);
    try t.expect((try world.get(second, data.Companion)).anger.retaliating);
    var options: damage.Options = .{ .source = 3 };
    try prepareDamage(&world, player, 100, 3000, &options);
    try t.expectEqual(@as(i32, 5), options.minimum_health);
    const result = damage.apply(try world.get(player, data.Health), null, 1000, 3000, options);
    try t.expect(!result.killed);
    try t.expectEqual(@as(i32, 5), (try world.get(player, data.Health)).current);
    try changeParty(&world, 1, false);
    options = .{ .source = 3 };
    try prepareDamage(&world, player, 100, 3050, &options);
    try t.expect(options.cancelled);
    const delayed = damage.apply(try world.get(player, data.Health), null, 1000, 3050, options);
    try t.expectEqual(@as(i32, 0), delayed.blood);
    try t.expectEqual(@as(i32, 5), (try world.get(player, data.Health)).current);
}

test "ordinary owned party shots cannot injure the owner or consume armour" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    const player = try world.create(1, .{ data.Player{}, data.Health{ .armor = 100 } });
    _ = try world.create(2, .{ data.Companion{ .identity = .mikiko, .owner = 1 }, data.Health{} });
    var options: damage.Options = .{ .source = 2 };
    try prepareDamage(&world, player, 1000, 100, &options);
    const result = damage.apply(try world.get(player, data.Health), null, 1000, 100, options);
    try std.testing.expect(options.cancelled and !result.killed);
    try std.testing.expectEqual(@as(i32, 100), (try world.get(player, data.Health)).current);
    try std.testing.expectEqual(@as(i32, 100), (try world.get(player, data.Health)).armor);
}
