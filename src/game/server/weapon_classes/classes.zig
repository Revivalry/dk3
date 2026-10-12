// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: every server weapon-class adapter. Data only; registry.zig dispatches the hooks.
/// Server weapon adapters, in step order.
pub const adapters = .{
    @import("../../../classes/weapons/c4/server/weapon_c4.zig"),               @import("../../../classes/weapons/hammer/server/weapon_hammer.zig"),       @import("../../../classes/weapons/shockwave/server/weapon_shockwave.zig"),   @import("../../../classes/weapons/trident/server/weapon_trident.zig"),
    @import("../../../classes/weapons/ballista/server/weapon_ballista.zig"),   @import("../../../classes/weapons/novabeam/server/weapon_novabeam.zig"),   @import("../../../classes/weapons/flashlight/server/weapon_flashlight.zig"), @import("../../../classes/weapons/discus/server/weapon_discus.zig"),
    @import("../../../classes/weapons/sunflare/server/weapon_sunflare.zig"),   @import("../../../classes/weapons/stavros/server/weapon_stavros.zig"),     @import("../../../classes/weapons/zeus/server/weapon_zeus.zig"),             @import("../../../classes/weapons/wyndrax/server/weapon_wyndrax.zig"),
    @import("../../../classes/weapons/nightmare/server/weapon_nightmare.zig"), @import("../../../classes/weapons/metamaser/server/weapon_metamaser.zig"),
};
