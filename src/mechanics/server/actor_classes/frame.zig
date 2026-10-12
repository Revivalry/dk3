// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the contexts the actor systems hand to class adapter hooks.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const std = @import("std");
const data = @import("../../../game/domain/components.zig");
const ecs = @import("../../../core/ecs/world.zig");
const abi = @import("../../../engine/abi.zig");
const rules = @import("../../domain/actors.zig");
const animation = @import("../../../core/domain/animation.zig");
const tables = @import("../../../core/domain/tables.zig");
const catalog = @import("actor_catalog");
const v = @import("../../../core/domain/vector.zig");
const Slots = @import("../../../engine/slots.zig").Slots;
pub const Actors = @import("../actors.zig").Actors;

/// One actor's simulation step. `actor`, `pose` and `body` point at the step's working copies,
/// which the actor system writes back after the hooks have run. `velocity` is the working copy
/// only from the movement phase on (`pathMove`, `takeover`, `move`, `settle`); before it, hooks
/// that change velocity write the Velocity component.
pub const Frame = struct {
    actors: *Actors,
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    router: *@import("../targets.zig").Router,
    navigation: @import("../../../core/domain/navigation.zig").Service,
    entity: ecs.Entity,
    slot: u16,
    kind: catalog.Kind,
    actor: *data.Actor,
    pose: *data.Transform,
    body: *data.Body,
    velocity: *data.Velocity,
    hurt: data.Hurt,
    definition: *const rules.Definition,
    dead: bool,
    now: i64,
    elapsed: u32,
    /// Where the actor steers by default, filled before `move`.
    threat: v.Vec3 = @splat(0),
    /// Freeze slowdown (1 when unaffected), filled before `move`.
    slow: f32 = 1,
};

/// Read-only presentation of one actor, for choosing what it shows. Pure choices need only the
/// actor and its definition; a class that reads other components uses the world.
pub const View = struct {
    kind: catalog.Kind,
    actor: *const data.Actor,
    definition: *const rules.Definition,
    now: i64,
    actors: *const Actors = undefined,
    world: *data.World = undefined,
    entity: ecs.Entity = undefined,

    /// True when nothing shared takes precedence over the class's own clip choice: no death
    /// pose, pain reaction, melee strike or script pose is showing.
    pub fn open(self: View) bool {
        const actor = self.actor;
        if (actor.mode == .dead) return actor.death_pose == null;
        return actor.reaction == null and !(catalog.sequenceAttack(self.kind) and actor.melee.active) and actor.scripted_pose == null;
    }
    /// The playback the shared mapping shows for a mode, starting at `started`.
    pub fn moded(self: View, sequence: animation.Sequence, started: i64) animation.Playback {
        const mode = self.actor.mode;
        return .{ .sequence = sequence, .started = started, .looping = mode == .idle or mode == .flee or mode == .chase };
    }
    /// When the current mode began: the idle clip's own start while idling, else the mode change.
    pub fn modeStarted(self: View) i64 {
        return if (self.actor.mode == .idle and self.actor.idle_started_ms != null) self.actor.idle_started_ms.? else self.actor.changed_ms;
    }
};

/// What a published actor shows beyond its clip: render tags, loop sounds, model visibility.
/// `playback` holds the chosen clip.
pub const Decoration = struct {
    view: View,
    playback: *animation.Playback,
    state: *abi.c.entityState_t,
};

/// A class's animations being resolved from its model's converted .anim metadata.
pub const Load = struct {
    actors: *Actors,
    id: u8,
    kind: catalog.Kind,
    classname: []const u8,
    metadata: []const u8,
    definition: *rules.Definition,
    events: []const u8,
    allocator: std.mem.Allocator,

    pub fn find(self: Load, name: []const u8) !?animation.Sequence {
        return animation.find(self.metadata, name);
    }
    /// The supplied actor_events.cfg row for one of this class's clips.
    pub fn event(self: Load, name: []const u8) !tables.Row {
        var reader = try tables.Reader.init(self.events);
        while (try reader.next()) |row| if (std.mem.eql(u8, row.field("classname") orelse "", self.classname) and std.mem.eql(u8, row.field("animation") orelse "", name)) return row;
        return error.MissingActorAttackEvent;
    }
};

/// How one attack clip and its supplied event row are loaded.
pub const AttackLoad = struct {
    /// A missing clip leaves the slot empty (`Definition.attack_present`) instead of failing.
    optional: bool = false,
    /// Playback rate multiplier for the clip (a class that advances it several frames a step).
    fps_scale: u16 = 1,
    events: enum {
        /// Sounds and strikes come from the clip's actor_events.cfg row.
        table,
        /// No row: the class times this clip itself.
        none,
        /// No row: a single strike on the clip's second frame.
        first_frame,
    } = .table,
    /// The row's second sound frame times the class's jump strike.
    jump_strike: bool = false,
};

/// A named clip a class needs beyond idle, run, death and attacks.
pub const Clip = struct {
    slot: Slot,
    name: []const u8,
    /// Used when the model lacks the clip; without one the clip is required.
    fallback: ?Slot = null,
    pub const Slot = enum { idle, run, death, ground_run, swim, walk, death_b, death_d, awakening, reload, hatch, alternate_idle, pain_c };
};

/// Shared route graphs a class steers through.
/// The authored node graphs a class navigates: `air` for fliers, `ground` (walkable and swimmable
/// nodes; hide nodes carry flag 0x1000, water nodes 0x2) for everything that wanders, takes cover
/// or swims.
pub const Routes = struct {
    air: bool = false,
    ground: bool = false,
};

/// An actor entering the world. Every component exists and the actor is bound to a slot.
pub const Spawn = struct {
    actors: *Actors,
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    entity: ecs.Entity,
    kind: catalog.Kind,
    object: data.MapObject,
    definition: *const rules.Definition,
    now: i64,

    /// The new actor's state. Fetch it again after adding components: storage may move.
    pub fn actor(self: Spawn) !*data.Actor {
        return self.world.get(self.entity, data.Actor);
    }
    pub fn position(self: Spawn) !v.Vec3 {
        return (try self.world.get(self.entity, data.Transform)).position;
    }
};

/// What the step does after a class's `takeover`.
pub const Takeover = enum {
    /// The class did not take the step.
    pass,
    /// The class stepped and published the actor itself.
    done,
    /// The class stepped; write the working copies back and publish.
    stepped,
};

/// What the ground melee mechanism asks a class at its decision points (ground_combat.zig).
pub const Admission = enum { admit, refuse, stop };

/// A hit being considered against an actor.
pub const Damage = struct {
    /// The weapon (weapon catalog id), 0 for none.
    weapon: u5,
    now: i64,
};
/// A hit that drew blood (or killed): a class may change its outcome.
pub const Hit = struct {
    world: *data.World,
    entity: ecs.Entity,
    actor: *data.Actor,
    health: *data.Health,
    amount: i32,
    options: @import("../../domain/damage.zig").Options,
    result: *@import("../../domain/damage.zig").Result,
    now: i64,
};
/// An authored trigger using an actor.
pub const Use = struct {
    actors: ?*Actors,
    world: *data.World,
    slots: *Slots,
    entity: ecs.Entity,
    actor: *data.Actor,
    now: i64,
};
