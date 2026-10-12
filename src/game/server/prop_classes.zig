// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: the roles a physical prop can play (props.zig), with optional hooks run in this
//! order. Data only.
//!
//! | Hook | Default |
//! |---|---|
//! | `propAge(*World, Entity, *Scenery, i64) !bool` | false; true removes the prop before its expiry check |
//! | `propTick(*props.Tick, *Scenery) !bool` | false; true: the role consumed the prop this frame |
//! | `propContact(*World, Entity, *Scenery, Vec3, Vec3) !?Vec3` | null: the shared bounce/toss clip |
pub const roles = .{ @import("../../mechanics/server/actor_gibs.zig"), @import("../../classes/entities/explosive/server/explosives.zig"), @import("../../mechanics/server/player_corpses.zig"), @import("../../classes/entities/scenery/server/scenery.zig") };
