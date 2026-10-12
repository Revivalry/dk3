// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Snapshot effect dispatch, separate from first-person animation and simulation.
//! Never names a concrete class: weapon effects are drawn by client weapon class adapters.
const c = @import("../../engine/abi.zig").c;
pub fn draw(entity: c.entityState_t, entities: []const c.entityState_t, now: i32, ref: *const c.refdef_t, client: i32) !void {
    try @import("weapon_classes/registry.zig").drawEffect(.{ .entity = entity, .entities = entities, .now = now, .ref = ref, .client = client });
}
