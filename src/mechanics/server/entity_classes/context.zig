// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the contexts the world-control system hands to map-entity class hooks.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const data = @import("../../../game/domain/components.zig");
const ecs = @import("../../../core/ecs/world.zig");
const abi = @import("../../../engine/abi.zig");
const rules = @import("../../domain/world_controls.zig");
const Slots = @import("../../../engine/slots.zig").Slots;
pub const Router = @import("../targets.zig").Router;
pub const Action = rules.Action;
pub const Saved = @import("../../domain/snapshot.zig").Saved;

/// An authored entity of the class entering the world.
pub const Spawn = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    entity: ecs.Entity,
    object: data.MapObject,
    now: i64,
};
/// What becomes of a spawned authored entity.
pub const Spawned = union(enum) {
    /// It becomes a world control with this state.
    control: Action,
    /// It is left as it is (not a control).
    keep,
    /// It is removed from the world.
    remove,
};
/// One world control being used, stepped or published.
pub const Control = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    router: *Router,
    entity: ecs.Entity,
    control: *data.WorldControl,
    now: i64,
    pub fn object(self: Control) !data.MapObject {
        return (try self.world.get(self.entity, data.MapObject)).*;
    }
};
/// Whether a body's contact counts for a control.
pub const Contact = struct {
    world: *data.World,
    entity: ecs.Entity,
    control: data.WorldControl,
    object: data.MapObject,
    other: ecs.Entity,
    pub fn player(self: Contact) bool {
        return (self.world.get(self.other, data.Player) catch null) != null;
    }
    pub fn companion(self: Contact) bool {
        return @import("../../../game/server/session_classes.zig").party.isMember(self.world, self.other);
    }
};
/// A bound control being projected (after spawning, restoring or moving between worlds).
pub const Publish = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    entity: ecs.Entity,
    now: i64,
};

/// How a class's authored brush is bound and projected (brushes.zig).
pub const Brush = struct {
    /// Doors, buttons, plats and trains move from their unrotated pose.
    angles: enum { authored, zeroed } = .authored,
    contents: enum { solid, none } = .solid,
    /// Never sent to clients.
    hidden: bool = false,
    /// Bound to a slot at all (editor-only portals are not).
    bound: bool = true,
};
/// The spawn passes that prepare authored entities that are not world controls.
pub const Pass = enum {
    /// Before world controls: trigger counters and limits.
    triggers,
    /// After them: hazards, walls, destructibles and target timelines.
    volumes,
};
/// An authored entity being prepared in its class's pass.
pub const Prepare = struct {
    allocator: @import("std").mem.Allocator,
    world: *data.World,
    projections: []abi.EntityProjection,
    entity: ecs.Entity,
    object: data.MapObject,
};
/// An authored entity being used by a trigger chain.
/// An authored music change (`soundtrack`).
pub const Soundtrack = struct { path: []const u8, volume: f32, changed_ms: ?i64 };
/// An authored current (`current`).
pub const Current = struct { enabled: bool, velocity: [3]f32 };
pub const Use = struct {
    router: *Router,
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    entity: ecs.Entity,
    object: data.MapObject,
    source: ?@import("../../domain/world_references.zig").Ref,
    activator: u32,
    now: i64,
};

/// What shared systems (bots, navigation, interactions, objectives, saves) may ask about an
/// authored class without naming it.
pub const Traits = struct {
    /// Activating it fires its targets.
    relays: bool = false,
    /// A switch pressed or touched by players.
    button: bool = false,
    /// Players may use it directly even when it is named as a target (buttons always may).
    player_usable: bool = false,
    /// A station (health and kin) used up close, facing it.
    station: bool = false,
    /// Fired by walking into it unless `use_only_flag` is set.
    touch_volume: bool = false,
    /// The spawnflag that makes a touch volume use-only.
    use_only_flag: u32 = 1,
    /// Fired by the first touch only, whatever its use-only flag.
    touch_once: bool = false,
    /// Counts its uses before firing.
    counter: bool = false,
    /// Shot to break; fires its targets as it breaks.
    breakable: bool = false,
    door: enum { none, sliding, rotating } = .none,
    /// A liquid volume that may drain away.
    liquid: bool = false,
    /// A team objective capture zone.
    capture_zone: bool = false,
    /// A level exit.
    level_exit: bool = false,
    /// An authored decoration prop.
    decoration: bool = false,
    /// A security monitor view.
    monitor: bool = false,
    /// A wall whose sections explode.
    exploding_wall: bool = false,
    /// A train, which may be authored without a model.
    train: bool = false,
    /// A team flag objective: team 1 or 2, or 0.
    team_flag: u2 = 0,
};
