// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: trigger. Relays and touch triggers: once, multiple, relay and counter limits.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{ "trigger_once", "trigger_multiple", "trigger_relay", "trigger_counter" };
pub const pass: context.Pass = .triggers;
pub fn prepare(preparing: *context.Prepare) !void {
    const object = preparing.object;
    const counter = std.mem.eql(u8, object.classname, "trigger_counter");
    const limit = try prop.number(object, "count", if (counter) 2 else 0);
    const wait = try prop.milliseconds(object, "wait", 0);
    try preparing.world.put(preparing.entity, data.Trigger{ .limit = if (std.mem.eql(u8, object.classname, "trigger_once")) 1 else if (counter) @intFromFloat(@max(1, limit)) else @intFromFloat(@max(0, limit)), .counter = counter, .wait_ms = if (wait > 0) wait else 200 });
}
pub fn traits(classname: []const u8) context.Traits {
    if (std.mem.eql(u8, classname, "trigger_relay")) return .{ .relays = true };
    if (std.mem.eql(u8, classname, "trigger_counter")) return .{ .relays = true, .counter = true };
    return .{ .relays = true, .touch_volume = true };
}
