// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: authored locks. An entity with a `keyname` admits only activators holding
//! that key; the keys themselves are the keys item class's.
const data = @import("../../game/domain/components.zig");
pub fn allows(world: *data.World, object: data.MapObject, activator: u32) bool {
    inline for (@import("../../game/server/use_classes.zig").locks) |Class| {
        if (!Class.allows(world, object, activator)) return false;
    }
    return true;
}
