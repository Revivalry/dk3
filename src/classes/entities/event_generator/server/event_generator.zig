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
