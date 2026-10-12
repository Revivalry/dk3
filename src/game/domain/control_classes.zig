// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: the classes owning world-control states. Each declares `controls`, its
//! `.{ .tag, .State }` pairs (the tag is the saved name). Data only; world_controls.zig builds the
//! `Action` union in this order.
const items = @import("item_catalog");
pub const classes = .{
    items.chest,                                                           @import("../../classes/actors/fish/domain/blood_cloud.zig"),                   @import("../../classes/entities/target_effect/domain/target_effect.zig"),
    @import("../../classes/entities/weather/domain/weather.zig"),          @import("../../classes/entities/lightning/domain/lightning.zig"),              @import("../../classes/entities/complex_particles/domain/complex_particles.zig"),
    @import("../../classes/entities/light/domain/lightstyles.zig"),        @import("../../classes/entities/spotlight/domain/spotlight.zig"),              @import("../../classes/entities/earthquake/domain/earthquake.zig"),
    @import("../../mechanics/domain/gib_emitter.zig"),                     @import("../../classes/entities/debris/domain/debris.zig"),                    @import("../../classes/entities/room/domain/controls/room.zig"),
    @import("../../mechanics/domain/laser.zig"),                           items.hosportal,                                                               @import("../../classes/entities/timer/domain/controls/timer.zig"),
    @import("../../classes/entities/speaker/domain/controls/speaker.zig"), @import("../../classes/entities/push/domain/controls/push.zig"),               @import("../../classes/entities/teleport/domain/controls/teleport.zig"),
    @import("../../classes/entities/secret/domain/controls/secret.zig"),   @import("../../classes/entities/toggle/domain/controls/toggle.zig"),           @import("../../classes/entities/music/domain/controls/music.zig"),
    @import("../../classes/entities/console/domain/controls/console.zig"), @import("../../classes/entities/remove_item/domain/controls/remove_item.zig"),
};
