// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: secret. Secret areas: found once, with the episode secret sound and a message.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .secret;
pub const classnames = [_][]const u8{"trigger_secret"};
pub fn spawn(_: *context.Spawn) !context.Spawned {
    return .{ .control = .secret };
}
pub fn use(control: *Control, activator: u32) !void {
    if (control.control.uses > 0) return;
    const player = control.world.find(activator) orelse return;
    const character = control.world.get(player, data.Character) catch return;
    control.control.uses = 1;
    character.secrets += 1;
    const episode = (control.router.actors orelse return error.MissingActorDefinitions).episode;
    var path: [40]u8 = undefined;
    try @import("../../../../mechanics/server/events.zig").soundAt(control.world, control.slots, control.projections, player, try std.fmt.bufPrint(&path, "e{d}/e{d}_secret.wav", .{ episode, episode }), control.now);
    try @import("../../../../mechanics/server/messages.zig").centerPrint(control.world, player, prop.text(try control.object(), "message") orelse "Secret found.");
    try control.router.fire(control.world, control.slots, control.projections, control.entity, activator, control.now);
}
pub fn touches(contact: context.Contact) !bool {
    return contact.player();
}
