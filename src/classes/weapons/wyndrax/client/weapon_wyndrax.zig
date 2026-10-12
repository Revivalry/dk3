// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: wyndrax. Client adapter: wisps at their published scale and fade.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const registry = @import("../../../../mechanics/client/weapon_classes/registry.zig");
pub const description = @import("weapon_catalog").classes.wyndrax;
pub fn decorateMissile(missile: registry.Missile) !void {
    for (&missile.rendered.axis, missile.entity.angles2) |*axis, factor| axis.* = v.scale(axis.*, factor);
    missile.rendered.nonNormalizedAxes = c.qtrue;
    missile.rendered.shaderRGBA[3] = @intFromFloat(std.math.clamp(missile.entity.origin2[2], 0, 1) * 255);
}
pub fn drawMissile(effect: registry.Effect) !void {
    try @import("wyndrax.zig").draw(effect.entity, effect.entities, effect.now, effect.ref);
}
