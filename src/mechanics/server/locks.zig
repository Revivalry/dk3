// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: authored locks. An entity with a `keyname` admits only activators holding
//! that key; the keys themselves are the keys item class's.
const data = @import("../../game/domain/components.zig");
pub fn allows(world: *data.World, object: data.MapObject, activator: u32) bool {
    const name = @import("properties.zig").text(object, "keyname") orelse return true;
    if (name.len == 0) return true;
    const player = @import("region_access.zig").find(world, activator) orelse return false;
    const keys = player.get(data.Keys) catch return false;
    return keys.has(name);
}
