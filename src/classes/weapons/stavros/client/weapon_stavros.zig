// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: stavros. Client adapter: growing meteors.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const registry = @import("../../../../mechanics/client/weapon_classes/registry.zig");
pub const description = @import("weapon_catalog").classes.stavros;
/// Meteors draw at their published scale.
pub fn decorateMissile(missile: registry.Missile) !void {
    for (&missile.rendered.axis, missile.entity.angles2) |*axis, factor| axis.* = v.scale(axis.*, factor);
    missile.rendered.nonNormalizedAxes = c.qtrue;
}
pub fn drawMissile(effect: registry.Effect) !void {
    try @import("stavros.zig").draw(effect.entity, effect.now, effect.ref);
}
