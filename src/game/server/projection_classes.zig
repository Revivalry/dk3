// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: the modules that project a restored or transferred entity, in match order: the
//! first whose `projected` components the entity carries and whose `project` accepts it wins.
//! Optional `restorable = false` (a saved entity of the family fails admission), `effect = true`
//! (a slot-bound effect whose binding admission does not check) and `modelless`
//! (a bool or `fn(*World, Entity) bool`: it draws without a model). Data only; persistence.zig
//! dispatches.
pub const publishers = .{
    @import("../../mechanics/server/glow_particles.zig"),            @import("../../mechanics/server/props.zig"),                       @import("../../classes/actors/thunderskeet/server/thunder_spray.zig"), @import("../../classes/entities/healthtree/server/healthtrees.zig"),
    @import("../../classes/actors/dwarf/server/dwarf_axes.zig"),     @import("../../mechanics/server/actor_attacks.zig"),               @import("../../mechanics/server/actor_lasers.zig"),                    @import("../../classes/actors/cryotech/server/cryo_spray.zig"),
    @import("../../classes/actors/froginator/server/frog_spit.zig"), @import("../../mechanics/server/cinematics.zig"),                  @import("../../mechanics/server/actors.zig"),                          @import("../../mechanics/server/items.zig"),
    @import("../../mechanics/server/projectiles.zig"),               @import("../../classes/weapons/c4/server/c4.zig"),                 @import("../../classes/weapons/hammer/server/hammer.zig"),             @import("../../classes/weapons/shockwave/server/shockwave.zig"),
    @import("../../classes/weapons/novabeam/server/novabeam.zig"),   @import("../../classes/weapons/flashlight/server/flashlight.zig"), @import("../../classes/weapons/zeus/server/zeus.zig"),                 @import("../../classes/weapons/metamaser/server/metamaser_death.zig"),
    @import("../../classes/weapons/nightmare/server/nightmare.zig"), @import("../../classes/entities/train/server/trains.zig"),
};
/// Class hooks around a load: `restoreAdmit(*World) !void` while the save is admitted,
/// `restoreBegin(*World) !void` before entities are projected, `restoreEnd(*World, i64) void`
/// after.
pub const restore = .{ @import("../../classes/entities/mover/server/movers.zig"), @import("../../classes/entities/light/server/lights.zig") };
