// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Shared generic pain contract. Classes supply their chance and heavy-hit limit.
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const Definition = @import("../domain/actors.zig").Definition;
/// The reference's generic pain handler: two rolls of the class `chance`. The first plays the pain
/// clip; the second plays it for a hit of `limit` or more and otherwise only stalls the actor.
/// The hit that makes a player the actor's enemy (`previous_threat` is the enemy before this
/// step's perception) skips the first roll: it starts the fight instead.
pub fn generic(world: *data.World, entity: ecs.Entity, actor: *data.Actor, definition: Definition, hurt: data.Hurt, previous_threat: u32, chance: u8, limit: i32, now: i64) !bool {
    const amount = hurt.amount;
    if (amount <= 0 or now <= actor.pain_ready_ms) return false;
    const random = try world.get(entity, data.Random);
    const first = @as(u8, @intFromFloat(random.next() * 99.9)) < chance and !acquiring(world, hurt, previous_threat);
    const second = @as(u8, @intFromFloat(random.next() * 99.9)) < chance;
    if (first or (second and amount >= limit)) {
        return hit(actor, definition, now);
    }
    if (!second) return false;
    const sequence = if (actor.melee.active) definition.attacks[actor.melee.pose] else if (actor.mode == .chase) definition.run else definition.idle;
    actor.pain_ready_ms = now + @divTrunc(@as(i64, sequence.last - sequence.first) * 1000, sequence.fps);
    // Below the limit the wrapper leaves the sequence unchanged. The pain task
    // yields at its next tick because this is not a hit animation.
    actor.reaction_until_ms = now + 100;
    actor.mode = .idle;
    return true;
}
/// A player's hit on an actor whose enemy was someone else: it makes him the enemy.
pub fn acquiring(world: *data.World, hurt: data.Hurt, previous_threat: u32) bool {
    if (hurt.source == previous_threat) return false;
    const source = @import("region_access.zig").find(world, hurt.source) orelse return false;
    return (source.get(data.Player) catch null) != null;
}
/// While a pain reaction plays, the actor idles and its class step yields: true until the reaction
/// ends, at which point the reaction is cleared.
pub fn reacting(actor: *data.Actor, now: i64) bool {
    const until = actor.reaction_until_ms orelse return false;
    if (now < until) {
        actor.mode = .idle;
        return true;
    }
    actor.reaction = null;
    actor.reaction_until_ms = null;
    return false;
}
/// The unwrapped pain callback has one chance roll and no heavy-hit fallback.
pub fn direct(world: *data.World, entity: ecs.Entity, actor: *data.Actor, definition: Definition, amount: i32, chance: u8, now: i64) !bool {
    if (amount <= 0 or now <= actor.pain_ready_ms) return false;
    if (@as(u8, @intFromFloat((try world.get(entity, data.Random)).next() * 99.9)) >= chance) return false;
    return hit(actor, definition, now);
}
fn hit(actor: *data.Actor, definition: Definition, now: i64) bool {
    const sequence = definition.pain[0] orelse return false;
    actor.reaction = sequence;
    actor.reaction_started_ms = now;
    actor.reaction_until_ms = now + sequence.lastFrameMs();
    actor.pain_ready_ms = now + @divTrunc(@as(i64, sequence.last - sequence.first) * 1000, sequence.fps);
    actor.melee.active = false;
    actor.mode = .idle;
    return true;
}

test "light damage can trigger the first pain roll before the heavy-hit limit" {
    const t = @import("std").testing;
    var world = data.World.init(t.allocator, 1);
    defer world.deinit();
    const entity = try world.create(1, .{data.Random{ .state = 0 }});
    var actor: data.Actor = .{ .definition = 0, .mode = .attack };
    actor.melee.begin(0, 100);
    var definition: Definition = .{};
    definition.pain[0] = .{ .first = 40, .last = 49, .fps = 10 };
    try t.expect(try generic(&world, entity, &actor, definition, .{ .amount = 1 }, 0, 25, 35, 1000));
    try t.expectEqual(@as(u16, 40), actor.reaction.?.first);
    try t.expect(!actor.melee.active);
    try t.expectEqual(@as(i64, 1900), actor.pain_ready_ms);
    // The lock suppresses both random draws, including on its final millisecond.
    const seed = (try world.get(entity, data.Random)).state;
    try t.expect(!try generic(&world, entity, &actor, definition, .{ .amount = 100 }, 0, 100, 35, 1900));
    try t.expectEqual(seed, (try world.get(entity, data.Random)).state);
}
test "the second light-hit roll retains the active attack and locks for that sequence" {
    const t = @import("std").testing;
    var world = data.World.init(t.allocator, 1);
    defer world.deinit();
    const entity = try world.create(1, .{data.Random{ .state = 8 }});
    var actor: data.Actor = .{ .definition = 0, .mode = .attack };
    actor.melee.begin(0, 100);
    actor.melee.struck = 1;
    var definition: Definition = .{};
    definition.attacks[0] = .{ .first = 20, .last = 39, .fps = 10 };
    definition.pain[0] = .{ .first = 40, .last = 49, .fps = 10 };
    try t.expect(try generic(&world, entity, &actor, definition, .{ .amount = 1 }, 0, 20, 35, 1000));
    try t.expectEqual(null, actor.reaction);
    try t.expect(actor.melee.active);
    try t.expectEqual(@as(u2, 1), actor.melee.struck);
    try t.expectEqual(@as(i64, 2900), actor.pain_ready_ms);
    try t.expectEqual(@as(?i64, 1100), actor.reaction_until_ms);
}

test "direct pain does not inherit the generic wrapper's second-roll admission" {
    const t = @import("std").testing;
    var world = data.World.init(t.allocator, 1);
    defer world.deinit();
    const entity = try world.create(1, .{data.Random{ .state = 8 }});
    var actor: data.Actor = .{ .definition = 0 };
    var definition: Definition = .{};
    definition.pain[0] = .{ .first = 40, .last = 49, .fps = 10 };
    try t.expect(!try direct(&world, entity, &actor, definition, 1, 20, 1000));
    try t.expectEqual(null, actor.reaction_until_ms);
}
test "a player's hit on an actor fighting someone else acquires him and skips the first roll" {
    const t = @import("std").testing;
    var world = data.World.init(t.allocator, 4);
    defer world.deinit();
    const entity = try world.create(1, .{data.Random{ .state = 0 }});
    _ = try world.create(2, .{data.Player{}});
    _ = try world.create(3, .{data.Random{ .state = 1 }});
    try t.expect(acquiring(&world, .{ .source = 2 }, 0));
    try t.expect(!acquiring(&world, .{ .source = 2 }, 2));
    try t.expect(!acquiring(&world, .{ .source = 3 }, 0));
    var actor: data.Actor = .{ .definition = 0, .mode = .attack };
    var definition: Definition = .{};
    definition.pain[0] = .{ .first = 40, .last = 49, .fps = 10 };
    // A certain first roll plays nothing on the acquiring hit; only the light-hit stall remains.
    try t.expect(try generic(&world, entity, &actor, definition, .{ .source = 2, .amount = 1 }, 0, 100, 35, 1000));
    try t.expectEqual(null, actor.reaction);
    try t.expectEqual(@as(?i64, 1100), actor.reaction_until_ms);
}
