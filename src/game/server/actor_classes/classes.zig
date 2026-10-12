// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: every actor class adapter, and the adapters of monster classes spawned outside the
//! actor catalog. Data only; registry.zig dispatches the hooks.
/// One adapter per class policy, in no particular order.
pub const adapters = .{
    @import("../../../classes/actors/archers/server/actor_archers.zig"),       @import("../../../classes/actors/battleboar/server/battleboar.zig"),       @import("../../../classes/actors/buboid/server/buboid.zig"),
    @import("../../../classes/actors/cambot/server/cambot.zig"),               @import("../../../classes/actors/cerberus/server/cerberus.zig"),           @import("../../../classes/actors/chaingang/server/chaingang.zig"),
    @import("../../../classes/actors/civilians/server/civilians.zig"),         @import("../../../classes/actors/column/server/column.zig"),               @import("../../../classes/actors/companions/server/actor_companions.zig"),
    @import("../../../classes/actors/crox/server/actor_crox.zig"),             @import("../../../classes/actors/cryotech/server/cryotech.zig"),           @import("../../../classes/actors/deathsphere/server/deathsphere.zig"),
    @import("../../../classes/actors/doombat/server/doombat.zig"),             @import("../../../classes/actors/dragon/server/dragon.zig"),               @import("../../../classes/actors/dwarf/server/dwarf.zig"),
    @import("../../../classes/actors/femgang/server/femgang.zig"),             @import("../../../classes/actors/fish/server/fish.zig"),                   @import("../../../classes/actors/froginator/server/froginator.zig"),
    @import("../../../classes/actors/garroth/server/garroth.zig"),             @import("../../../classes/actors/ghost/server/ghost.zig"),                 @import("../../../classes/actors/griffon/server/griffon.zig"),
    @import("../../../classes/actors/gunners/server/actor_gunners.zig"),       @import("../../../classes/actors/harpy/server/harpy.zig"),                 @import("../../../classes/actors/inmater/server/inmater.zig"),
    @import("../../../classes/actors/kage/server/kage.zig"),                   @import("../../../classes/actors/knights/server/actor_knights.zig"),       @import("../../../classes/actors/labmonkey/server/labmonkey.zig"),
    @import("../../../classes/actors/lasergat/server/lasergat.zig"),           @import("../../../classes/actors/lycanthir/server/lycanthir.zig"),         @import("../../../classes/actors/medusa/server/medusa.zig"),
    @import("../../../classes/actors/mikiko/server/mikiko.zig"),               @import("../../../classes/actors/mishima_guard/server/mishima_guard.zig"), @import("../../../classes/actors/nharre/server/nharre.zig"),
    @import("../../../classes/actors/prisoners/server/actor_prisoners.zig"),   @import("../../../classes/actors/protopod/server/protopod.zig"),           @import("../../../classes/actors/psyclaw/server/psyclaw.zig"),
    @import("../../../classes/actors/ragemaster/server/ragemaster.zig"),       @import("../../../classes/actors/rats/server/actor_rats.zig"),             @import("../../../classes/actors/rockgat/server/rockgat.zig"),
    @import("../../../classes/actors/rocketgang/server/actor_rocketgang.zig"), @import("../../../classes/actors/rocketmp/server/actor_rocketmp.zig"),     @import("../../../classes/actors/rotworm/server/rotworm.zig"),
    @import("../../../classes/actors/satyr/server/satyr.zig"),                 @import("../../../classes/actors/seagull/server/seagull.zig"),             @import("../../../classes/actors/shark/server/shark.zig"),
    @import("../../../classes/actors/skeeter/server/skeeter.zig"),             @import("../../../classes/actors/skeleton/server/skeleton.zig"),           @import("../../../classes/actors/sludge/server/sludge.zig"),
    @import("../../../classes/actors/spider/server/spider.zig"),               @import("../../../classes/actors/stavros/server/actor_stavros.zig"),       @import("../../../classes/actors/surgeon/server/surgeon.zig"),
    @import("../../../classes/actors/thief/server/thief.zig"),                 @import("../../../classes/actors/thunderskeet/server/thunderskeet.zig"),   @import("../../../classes/actors/vermin/server/actor_vermin.zig"),
    @import("../../../classes/actors/wyndrax/server/actor_wyndrax.zig"),
};
/// Adapters for monster classes spawned outside the actor catalog. Each declares `classname`
/// and, when the actor system spawns it, `spawnForeign`.
pub const foreign = .{ @import("../../../classes/actors/wisp/server/wisp.zig"), @import("../../../classes/actors/firefly/server/firefly.zig"), @import("../../../classes/entities/path_corner/server/path_corner.zig") };
