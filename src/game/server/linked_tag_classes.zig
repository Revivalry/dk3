// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: classes whose projections name another entity in `otherEntityNum`, under a
//! body tag (`generic1`, declared in `linked_body_tags`) or an overlay tag (`time2`,
//! `linked_overlay_tags`). Region presentation remaps those references across worlds. Data only.
const actors = @import("actor_catalog");
pub const classes = .{ actors.gunners, actors.medusa, @import("../../classes/entities/lightning/domain/lightning.zig") };
