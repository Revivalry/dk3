// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: classes whose entities bots must dodge. Data only; bot_evasion.zig reads them.
//!
//! | Declaration | Meaning |
//! |---|---|
//! | `contact_missile: type` (a component) | a slow missile that bursts on actors as well as geometry |
//! | `hazard: type`, `forecast(*World, Entity, i64) !?struct { eta, point }` | a hazard with a predicted impact |
//! | `probe(*World, Entity, i64) !bool` | prints the entity's state for `dk3_runtime_projectiles` |
//! | `diagnostic_name: []const u8` (with `hazard`) | how bot diagnostics name an unnamed entity |
pub const classes = .{ @import("../../classes/actors/thunderskeet/server/thunder_spray.zig"), @import("../../classes/actors/froginator/server/frog_spit.zig") };
