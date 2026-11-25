// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: monster_spawn. Spawns its authored monster when used.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const policy = @import("../monster_spawn.zig");
const v = @import("../../../../core/domain/vector.zig");
pub const classnames = [_][]const u8{"target_monster_spawn"};
pub fn useAuthored(using: *context.Use) !void {
    const actors = using.router.actors orelse return error.MissingActorDefinitions;
    const world = using.world;
    const object = using.object;
    const classname = prop.text(object, "monsterclass") orelse return error.MissingSpawnClass;
    var pose = (try world.get(using.entity, data.Transform)).*;
    pose.position[2] += 0.03125;
    if (@import("actor_catalog").find(classname) != null) {
        var flags = object.flags;
        if (using.source) |other| if ((other.get(data.Actor) catch null) != null) {
            flags = (try other.get(data.MapObject)).flags;
        };
        const spawned = try actors.spawnAuthored(world, using.slots, using.projections, try monsterObject(actors.allocator, object, classname, flags), pose, using.now);
        const body = (try world.get(spawned, data.Body)).*;
        const binding = (try world.get(spawned, data.Binding)).*;
        const origin = (try world.get(spawned, data.Transform)).position;
        const clear = try policy.placement(@import("../../../../mechanics/server/actor_collision.zig").probe(), .{
            .start = origin,
            .end = origin,
            .mins = body.mins,
            .maxs = body.maxs,
            .slot = binding.slot,
            .mask = body.collision_mask,
        });
        if (clear) |point| {
            if (v.length(v.subtract(point, origin)) > 0.001) {
                (try world.get(spawned, data.Transform)).position = point;
                try actors.publish(world, spawned, using.projections, using.now);
                var message: [256]u8 = undefined;
                engine.print(try std.fmt.bufPrintZ(&message, "dk3 factory clearance: class={s} from={d:.2},{d:.2},{d:.2} to={d:.2},{d:.2},{d:.2}\n", .{ classname, origin[0], origin[1], origin[2], point[0], point[1], point[2] }));
            }
        } else engine.print("dk3 factory clearance: no clear origin within bounded search\n");
    } else {
        _ = try @import("../../../../mechanics/server/items.zig").spawnDynamic(world, using.slots, using.projections, classname, pose, using.now, actors.episode);
    }
    if (prop.text(object, "sound")) |sound| try @import("../../../../mechanics/server/events.zig").sound(world, using.slots, using.projections, sound, pose.position, c.ENTITYNUM_NONE, c.CHAN_AUTO, using.now);
    if (using.slots.find(using.entity)) |slot| {
        engine.unlink(&using.projections[slot]);
        try using.slots.release(slot, using.entity);
    }
    try world.destroy(using.entity);
}

fn monsterObject(allocator: std.mem.Allocator, source: data.MapObject, classname: []const u8, flags: u32) !data.MapObject {
    var pairs: std.ArrayList(data.Property) = .empty;
    defer pairs.deinit(allocator);
    for (source.properties) |pair| {
        if (std.mem.eql(u8, pair.key, "classname")) continue;
        try pairs.append(allocator, .{ .key = if (std.mem.eql(u8, pair.key, "monsterclass")) "classname" else if (std.mem.eql(u8, pair.key, "muniqueid")) "uniqueid" else pair.key, .value = pair.value });
    }
    return .{ .classname = classname, .targetname = source.targetname, .target = source.target, .flags = flags, .properties = try pairs.toOwnedSlice(allocator) };
}

test "authored monster factory preserves death outputs and maps the unique id" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try monsterObject(arena.allocator(), .{ .classname = "target_monster_spawn", .targetname = "tskeetspawn", .flags = 16, .properties = &.{
        .{ .key = "classname", .value = "target_monster_spawn" },
        .{ .key = "monsterclass", .value = "monster_thunderskeet" },
        .{ .key = "muniqueid", .value = "tskeet" },
        .{ .key = "deathtarget", .value = "tskeetdead" },
        .{ .key = "spawnname", .value = "item_megashield" },
    } }, "monster_thunderskeet", 2);
    try std.testing.expectEqualStrings("monster_thunderskeet", result.classname);
    try std.testing.expectEqualStrings("monster_thunderskeet", prop.text(result, "classname").?);
    try std.testing.expectEqualStrings("tskeet", prop.text(result, "uniqueid").?);
    try std.testing.expectEqualStrings("tskeetdead", prop.text(result, "deathtarget").?);
    try std.testing.expectEqualStrings("item_megashield", prop.text(result, "spawnname").?);
    try std.testing.expectEqualStrings("tskeetspawn", result.targetname);
    try std.testing.expectEqual(@as(u32, 2), result.flags);
}
