// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: metamaser. Client adapter: cubes, their beams and locks.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const registry = @import("../../../../mechanics/client/weapon_classes/registry.zig");
pub const description = @import("weapon_catalog").classes.metamaser;
pub fn drawEffect(effect: registry.Effect) !void {
    try @import("metamaser.zig").draw(effect.entity, effect.entities, effect.now, effect.ref);
}
pub fn drawMissile(effect: registry.Effect) !void {
    try @import("metamaser.zig").draw(effect.entity, effect.entities, effect.now, effect.ref);
}
