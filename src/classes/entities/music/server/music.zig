// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: music. Music changes.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .music;
pub const classnames = [_][]const u8{"trigger_changemusic"};
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    const object = spawning.object;
    return .{ .control = .{ .music = .{ .path = prop.text(object, "path") orelse return error.MissingMusicPath, .volume = std.math.clamp(try prop.number(object, "volume", 1), 0, 1) } } };
}
pub fn use(control: *Control, _: u32) !void {
    const music = &control.control.action.music;
    control.control.ready_ms = control.now + 1000;
    music.changed_ms = control.now;
    try @import("../../../../mechanics/server/music.zig").publish(music.path, music.volume);
}
/// Players trigger it unless flag 1 restricts it to scripted performers.
pub fn touches(contact: context.Contact) !bool {
    return (contact.player() and contact.object.flags & 1 == 0) or (contact.world.get(contact.other, data.Performer) catch null) != null;
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(_: *const context.Saved, action: context.Action) !void {
    const music = action.music;
    if (!std.math.isFinite(music.volume) or music.volume < 0 or music.volume > 1 or music.path.len == 0 or music.path.len >= 64) return error.InvalidSavedMusic;
}
/// The track this control last set (map music restore picks the latest).
pub fn soundtrack(action: context.Action) ?context.Soundtrack {
    return switch (action) {
        .music => |music| .{ .path = music.path, .volume = music.volume, .changed_ms = music.changed_ms },
        else => null,
    };
}
