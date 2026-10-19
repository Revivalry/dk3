// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: every client weapon-class adapter. Data only; registry.zig dispatches the hooks.
pub const adapters = .{
    @import("../../../classes/weapons/novabeam/client/novabeam.zig"),          @import("../../../classes/weapons/flashlight/client/flashlight.zig"),      @import("../../../classes/weapons/sunflare/client/weapon_sunflare.zig"), @import("../../../classes/weapons/zeus/client/weapon_zeus.zig"),
    @import("../../../classes/weapons/nightmare/client/weapon_nightmare.zig"), @import("../../../classes/weapons/ion/client/weapon_ion.zig"),             @import("../../../classes/weapons/c4/client/c4.zig"),                    @import("../../../classes/weapons/stavros/client/weapon_stavros.zig"),
    @import("../../../classes/weapons/wyndrax/client/weapon_wyndrax.zig"),     @import("../../../classes/weapons/metamaser/client/weapon_metamaser.zig"),
};
