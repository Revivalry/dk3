// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: server classes with session hooks, and the class that provides the player's
//! party. Data only; server.zig runs the hooks.
//!
//! | Hook | Default |
//! |---|---|
//! | `sessionReset() void` | no transient state: runs at shutdown and before a restore |
//! | `restoreDefaults(*World) !void` | an older save needs no authored defaults rebuilt |
//! | `camera(*World, Entity, *playerState_t) !void` (in this order) | the class never steers a view |
//! | `status(*World, Entity, *playerState_t, *const weapons.Table) !void` (after `camera`) | the class reports nothing in the player's HUD stats |
//! | `releasePlayer(*World, Entity) !void` | a leaving or travelling player is not held by it |
//! | `takesView(*World) bool` | it never takes the view over (as a cinematic does) |
pub const classes = .{ @import("../../classes/actors/companions/server/companion_pilot.zig"), @import("../../classes/entities/monitor/server/monitors.zig"), @import("../../classes/weapons/ballista/server/ballista.zig"), @import("../../classes/actors/companions/server/companions.zig") };
/// The class whose members travel with the player, take orders and gate autosaves and exits:
/// `find`, `member`, `isMember`, `healthyParty`, `required`, `capture`, `start`, `arrive`, `order`,
/// `handles`, `command`,
/// `allowsPickup`, `collects`, `viewHeight`, `afterTransfer`, `farthestRequired`, `summary`,
/// `Identity`.
pub const party = @import("../../classes/actors/companions/server/companions.zig");
