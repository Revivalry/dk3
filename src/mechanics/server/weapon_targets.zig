// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: class-supplied automatic weapon acquisition across owned worlds.
const data = @import("../../game/domain/components.zig");
const Ref = @import("../domain/world_references.zig").Ref;
const Policy = @FieldType(@import("weapon_catalog").Spec, "automatic_targets");
pub fn allowed(target: Ref, owner: u32, policy: Policy, deathmatch: bool) !bool {
    if (try target.id() == owner or (target.get(data.Health) catch return false).current <= 0) return false;
    const role: Policy.Role = if (@import("../../game/server/session_classes.zig").party.isMember(target.world, target.entity))
        .party
    else if ((target.get(data.Actor) catch null) != null)
        .actor
    else if ((target.get(data.Player) catch null) != null)
        .player
    else
        .other;
    return policy.allows(role, deathmatch);
}
