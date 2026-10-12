// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: zeus. Client adapter: the lightning graph.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const registry = @import("../../../../mechanics/client/weapon_classes/registry.zig");
pub const description = @import("weapon_catalog").classes.zeus;
pub fn drawEffect(effect: registry.Effect) !void {
    try @import("zeus.zig").draw(effect.entity, effect.now, effect.ref, effect.client);
}
/// The graph's closing frame ends the first-person cast.
pub fn viewEnd(entity: c.entityState_t) ?i64 {
    return if (entity.frame == 100) entity.time2 else null;
}
