// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: client class modules with session hooks, all optional. Data only; client.zig
//! runs the hooks.
//!
//! | Hook | Default |
//! |---|---|
//! | `reset() void` | no client state: runs at shutdown |
//! | `world_state: bool` | false: `reset` runs only at shutdown (true: also when a save is restored) |
//! | `screen(entities, client, now_ms, display) void` | nothing drawn over the 2D screen |
//! | `command() void` | server commands are not the class's |
//! | `viewOffset(now_ms) Vec3` | the class adds nothing to the view angles |
//! | `console_commands: [N][*:0]const u8` | the class registers no local console commands |
//! | `console(name, now_ms) bool` | the class handles no local console command |
//! | `hud(*const playerState_t, now_ms, display) void` | nothing drawn over the HUD |
//! | `holdsInventoryColumn() bool` | the weapon list keeps its column |
//! | `cycle_panels: usize` with `cycleOpen(slot, now_ms) bool`, `cycleClose(slot, now_ms)`, `cycleStep(slot, direction, now_ms)`, `cycleApply(slot, now_ms)` | the class adds no HUD cycle mode (hud_cycle.zig); `cycleOpen` false skips an absent panel |
pub const presenters = .{
    @import("../../mechanics/client/flame_particles.zig"),               @import("../../classes/actors/chaingang/client/chaingang.zig"),                   @import("../../classes/actors/buboid/client/buboid.zig"),
    @import("../../mechanics/client/venom_spit.zig"),                    @import("../../classes/weapons/ion/client/ion.zig"),                              @import("../../classes/actors/wisp/client/wisps.zig"),
    @import("../../mechanics/client/wisp_lightning.zig"),                @import("../../mechanics/client/actor_meteors.zig"),                              @import("../../mechanics/client/summon_effects.zig"),
    @import("../../classes/actors/nharre/client/nharre_reaper.zig"),     @import("../../classes/entities/complex_particles/client/complex_particles.zig"), @import("../../classes/entities/lightning/client/lightning.zig"),
    @import("../../classes/entities/weather/client/weather.zig"),        @import("../../classes/entities/target_effect/client/target_effects.zig"),        @import("../../classes/actors/fish/client/blood_clouds.zig"),
    @import("../../classes/entities/chest/client/chests.zig"),           @import("../../classes/actors/medusa/client/medusa.zig"),                         @import("../../classes/entities/earthquake/client/earthquakes.zig"),
    @import("../../classes/actors/companions/client/companion_hud.zig"),
};
