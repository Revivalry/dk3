// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: sunflare. Client adapter: burning fires.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const registry = @import("../../../../mechanics/client/weapon_classes/registry.zig");
pub const description = @import("weapon_catalog").classes.sunflare;
pub fn drawEffect(effect: registry.Effect) !void {
    try @import("sunflare.zig").draw(effect.entity, effect.now, effect.ref);
}
