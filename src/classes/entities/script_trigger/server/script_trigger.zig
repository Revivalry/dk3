// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: script_trigger. Triggers starting an authored AI script or cinematic (flag 1 repeats).
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"trigger_script"};
pub const pass: context.Pass = .triggers;
pub fn prepare(preparing: *context.Prepare) !void {
    try preparing.world.put(preparing.entity, data.Trigger{ .limit = if (preparing.object.flags & 1 != 0) 0 else 1, .wait_ms = try prop.milliseconds(preparing.object, "wait", 2) });
}
pub fn useAuthored(using: *context.Use) !void {
    const world = using.world;
    const object = using.object;
    const trigger = try world.get(using.entity, data.Trigger);
    if (using.now < trigger.ready_ms or (trigger.limit > 0 and trigger.uses >= trigger.limit)) return;
    if (prop.nonempty(object, "cinescript")) {
        const cine = using.router.cinematics orelse return error.MissingCinematicPrograms;
        if (!try cine.trigger(world, using.entity, prop.text(object, "cinescript").?, using.activator)) return;
    } else {
        const name = prop.text(object, "aiscript") orelse return error.MissingAuthoredScript;
        try (using.router.scripts orelse return error.MissingScriptPrograms).start(world, using.entity, name, using.activator, true);
    }
    const used = try world.get(using.entity, data.Trigger);
    used.uses += 1;
    used.ready_ms = using.now + used.wait_ms;
}
/// Touched unless spawnflag 2 makes it use-only.
pub const traits: context.Traits = .{ .touch_volume = true, .use_only_flag = 2 };
