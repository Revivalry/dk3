// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the class validators the snapshot decoder calls back for class-owned saved
//! state (domain/snapshot.zig `class_validators`); each forwards to its class registry.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const data = @import("../../game/domain/components.zig");
const Saved = @import("../domain/snapshot.zig").Saved;
/// Whether the restored entity's class declares the boolean `trait` (exits, monitors, exploding
/// walls).
pub fn hasTrait(saved: *const Saved, comptime trait: []const u8) !bool {
    return @field(@import("entity_classes/registry.zig").traitsOf(try saved.classname()), trait);
}
pub fn actorAttack(saved: *const Saved, value: data.ActorAttack) !void {
    try @import("actor_classes/registry.zig").validateSavedAttack(saved, value);
}
pub fn control(saved: *const Saved, value: data.WorldControl) !void {
    try @import("entity_classes/registry.zig").validateSaved(saved, value.action);
}
