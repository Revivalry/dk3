// SPDX-License-Identifier: GPL-2.0-or-later
//! item-class: keys. Pickup flags, one-use inventory, and durable keyed control unlocking.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const catalog = @import("item_catalog");
const policy = catalog.key_policy;
const access = @import("../../../../mechanics/server/region_access.zig");
const prop = @import("../../../../mechanics/server/properties.zig");

pub fn spawned(world: *data.World, item: ecs.Entity) !void {
    const object = (try world.get(item, data.MapObject)).*;
    const bounds = policy.pickupBounds(object.classname) orelse return;
    const body = try world.get(item, data.Body);
    body.mins = bounds.mins;
    body.maxs = bounds.maxs;
}
pub fn collected(world: *data.World, item: ecs.Entity, receiver: ecs.Entity) !void {
    const object = (try world.get(item, data.MapObject)).*;
    const index = catalog.keyIndex(object.classname) orelse return;
    (try world.get(receiver, data.Keys)).noteFlags(index, object.flags);
}
pub fn allows(world: *data.World, object: data.MapObject, activator: u32) bool {
    const name = prop.text(object, "keyname") orelse return true;
    if (name.len == 0 or (object.key_unlocked orelse (object.objective_uses > 0))) return true;
    const player = access.find(world, activator) orelse return false;
    const keys = player.get(data.Keys) catch return false;
    return keys.has(name);
}
pub fn fired(world: *data.World, entity: ecs.Entity, activator: u32) !void {
    const object = (try world.get(entity, data.MapObject)).*;
    const name = prop.text(object, "keyname") orelse return;
    if (name.len == 0 or (object.key_unlocked orelse (object.objective_uses > 0))) return;
    (try world.get(entity, data.MapObject)).key_unlocked = false;
    const player = access.find(world, activator) orelse return;
    const keys = player.get(data.Keys) catch return;
    const effect = keys.lockEffect(name) orelse return;
    if (!effect.consume and !effect.unlock_targets) return;
    if (effect.consume) {
        // Key-item REMOVEALL semantics apply to cooperative players, not the
        // companions' unrelated inventories. The activator can own a seam.
        consumePlayers(player.world, name);
        if (player.world != world) consumePlayers(world, name);
    }
    try markUnlocked(world, entity, false);
    if (effect.unlock_targets and object.target.len != 0) {
        const home = try access.authored(world, entity);
        const lookup = if (home) |context| &context.world.? else world;
        var targets: [ecs.max_entities]ecs.Entity = undefined;
        var count: usize = 0;
        {
            var query = lookup.queryAccess(data.World.mask(.{data.MapObject}), 0, 0);
            defer query.deinit();
            while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |target, description| {
                if (!std.mem.eql(u8, description.targetname, object.target)) continue;
                targets[count] = target;
                count += 1;
            };
        }
        for (targets[0..count]) |target| try markUnlocked(lookup, target, true);
    }
}
fn markUnlocked(world: *data.World, entity: ecs.Entity, manual: bool) !void {
    const object = try world.get(entity, data.MapObject);
    object.key_unlocked = true;
    object.manually_unlocked = object.manually_unlocked or manual;
    if (manual) object.targetname = "";
    const mover = world.get(entity, data.Mover) catch return;
    if (mover.group == 0) return;
    const group = mover.group;
    var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Mover }), 0, data.World.mask(.{data.MapObject}));
    defer query.deinit();
    while (query.next()) |view| for (view.write(data.MapObject), view.read(data.Mover)) |*description, motion| {
        if (motion.group != group) continue;
        description.key_unlocked = true;
        description.manually_unlocked = description.manually_unlocked or manual;
        if (manual) description.targetname = "";
    };
}
fn consumePlayers(world: *data.World, name: []const u8) void {
    var query = world.queryAccess(data.World.mask(.{ data.Player, data.Keys }), 0, data.World.mask(.{data.Keys}));
    defer query.deinit();
    while (query.next()) |view| for (view.write(data.Keys)) |*keys| keys.consume(name);
}
pub fn restoreAdmit(world: *data.World) !void {
    {
        var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Pickup, data.Body }), 0, data.World.mask(.{data.Body}));
        defer query.deinit();
        while (query.next()) |view| for (view.read(data.MapObject), view.write(data.Body)) |object, *body| {
            const bounds = policy.pickupBounds(object.classname) orelse continue;
            body.mins = bounds.mins;
            body.maxs = bounds.maxs;
        };
    }
    // Preserve successful controls from saves predating explicit unlock state.
    // Do not retroactively delete an inventory whose acquisition order is lost.
    {
        var query = world.queryAccess(data.World.mask(.{data.MapObject}), 0, data.World.mask(.{data.MapObject}));
        defer query.deinit();
        while (query.next()) |view| for (view.write(data.MapObject)) |*object| {
            const name = prop.text(object.*, "keyname") orelse continue;
            if (name.len != 0 and object.key_unlocked == null) object.key_unlocked = object.objective_uses > 0;
        };
    }
    var owners = world.queryAccess(data.World.mask(.{data.Keys}), 0, data.World.mask(.{data.Keys}));
    defer owners.deinit();
    while (owners.next()) |view| for (view.write(data.Keys)) |*keys| {
        keys.history |= keys.mask;
        if (keys.quest & 1 != 0) keys.history |= 0x0003c000;
        var items = world.queryAccess(data.World.mask(.{ data.MapObject, data.Pickup }), 0, 0);
        defer items.deinit();
        while (items.next()) |items_view| for (items_view.read(data.MapObject)) |object| {
            const index = catalog.keyIndex(object.classname) orelse continue;
            const bit = @as(u32, 1) << index;
            if (keys.mask & bit != 0 and keys.known_flags & bit == 0) keys.noteFlags(index, object.flags);
        };
    };
}
test "one-use key unlocks persist and remove the cooperative copies once" {
    var world = data.World.init(std.testing.allocator, 8);
    defer world.deinit();
    const green = catalog.keyIndex("item_control_card_green").?;
    var initial: policy.Keys = .{};
    _ = initial.collect(green);
    initial.noteFlags(green, 1);
    const player = try world.create(null, .{ data.Player{}, initial });
    const other = try world.create(null, .{ data.Player{}, initial });
    const control = try world.create(null, .{data.MapObject{ .classname = "switch", .properties = &.{.{ .key = "keyname", .value = "item_control_card_green" }} }});
    const owner = try world.persistentId(player);
    try std.testing.expect(allows(&world, (try world.get(control, data.MapObject)).*, owner));
    try fired(&world, control, owner);
    try std.testing.expect(!(try world.get(player, data.Keys)).has("item_control_card_green"));
    try std.testing.expect(!(try world.get(other, data.Keys)).has("item_control_card_green"));
    try std.testing.expectEqual(@as(?bool, true), (try world.get(control, data.MapObject)).key_unlocked);
    try std.testing.expect(allows(&world, (try world.get(control, data.MapObject)).*, try world.persistentId(other)));
    _ = (try world.get(player, data.Keys)).collect(green);
    try fired(&world, control, owner);
    try std.testing.expect((try world.get(player, data.Keys)).has("item_control_card_green"));
}
test "reusable keys retain their lock while unlock flags enable linked doors" {
    var world = data.World.init(std.testing.allocator, 8);
    defer world.deinit();
    const index = catalog.keyIndex("item_control_card_red").?;
    var initial: policy.Keys = .{};
    _ = initial.collect(index);
    initial.noteFlags(index, 0);
    const player = try world.create(null, .{ data.Player{}, initial });
    const control = try world.create(null, .{data.MapObject{ .classname = "switch", .target = "doors", .properties = &.{.{ .key = "keyname", .value = "item_control_card_red" }} }});
    const motion: data.Mover = .{ .group = 7, .closed = @splat(0), .opened = @splat(0), .motion = .{ .base = @splat(0), .end = @splat(0), .start_ms = 0, .duration_ms = 0 } };
    const door = try world.create(null, .{ data.MapObject{ .classname = "door", .targetname = "doors" }, motion });
    const other_leaf = try world.create(null, .{ data.MapObject{ .classname = "door" }, motion });
    const owner = try world.persistentId(player);
    try fired(&world, control, owner);
    try std.testing.expectEqual(@as(?bool, false), (try world.get(control, data.MapObject)).key_unlocked);
    try std.testing.expect((try world.get(player, data.Keys)).has("item_control_card_red"));
    (try world.get(player, data.Keys)).noteFlags(index, 2);
    try fired(&world, control, owner);
    try std.testing.expect((try world.get(player, data.Keys)).has("item_control_card_red"));
    try std.testing.expect((try world.get(door, data.MapObject)).manually_unlocked);
    try std.testing.expectEqualStrings("", (try world.get(door, data.MapObject)).targetname);
    try std.testing.expectEqual(@as(?bool, true), (try world.get(door, data.MapObject)).key_unlocked);
    try std.testing.expect((try world.get(other_leaf, data.MapObject)).manually_unlocked);
    try std.testing.expectEqual(@as(?bool, true), (try world.get(other_leaf, data.MapObject)).key_unlocked);
}
test "older key saves admit defaults and successful locks without deleting inventory" {
    var parsed = try std.json.parseFromSlice(policy.Keys, std.testing.allocator, "{\"mask\":2,\"quest\":0}", .{});
    defer parsed.deinit();
    var world = data.World.init(std.testing.allocator, 8);
    defer world.deinit();
    const player = try world.create(null, .{ data.Player{}, parsed.value });
    const old = try world.create(null, .{data.MapObject{ .classname = "switch", .objective_uses = 1, .properties = &.{.{ .key = "keyname", .value = "item_control_card_green" }} }});
    const reusable = try world.create(null, .{data.MapObject{ .classname = "switch", .objective_uses = 1, .key_unlocked = false, .properties = &.{.{ .key = "keyname", .value = "item_control_card_green" }} }});
    const card = try world.create(null, .{ data.MapObject{ .classname = "item_control_card_yellow" }, data.Body{ .mins = .{ -1, -5, 0 }, .maxs = .{ 1, 5, 16 } }, data.Pickup{ .kind = .{ .key = 3 } } });
    const other = try world.create(null, .{ data.MapObject{ .classname = "item_bottle" }, data.Body{ .mins = @splat(-3), .maxs = @splat(3) }, data.Pickup{ .kind = .{ .key = 14 } } });
    try spawned(&world, card);
    try std.testing.expectEqual([3]f32{ -10, -10, 0 }, (try world.get(card, data.Body)).mins);
    (try world.get(card, data.Body)).mins[1] = -5;
    try restoreAdmit(&world);
    try std.testing.expectEqual([3]f32{ -10, -10, 0 }, (try world.get(card, data.Body)).mins);
    try std.testing.expectEqual([3]f32{ 10, 10, 16 }, (try world.get(card, data.Body)).maxs);
    try std.testing.expectEqual(@as([3]f32, @splat(-3)), (try world.get(other, data.Body)).mins);
    try std.testing.expectEqual(@as(?bool, true), (try world.get(old, data.MapObject)).key_unlocked);
    try std.testing.expectEqual(@as(?bool, false), (try world.get(reusable, data.MapObject)).key_unlocked);
    try std.testing.expectEqual(@as(u32, 2), (try world.get(player, data.Keys)).mask);
    (try world.get(player, data.Keys)).consume("item_control_card_green");
    const owner = try world.persistentId(player);
    try std.testing.expect(allows(&world, (try world.get(old, data.MapObject)).*, owner));
    try std.testing.expect(!allows(&world, (try world.get(reusable, data.MapObject)).*, owner));
}
