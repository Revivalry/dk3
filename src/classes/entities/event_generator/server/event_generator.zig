// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: event_generator. Authored target timelines: invisible volumes (SVF_NOCLIENT at spawn) firing timed events.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const rules = @import("../../../../mechanics/domain/world_actions.zig");
pub const classnames = [_][]const u8{"func_event_generator"};
pub const brush: context.Brush = .{ .hidden = true };
pub const pass: context.Pass = .volumes;
/// Players and their companions are ordinary activators. The monster flag
/// admits other actors, including a dying actor firing its death targets.
pub fn allowsSequence(world: *data.World, entity: @import("../../../../core/ecs/world.zig").Entity, activator: u32) bool {
    const owner = @import("../../../../mechanics/server/region_access.zig").find(world, activator) orelse return false;
    if ((owner.get(data.Player) catch null) != null) return true;
    if (@import("../../../../game/server/session_classes.zig").party.isMember(owner.world, owner.entity)) return true;
    const sequence = world.get(entity, data.TargetSequence) catch return false;
    return sequence.actor_allowed and (owner.get(data.Actor) catch null) != null;
}
pub fn prepare(preparing: *context.Prepare) !void {
    const object = preparing.object;
    var events: std.array_list.Managed(rules.Event) = .init(preparing.allocator);
    for (object.properties) |property| {
        if (try rules.eventProperty(property.key, property.value, events.items.len)) |event| try events.append(event);
    }
    std.mem.sort(rules.Event, events.items, {}, struct {
        fn less(_: void, a: rules.Event, b: rules.Event) bool {
            return a.delay_ms < b.delay_ms;
        }
    }.less);
    try preparing.world.put(preparing.entity, data.TargetSequence{ .events = try events.toOwnedSlice(), .once = object.flags & 1 != 0, .touch = object.flags & 2 != 0, .actor_allowed = object.flags & 4 != 0, .wait_ms = @max(50, try prop.milliseconds(object, "wait", 0.2)), .sound = prop.text(object, "sound") orelse "" });
    if ((preparing.world.get(preparing.entity, data.Binding) catch null) != null) try @import("../../../../mechanics/server/world_actions.zig").publishVolume(preparing.world, preparing.entity, preparing.projections, false, if (object.flags & 2 != 0) c.CONTENTS_TRIGGER else 0);
}

test "event timelines accept companions without admitting unflagged monsters" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 8);
    defer world.deinit();
    const generator = try world.create(null, .{data.TargetSequence{ .events = &.{} }});
    const companion = try world.create(null, .{data.Companion{ .identity = .mikiko }});
    const monster = try world.create(null, .{data.Actor{ .definition = 0 }});
    try t.expect(allowsSequence(&world, generator, try world.persistentId(companion)));
    try t.expect(!allowsSequence(&world, generator, try world.persistentId(monster)));
    (try world.get(generator, data.TargetSequence)).actor_allowed = true;
    try t.expect(allowsSequence(&world, generator, try world.persistentId(monster)));
    try t.expect(!allowsSequence(&world, generator, 0));
}
