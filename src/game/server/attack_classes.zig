// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: the server modules that step and publish persistent actor attacks. Each declares
//! `pub const policy` (whose `attack_payloads` it handles) and `publish`/`step`. Data only;
//! actor_attacks.zig dispatches.
pub const handlers = .{
    @import("../../classes/actors/nharre/server/nharre_reaper.zig"),     @import("../../mechanics/server/summon_effects.zig"), @import("../../mechanics/server/actor_fireballs.zig"),
    @import("../../classes/actors/psyclaw/server/psyclaw_spheres.zig"),  @import("../../mechanics/server/gunner_bursts.zig"),  @import("../../classes/actors/sludge/server/sludge_globs.zig"),
    @import("../../classes/actors/prisoners/server/prisoner_rocks.zig"), @import("../../mechanics/server/shafts.zig"),         @import("../../mechanics/server/venom_spit.zig"),
    @import("../../mechanics/server/actor_rockets.zig"),                 @import("../../mechanics/server/meteors.zig"),        @import("../../mechanics/server/wisp_lightning.zig"),
    @import("../../classes/actors/knights/server/knight_attacks.zig"),
};
