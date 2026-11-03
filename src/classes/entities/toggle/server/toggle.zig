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
/// Hold companion-only stations while their authored target chain exists.
/// Maps release the station by removing that chain; distance and elapsed time
/// cannot stand in for the player's having completed the puzzle.
pub fn companionDuty(world: *data.World, entity: ecs.Entity) !?context.CompanionDuty {
    const object = (try world.get(entity, data.MapObject)).*;
    if (object.flags & 8 == 0 or object.target.len == 0) return null;
    if ((try @import("../../../../mechanics/server/names.zig").named(world, object.target)).count == 0) return null;
    const control = (try world.get(entity, data.WorldControl)).*;
    const body = (try world.get(entity, data.Body)).*;
    const origin = (try world.get(entity, data.Transform)).position;
    return .{ .mins = v.add(origin, body.mins), .maxs = v.add(origin, body.maxs), .occupant = control.action.toggle.activator };
}
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

test "companion station waits for the authored completion, including restored occupants" {
    const t = std.testing;
    var world = data.World.init(t.allocator, 8);
    defer world.deinit();
    const chain = try world.create(null, .{data.MapObject{ .classname = "func_event_generator", .targetname = "puzzle" }});
    const station = try world.create(null, .{
        data.MapObject{ .classname = "trigger_toggle", .flags = 9, .target = "puzzle" },
        data.WorldControl{ .action = .{ .toggle = .{ .center = .{ 100, 0, 0 }, .radius = 48, .activator = 7 } } },
        data.Body{ .mins = .{ 80, -20, -8 }, .maxs = .{ 120, 20, 8 } },
        data.Transform{},
    });
    const offered = (try companionDuty(&world, station)).?;
    try t.expectEqual(@as(u32, 7), offered.occupant);
    try t.expectEqual(data.Vec3{ 80, -20, -8 }, offered.mins);
    // Departure distance or a timer cannot end the duty. The authored chain
    // disappearing releases it, even if a save retained the occupant ID.
    try world.destroy(chain);
    try t.expectEqual(null, try companionDuty(&world, station));
    (try world.get(station, data.MapObject)).flags = 1;
    try t.expectEqual(null, try companionDuty(&world, station));
}
