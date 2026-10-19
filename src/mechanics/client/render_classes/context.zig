// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: what the client hands to render-class hooks while drawing one entity.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const c = @import("../../../engine/abi.zig").c;

/// Per-frame presentation counts the client reports to probes.
pub const Counters = struct { now: i32 = 0, models: usize = 0, blended: usize = 0, entity: i32 = 0, frame: i32 = 0, oldframe: i32 = 0, backlerp: f32 = 0, ions: usize = 0, lamps: usize = 0, gibs: usize = 0, chunks: usize = 0 };

/// One entity being drawn.
pub const Draw = struct {
    entity: c.entityState_t,
    /// Every entity of the frame, for effects that join entities.
    entities: []const c.entityState_t,
    game: *c.gameState_t,
    ref: *const c.refdef_t,
    client: i32,
    now: i32,
    counters: *Counters,
};
/// One entity's model, between being set up and being added to the scene (`decorate`), or just
/// after (`overlay`).
pub const Model = struct {
    draw: Draw,
    rendered: *c.refEntity_t,
    /// A translucent model uses its bright alpha skin variant.
    bright: bool = false,
};
