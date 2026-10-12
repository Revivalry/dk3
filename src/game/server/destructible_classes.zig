// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: breakable brush classes (`Destructible`), asked in this order. Data only;
//! world_actions.zig and damage.zig run the hooks.
//!
//! | Hook | Meaning |
//! |---|---|
//! | `destructibleUse(*const Destructing) !bool` | true: the class handled the use |
//! | `destructibleStep(*const Destructing) !bool` | true: the class stepped the brush this frame |
//! | `destructibleRecipient(*World, Entity, i32) !Entity` | the entity that takes a hit aimed at it |
pub const classes = .{ @import("../../classes/entities/wall_breakage/server/wall_breakage.zig"), @import("../../classes/entities/explosive/server/explosives.zig") };
