// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: c4. Client adapter: the red blink of a placed charge.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const registry = @import("../../../../mechanics/client/weapon_classes/registry.zig");
pub const description = @import("weapon_catalog").classes.c4;
/// For 100 ms after each blink time the charge lights red.
pub fn decorateMissile(missile: registry.Missile) !void {
    const entity = missile.entity;
    if (entity.time2 <= 0 or missile.now < entity.time2 or missile.now - entity.time2 >= 100) return;
    _ = engine.gateway.call(c.CG_R_ADDLIGHTTOSCENE, .{ &missile.rendered.origin, engine.floatArg(100), engine.floatArg(1), engine.floatArg(0), engine.floatArg(0) });
}
