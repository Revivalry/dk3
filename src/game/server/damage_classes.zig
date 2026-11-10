// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: non-actor classes that refuse damage while in some state, with
//! `admitsDamage(*World, Entity) bool`. Data only; damage.zig asks them.
pub const classes = .{@import("../../classes/entities/healthtree/server/healthtrees.zig")};
pub const absorbers = .{@import("../../classes/items/antidote/server/antidote.zig")};
pub const modifiers = .{ @import("../../classes/actors/companions/server/companion_anger.zig"), @import("../../classes/entities/trigger/server/trigger.zig") };
