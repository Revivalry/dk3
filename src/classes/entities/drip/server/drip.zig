// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: drip. effect_drip: the authored name remains in e1dm2, but its reference export was removed.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const classnames = [_][]const u8{"effect_drip"};
pub fn spawn(_: *context.Spawn) !context.Spawned {
    return .remove;
}
