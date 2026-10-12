// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Explicit rewriting of persistent references for save and actor ownership.
//! Slots, counters, random seeds, masks and resource indices are never identities.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
pub const Mapping = struct {
    namespace: ?u7 = null,
    from: u32,
    to: u32,
    pub fn id(self: Mapping, value: u32) !u32 {
        if (value == 0) return 0;
        if (self.namespace != null and value > 0xffffff) return error.InvalidLegacyIdentity;
        if (value == self.from) return self.to;
        return if (self.namespace) |namespace| (@as(u32, namespace) << 24) | value else value;
    }
    pub fn one(self: Mapping, value: *u32) !void {
        value.* = try self.id(value.*);
    }
    pub fn optional(self: Mapping, value: *?u32) !void {
        if (value.*) |*id_value| try self.one(id_value);
    }
    pub fn fields(self: Mapping, value: anytype, comptime names: anytype) !void {
        inline for (names) |name| try self.one(&@field(value, name));
    }
    pub fn many(self: Mapping, values: []u32) !void {
        for (values) |*value| try self.one(value);
    }
};
/// Rebind references to an authored destination incarnation before retiring its
/// old ID. The same typed inventory used by legacy migration excludes counters.
pub fn replace(world: *data.World, pending: *@import("target_actions.zig").Queue, from: u32, to: u32) !void {
    if (from == 0 or to == 0) return error.InvalidEntityIdentity;
    if (from == to) return;
    const mapping: Mapping = .{ .from = from, .to = to };
    var query = world.queryAccess(0, 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities()) |entity| {
        inline for (std.meta.fields(data.Component)) |field| if (world.get(entity, field.type) catch null) |value| {
            try remap(@field(data.ComponentId, field.name), value, mapping);
        };
    };
    for (pending) |*entry| if (entry.*) |*action| {
        action.source = try mapping.id(action.source);
        action.activator = try mapping.id(action.activator);
    };
}
/// Shared components map their ids here; every other component maps its own (`remapIds`).
pub fn remap(comptime kind: data.ComponentId, value: *data.types[@intFromEnum(kind)], map: Mapping) !void {
    switch (kind) {
        .body => try map.optional(&value.motion_owner),
        .attachment => try map.one(&value.parent_id),
        .target_sequence => try map.one(&value.activator),
        .exit => try map.one(&value.ending_player),
        .hurt => try map.one(&value.source),
        .ailments => {
            try map.one(&value.freeze_source);
            if (value.poison) |*poison| try map.one(&poison.source);
            if (value.warp) |*warp| try map.one(&warp.source);
        },
        .actor => {
            try map.fields(value, .{ "path", "threat" });
            try map.one(&value.audio.threat);
            // Class states map their own ids.
            inline for (@typeInfo(data.Actor).@"struct".fields) |field| if (comptime @import("snapshot_time.zig").classState(field.type, "remapIds")) try @field(value, field.name).remapIds(map);
        },
        .projectile => {
            try map.one(&value.owner);
            // Each weapon's flight state maps its own ids.
            switch (value.flight) {
                inline else => |*flight| if (comptime hasDecl(@TypeOf(flight.*), "remapIds")) try flight.remapIds(map),
            }
        },
        .melee, .weapon_launch => try map.one(&value.owner),
        .cinematic => try map.fields(value, .{ "trigger", "exit", "viewer" }),
        .script => {
            try map.one(&value.activator);
            for (&value.stack) |*frame| try map.one(&frame.activator);
        },
        .objective => try map.optional(&value.carrier),
        .world_control => switch (value.action) {
            inline else => |*control| if (comptime hasDecl(@TypeOf(control.*), "remapIds")) try control.remapIds(map),
        },
        else => if (comptime hasDecl(@TypeOf(value.*), "remapIds")) try value.remapIds(map),
    }
}

test "legacy reference mapping preserves counters resources and random state" {
    const t = std.testing;
    const map: Mapping = .{ .namespace = 3, .from = 7, .to = 0x1000008 };
    var actor: data.Actor = .{ .definition = 0, .uses = 7, .receipt = 7, .threat = 7, .path = 12, .ground_entity = 12, .audio = .{ .threat = 7 }, .cambot = .{ .alarmed = 12 }, .wyndrax = .{ .source = 13, .charge = 14 } };
    try remap(.actor, &actor, map);
    try t.expectEqual(@as(u32, 0x1000008), actor.threat);
    try t.expectEqual(@as(u32, 0x1000008), actor.audio.threat);
    try t.expectEqual(@as(u32, 0x300000c), actor.path);
    try t.expectEqual(@as(u32, 0x300000c), actor.cambot.alarmed);
    try t.expectEqual(@as(u32, 0x300000e), actor.wyndrax.charge);
    try t.expectEqual(@as(u32, 7), actor.uses);
    try t.expectEqual(@as(u32, 7), actor.receipt);
    try t.expectEqual(@as(u16, 12), actor.ground_entity);
    var control: data.WorldControl = .{ .uses = 7, .action = .{ .timer = .{ .activator = 7, .random = 7, .next_ms = 1200 } } };
    try remap(.world_control, &control, map);
    try t.expectEqual(@as(u32, 0x1000008), control.action.timer.activator);
    try t.expectEqual(@as(u32, 7), control.action.timer.random);
    try t.expectEqual(@as(u32, 7), control.uses);
    try t.expectEqual(@as(?i64, 1200), control.action.timer.next_ms);
    var projectile: data.Projectile = .{ .owner = 7, .weapon = 27, .damage = 10, .born_ms = 100, .stepped_ms = 100, .flight = .{ .wyndrax = .{ .enemy = 12, .targets = .{ 7, 12, 0, 0 } } } };
    try remap(.projectile, &projectile, map);
    try t.expectEqual(@as(u32, 0x1000008), projectile.owner);
    try t.expectEqual(@as(?u32, 0x300000c), projectile.flight.wyndrax.enemy);
    try t.expectEqual([4]u32{ 0x1000008, 0x300000c, 0, 0 }, projectile.flight.wyndrax.targets);
    var binding: data.Binding = .{ .slot = 7, .model = 12 };
    try remap(.binding, &binding, map);
    try t.expectEqual(data.Binding{ .slot = 7, .model = 12 }, binding);
    try t.expectError(error.InvalidLegacyIdentity, map.id(0x2000007));
}

test "rebinding a party incarnation rewrites typed references without renaming other identities" {
    const t = std.testing;
    var world = data.World.initNamespaced(t.allocator, 4, 2);
    defer world.deinit();
    const old: u32 = 0x200002a;
    const birth: u32 = 0x1000021;
    const actor = try world.create(null, .{data.Actor{ .definition = 0, .threat = old, .path = 0x200001b, .receipt = old }});
    const script = try world.create(null, .{data.Script{ .name = "arrival", .activator = old, .revision = old }});
    var pending: @import("target_actions.zig").Queue = @splat(null);
    pending[0] = .{ .source = old, .activator = 7, .due_ms = 1500 };
    try replace(&world, &pending, old, birth);
    try t.expectEqual(birth, (try world.get(actor, data.Actor)).threat);
    try t.expectEqual(@as(u32, 0x200001b), (try world.get(actor, data.Actor)).path);
    try t.expectEqual(old, (try world.get(actor, data.Actor)).receipt);
    try t.expectEqual(birth, (try world.get(script, data.Script)).activator);
    try t.expectEqual(old, (try world.get(script, data.Script)).revision);
    try t.expectEqual(birth, pending[0].?.source);
    try t.expectEqual(@as(u32, 7), pending[0].?.activator);
    try t.expectEqual(@as(i64, 1500), pending[0].?.due_ms);
}
fn hasDecl(comptime T: type, comptime name: []const u8) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"enum", .@"union" => @hasDecl(T, name),
        else => false,
    };
}
