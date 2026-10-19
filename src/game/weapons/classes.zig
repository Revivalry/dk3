// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: every weapon description, by name and in weapon-table order. Data only;
//! catalog.zig dispatches the description hooks. Only a weapon's own modules reach it by name.
pub const disruptor = @import("../../classes/weapons/disruptor/disruptor.zig");
pub const ion = @import("../../classes/weapons/ion/ion.zig");
pub const c4 = @import("../../classes/weapons/c4/c4.zig");
pub const shotcycler = @import("../../classes/weapons/shotcycler/shotcycler.zig");
pub const sidewinder = @import("../../classes/weapons/sidewinder/sidewinder.zig");
pub const shockwave = @import("../../classes/weapons/shockwave/shockwave.zig");
pub const gas_hands = @import("../../classes/weapons/gas_hands/gas_hands.zig");
pub const daikatana = @import("../../classes/weapons/sword/sword.zig");
pub const discus = @import("../../classes/weapons/discus/discus.zig");
pub const sunflare = @import("../../classes/weapons/sunflare/sunflare.zig");
pub const venom = @import("../../classes/weapons/venom/venom.zig");
pub const hammer = @import("../../classes/weapons/hammer/hammer.zig");
pub const trident = @import("../../classes/weapons/trident/trident.zig");
pub const zeus = @import("../../classes/weapons/zeus/zeus.zig");
pub const silverclaw = @import("../../classes/weapons/silverclaw/silverclaw.zig");
pub const bolter = @import("../../classes/weapons/bolter/bolter.zig");
pub const stavros = @import("../../classes/weapons/stavros/stavros.zig");
pub const ballista = @import("../../classes/weapons/ballista/ballista.zig");
pub const wyndrax = @import("../../classes/weapons/wyndrax/wyndrax.zig");
pub const nightmare = @import("../../classes/weapons/nightmare/nightmare.zig");
pub const glock = @import("../../classes/weapons/glock/glock.zig");
pub const ripgun = @import("../../classes/weapons/ripgun/ripgun.zig");
pub const slugger = @import("../../classes/weapons/slugger/slugger.zig");
pub const kineticore = @import("../../classes/weapons/kineticore/kineticore.zig");
pub const novabeam = @import("../../classes/weapons/novabeam/novabeam.zig");
pub const metamaser = @import("../../classes/weapons/metamaser/metamaser.zig");
pub const cordite = @import("../../classes/weapons/cordite/cordite.zig");
pub const flashlight = @import("../../classes/weapons/flashlight/flashlight.zig");
/// Every description, in weapon-table order.
pub const all = .{ disruptor, ion, c4, shotcycler, sidewinder, shockwave, gas_hands, daikatana, discus, sunflare, venom, hammer, trident, zeus, silverclaw, bolter, stavros, ballista, wyndrax, nightmare, glock, ripgun, slugger, kineticore, novabeam, metamaser, cordite, flashlight };
