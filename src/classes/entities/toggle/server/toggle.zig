// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: toggle. Toggle volumes firing when entered and, flagged, when left.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .toggle;
pub const classnames = [_][]const u8{"trigger_toggle"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    const binding = (try spawning.world.get(spawning.entity, data.Binding)).*;
    const projection = spawning.projections[binding.slot].shared;
    return .{ .control = .{ .toggle = .{ .center = v.scale(v.add(projection.absmin, projection.absmax), 0.5), .radius = v.length(v.subtract(projection.absmax, projection.absmin)) * 0.57 } } };
}
/// Flag 8 admits only companions; flag 4 admits companions besides players.
pub fn touches(contact: context.Contact) !bool {
    return if (contact.object.flags & 8 != 0) contact.companion() else contact.player() or (contact.companion() and contact.object.flags & 4 != 0);
}
pub fn touch(control: *Control, other: ecs.Entity) !void {
    const toggle = &control.control.action.toggle;
    if (toggle.activator != 0) return;
    toggle.activator = try control.world.persistentId(other);
    control.control.ready_ms = control.now + 200;
    try control.router.fire(control.world, control.slots, control.projections, control.entity, toggle.activator, control.now);
}
/// When its occupant leaves, it rearms, and flag 1 fires its targets again.
pub fn step(control: *Control) !void {
    const toggle = &control.control.action.toggle;
    if (toggle.activator == 0 or control.now < control.control.ready_ms) return;
    control.control.ready_ms = control.now + 200;
    const activator = toggle.activator;
    const actor = control.world.find(activator);
    if (actor) |other| if (v.length(v.subtract((try control.world.get(other, data.Transform)).position, toggle.center)) <= toggle.radius) return;
    toggle.activator = 0;
    if ((try control.object()).flags & 1 != 0 and actor != null) try control.router.fire(control.world, control.slots, control.projections, control.entity, activator, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(_: *const context.Saved, action: context.Action) !void {
    const toggle = action.toggle;
    if (!std.math.isFinite(toggle.radius) or toggle.radius < 0) return error.InvalidSavedToggle;
    for (toggle.center) |value| if (!std.math.isFinite(value)) return error.InvalidSavedToggle;
}
