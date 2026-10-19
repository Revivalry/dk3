// SPDX-License-Identifier: GPL-2.0-or-later
//! weapon-class: ion. Client adapter: the trail behind the bolt.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const registry = @import("../../../../mechanics/client/weapon_classes/registry.zig");
pub const description = @import("weapon_catalog").classes.ion;
pub fn drawSprite(sprite: registry.Sprite) !void {
    try @import("ion.zig").draw(sprite.entity, sprite.origin, sprite.now, sprite.ref);
    sprite.counters.ions += 1;
}
