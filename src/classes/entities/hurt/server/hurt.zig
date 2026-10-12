// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: hurt. Hurt volumes: damage on contact at an interval; flagged ones toggle.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"trigger_hurt"};
pub const pass: context.Pass = .volumes;
pub fn prepare(preparing: *context.Prepare) !void {
    const object = preparing.object;
    const amount = try prop.number(object, "damage", try prop.number(object, "dmg", 5));
    if (amount < 0) return error.InvalidHazardDamage;
    const hazard: data.Hazard = .{ .enabled = object.flags & 3 != 3, .toggleable = object.flags & 1 != 0, .damage = @intFromFloat(amount), .interval_ms = @max(50, try prop.milliseconds(object, "wait", 0.5)), .sound = prop.text(object, "sound") orelse "" };
    try preparing.world.put(preparing.entity, hazard);
    try @import("../../../../mechanics/server/world_actions.zig").publishVolume(preparing.world, preparing.entity, preparing.projections, false, if (hazard.enabled) c.CONTENTS_TRIGGER else 0);
}
