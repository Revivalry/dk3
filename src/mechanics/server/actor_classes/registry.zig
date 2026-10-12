// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: maps every actor kind to its class adapter and dispatches the class hooks.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
//!
//! An adapter is a module under actor_classes/ that declares `pub const policy`, the pure class
//! policy whose `classes` list the kinds it owns. Every kind has exactly one adapter. An adapter
//! declares only the hooks its class needs; every other hook takes the default in the table
//! below, which lives once (here or in common.zig). Adding a class means adding its adapter to
//! `adapters` in classes.zig, never editing a shared system. Hook signatures are checked at compile time.
//!
//! | Phase | Hook | Default |
//! |---|---|---|
//! | Load | `attacks` (`[]const []const u8`, or `fn(Kind)` for several kinds) | no attack clips |
//! | Load | `attackLoad(Kind, usize) AttackLoad` | clip required, events from the table |
//! | Load | `clips` (`[]const Clip`, or `fn(Kind)`) | none beyond idle, run, death, attacks |
//! | Load | `routes: Routes` | no route graphs |
//! | Load | `requires: []const []const u8` | no other classes |
//! | Load | `varied_idle: bool` | true: ambient clips vary the idle |
//! | Load | `loadAnimations(Load) !void` | nothing extra |
//! | Load | `preload: bool` | false: loaded when first spawned |
//! | Load | `clip_fps: u16` | 20: the reference animates every monster and sidekick at 20 fps |
//! | Map | `Store` type, `enterMap(*Store, *Actors) !void`, `tick(*Store, *Actors, *World, *Slots) !void` | none |
//! | Spawn | `spawn(*Spawn) !void` | nothing extra |
//! | Death | `vanish_on_death: bool` | false: the body stays |
//! | Death | `own_death: bool` | false: the shared transition runs |
//! | Death | `die(*Frame) !void` | the death clip |
//! | Death | `mustGib(*const Actor) bool` | false |
//! | Step | `sense(*Frame) !void` (before the freeze check) | none |
//! | Step | `prepare(*Frame) !void` (after it) | none |
//! | Step | `scriptable(*const Actor) bool` / `follows(*const Actor) bool` | true |
//! | Step | `perceive(*Frame) !void` | path followers acquire threats (common.perceive) |
//! | Step | `preempt(*Frame) !bool` | false |
//! | Step | `path_gait: Gait`, `pathMove(*Frame, ?Vec3, f32) !void` | run; ground steering |
//! | Step | `takeover(*Frame) !Takeover` | pass |
//! | Step | `think(*Frame) !void` | none |
//! | Step | `move(*Frame) !void` / `settle(*Frame) void` | ground motion (common.move); none |
//! | Publish | `playback(View) !?Playback` / `decorate(*Decoration) !void` | shared mapping; none |
//! | Publish | `upright: bool` / `audio_follows_playback: bool` | false |
//! | Audio | `idleVaries(*const Actor) bool` | true: idle ambients may play |
//! | Audio | `frame_attack_audio: bool` | false: the class's controller sounds its attacks |
//! | Damage | `admitDamage(*const Actor, Damage) bool` / `afterDamage(*Hit) !void` | admitted; none |
//! | Damage | `immovable(*const Actor) bool` | false: blasts shove it |
//! | Use | `use(*Use) !bool`, `use_after_scripts: bool` | not handled; before scripts |
//! | Scripts | `pausesScript(*const Actor) bool` | false |
//! | Probe | `diagnose(View, *std.Io.Writer) !void` | none |
//! | Mirroring | `linkedIdentity(*const Actor) ?u32` | its projection names no other entity |
const std = @import("std");
const catalog = @import("actor_catalog");
const data = @import("../../../game/domain/components.zig");
const animation = @import("../../../core/domain/animation.zig");
const v = @import("../../../core/domain/vector.zig");
const Slots = @import("../../../engine/slots.zig").Slots;
const common = @import("common.zig");
const context = @import("frame.zig");
pub const Frame = context.Frame;
pub const View = context.View;
pub const Load = context.Load;
pub const Spawn = context.Spawn;
pub const Decoration = context.Decoration;
pub const AttackLoad = context.AttackLoad;
pub const Clip = context.Clip;
pub const Routes = context.Routes;
pub const Takeover = context.Takeover;
pub const Hit = context.Hit;
pub const Use = context.Use;
pub const Damage = context.Damage;
pub const Gait = enum { run, walk };
const Actors = context.Actors;
const Playback = animation.Playback;

const adapters = @import("../../../game/server/actor_classes/classes.zig").adapters;
const foreign = @import("../../../game/server/actor_classes/classes.zig").foreign;

const kind_count = @typeInfo(catalog.Kind).@"enum".fields.len;
/// Adapter index for each kind.
const owner: [kind_count]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var table: [kind_count]?u8 = @splat(null);
    for (adapters, 0..) |A, index| {
        check(A);
        for (A.policy.classes) |class| {
            if (table[@intFromEnum(class.kind)] != null) @compileError("actor kind adapted twice: " ++ @tagName(class.kind));
            table[@intFromEnum(class.kind)] = index;
        }
    }
    var result: [kind_count]u8 = undefined;
    for (table, 0..) |entry, index| result[index] = entry orelse @compileError("actor kind without a class adapter: " ++ @tagName(@as(catalog.Kind, @enumFromInt(index))));
    break :blk result;
};

/// Hook names an adapter may declare, with their signatures. A misspelt hook would silently take
/// its default, so every public function of an adapter must be one of these or be listed in the
/// adapter's `helpers`.
const hooks = .{
    .{ "attackLoad", &.{ catalog.Kind, usize }, AttackLoad },
    .{ "loadAnimations", &.{Load}, void },
    .{ "spawn", &.{*Spawn}, void },
    .{ "die", &.{*Frame}, void },
    .{ "mustGib", &.{*const data.Actor}, bool },
    .{ "sense", &.{*Frame}, void },
    .{ "prepare", &.{*Frame}, void },
    .{ "scriptable", &.{*const data.Actor}, bool },
    .{ "follows", &.{*const data.Actor}, bool },
    .{ "perceive", &.{*Frame}, void },
    .{ "preempt", &.{*Frame}, bool },
    .{ "pathMove", &.{ *Frame, ?v.Vec3, f32 }, void },
    .{ "takeover", &.{*Frame}, Takeover },
    .{ "think", &.{*Frame}, void },
    .{ "move", &.{*Frame}, void },
    .{ "settle", &.{*Frame}, void },
    .{ "playback", &.{View}, ?Playback },
    .{ "decorate", &.{*Decoration}, void },
    .{ "diagnose", &.{ View, *std.Io.Writer }, void },
    .{ "attacks", &.{catalog.Kind}, []const []const u8 },
    .{ "idleVaries", &.{*const data.Actor}, bool },
    .{ "admitDamage", &.{ *const data.Actor, context.Damage }, bool },
    .{ "afterDamage", &.{*context.Hit}, void },
    .{ "immovable", &.{*const data.Actor}, bool },
    .{ "use", &.{*context.Use}, bool },
    .{ "pausesScript", &.{*const data.Actor}, bool },
    .{ "linkedIdentity", &.{*const data.Actor}, ?u32 },
    .{ "clips", &.{catalog.Kind}, []const Clip },
    .{ "validateSavedAttack", &.{ *const @import("../../domain/snapshot.zig").Saved, data.ActorAttack }, void },
};

fn check(comptime A: type) void {
    if (!@hasDecl(A, "policy")) @compileError(@typeName(A) ++ ": an actor class adapter declares its policy");
    if (@hasDecl(A, "Store")) {
        if (@hasDecl(A, "enterMap")) expect(A, "enterMap", &.{ *A.Store, *Actors }, void);
        if (@hasDecl(A, "tick")) expect(A, "tick", &.{ *A.Store, *Actors, *data.World, *Slots }, void);
    }
    const helpers: []const []const u8 = if (@hasDecl(A, "helpers")) &A.helpers else &.{};
    for (@typeInfo(A).@"struct".decls) |decl| {
        if (@typeInfo(@TypeOf(@field(A, decl.name))) != .@"fn") continue;
        if (listed(decl.name, &.{ "enterMap", "tick" }) or listed(decl.name, helpers)) continue;
        const hook = for (hooks) |entry| {
            if (std.mem.eql(u8, entry[0], decl.name)) break entry;
        } else @compileError(@typeName(A) ++ ": " ++ decl.name ++ " is not an actor class hook; list it in `helpers` if it is an adapter helper");
        expect(A, hook[0], hook[1], hook[2]);
    }
}
fn listed(comptime name: []const u8, comptime names: []const []const u8) bool {
    for (names) |entry| if (std.mem.eql(u8, entry, name)) return true;
    return false;
}
/// Compile-time check of a hook's parameters and (error-union payload) result.
fn expect(comptime A: type, comptime hook: []const u8, comptime params: []const type, comptime result: type) void {
    const info = @typeInfo(@TypeOf(@field(A, hook))).@"fn";
    const returned = info.return_type.?;
    const payload = switch (@typeInfo(returned)) {
        .error_union => |union_info| union_info.payload,
        else => returned,
    };
    var matches = info.params.len == params.len and payload == result;
    if (matches) for (info.params, params) |param, wanted| {
        matches = matches and param.type == wanted;
    };
    if (!matches) @compileError(@typeName(A) ++ ": hook " ++ hook ++ " has the wrong signature");
}

fn adapterOf(kind: catalog.Kind) u8 {
    return owner[@intFromEnum(kind)];
}
/// A list declaration that is an array, a slice, or a function of the kind (for adapters of
/// several kinds).
fn listOf(comptime A: type, comptime name: []const u8, comptime Element: type, kind: catalog.Kind) []const Element {
    const declared = @field(A, name);
    return switch (@typeInfo(@TypeOf(declared))) {
        .@"fn" => declared(kind),
        .array => &declared,
        else => declared,
    };
}

// Load ------------------------------------------------------------------------------------------

pub fn attacks(kind: catalog.Kind) []const []const u8 {
    switch (adapterOf(kind)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "attacks")) listOf(adapters[i], "attacks", []const u8, kind) else &.{},
        else => unreachable,
    }
}
pub fn attackLoad(kind: catalog.Kind, attack: usize) AttackLoad {
    switch (adapterOf(kind)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "attackLoad")) adapters[i].attackLoad(kind, attack) else .{},
        else => unreachable,
    }
}
pub fn clips(kind: catalog.Kind) []const Clip {
    switch (adapterOf(kind)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "clips")) listOf(adapters[i], "clips", Clip, kind) else &.{},
        else => unreachable,
    }
}
pub fn routes(kind: catalog.Kind) Routes {
    return value(kind, "routes", Routes{});
}
pub fn requires(kind: catalog.Kind) []const []const u8 {
    switch (adapterOf(kind)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "requires")) listOf(adapters[i], "requires", []const u8, kind) else &.{},
        else => unreachable,
    }
}
pub fn variedIdle(kind: catalog.Kind) bool {
    return value(kind, "varied_idle", true);
}
pub fn preload(kind: catalog.Kind) bool {
    return value(kind, "preload", false);
}
/// The rate the class plays its clips at; the converted model metadata carries the engine's 10.
pub fn clipFps(kind: catalog.Kind) u16 {
    return value(kind, "clip_fps", @as(u16, 20));
}
pub fn loadAnimations(kind: catalog.Kind, load: Load) !void {
    return dispatch(kind, "loadAnimations", .{load}, {});
}

// Map -------------------------------------------------------------------------------------------

/// Per-map class state: one field per adapter that declares a `Store`, owned by the actor system.
pub const Stores = blk: {
    var count: usize = 0;
    for (adapters) |A| {
        if (@hasDecl(A, "Store")) count += 1;
    }
    var names: [count][]const u8 = undefined;
    var types: [count]type = undefined;
    var attributes: [count]std.builtin.Type.StructField.Attributes = undefined;
    var at: usize = 0;
    for (adapters) |A| if (@hasDecl(A, "Store")) {
        names[at] = @typeName(A);
        types[at] = A.Store;
        attributes[at] = .{ .default_value_ptr = &A.Store{} };
        at += 1;
    };
    break :blk @Struct(.auto, null, &names, &types, &attributes);
};
/// The adapter's own store.
pub fn store(comptime A: type, stores: anytype) switch (@TypeOf(stores)) {
    *Stores => *A.Store,
    else => *const A.Store,
} {
    return &@field(stores, @typeName(A));
}
/// A map was entered or a save of it restored.
pub fn enterMap(actors: *Actors) !void {
    inline for (adapters) |A| if (@hasDecl(A, "enterMap")) try A.enterMap(store(A, &actors.stores), actors);
}
/// Once per actor step, before the actors.
pub fn tick(actors: *Actors, world: *data.World, slots: *Slots) !void {
    inline for (adapters) |A| if (@hasDecl(A, "tick")) try A.tick(store(A, &actors.stores), actors, world, slots);
}

// Spawn -----------------------------------------------------------------------------------------

pub fn spawn(kind: catalog.Kind, spawning: *Spawn) !void {
    return dispatch(kind, "spawn", .{spawning}, {});
}
/// The spawner of a monster class outside the catalog, or null.
pub fn foreignSpawner(classname: []const u8) ?*const fn (*Actors, *data.World, *Slots, []@import("../../../engine/abi.zig").EntityProjection, @import("../../../core/ecs/world.zig").Entity, i64) anyerror!void {
    inline for (foreign) |F| if (std.mem.eql(u8, F.classname, classname)) return if (@hasDecl(F, "spawnForeign")) &F.spawnForeign else null;
    return null;
}
/// True for a monster class that another system spawns.
pub fn foreignClass(classname: []const u8) bool {
    inline for (foreign) |F| if (std.mem.eql(u8, F.classname, classname)) return true;
    return false;
}

// Death -----------------------------------------------------------------------------------------

pub fn vanishesOnDeath(kind: catalog.Kind) bool {
    return value(kind, "vanish_on_death", false);
}
pub fn ownsDeath(kind: catalog.Kind) bool {
    return value(kind, "own_death", false);
}
pub fn die(kind: catalog.Kind, frame: *Frame) !void {
    return dispatch(kind, "die", .{frame}, {});
}
pub fn mustGib(kind: catalog.Kind, actor: *const data.Actor) bool {
    return dispatch(kind, "mustGib", .{actor}, false);
}

// Step ------------------------------------------------------------------------------------------

pub fn sense(kind: catalog.Kind, frame: *Frame) !void {
    return dispatch(kind, "sense", .{frame}, {});
}
pub fn prepare(kind: catalog.Kind, frame: *Frame) !void {
    return dispatch(kind, "prepare", .{frame}, {});
}
pub fn scriptable(kind: catalog.Kind, actor: *const data.Actor) bool {
    return dispatch(kind, "scriptable", .{actor}, true);
}
pub fn follows(kind: catalog.Kind, actor: *const data.Actor) bool {
    return dispatch(kind, "follows", .{actor}, true);
}
pub fn perceive(kind: catalog.Kind, frame: *Frame) !void {
    switch (adapterOf(kind)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "perceive")) adapters[i].perceive(frame) else common.perceive(frame),
        else => unreachable,
    }
}
pub fn preempt(kind: catalog.Kind, frame: *Frame) !bool {
    return dispatch(kind, "preempt", .{frame}, false);
}
pub fn pathGait(kind: catalog.Kind) Gait {
    return value(kind, "path_gait", Gait.run);
}
pub fn pathMove(kind: catalog.Kind, frame: *Frame, point: ?v.Vec3, speed: f32) !void {
    switch (adapterOf(kind)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "pathMove")) adapters[i].pathMove(frame, point, speed) else common.groundPath(frame, point, speed),
        else => unreachable,
    }
}
pub fn takeover(kind: catalog.Kind, frame: *Frame) !Takeover {
    return dispatch(kind, "takeover", .{frame}, Takeover.pass);
}
pub fn think(kind: catalog.Kind, frame: *Frame) !void {
    return dispatch(kind, "think", .{frame}, {});
}
pub fn move(kind: catalog.Kind, frame: *Frame) !void {
    switch (adapterOf(kind)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "move")) adapters[i].move(frame) else common.move(frame),
        else => unreachable,
    }
}
pub fn settle(kind: catalog.Kind, frame: *Frame) void {
    switch (adapterOf(kind)) {
        inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], "settle")) adapters[i].settle(frame),
        else => unreachable,
    }
}

// Publish ---------------------------------------------------------------------------------------

pub fn playback(kind: catalog.Kind, view: View) !?Playback {
    return dispatch(kind, "playback", .{view}, @as(?Playback, null));
}
pub fn decorate(kind: catalog.Kind, decoration: *Decoration) !void {
    return dispatch(kind, "decorate", .{decoration}, {});
}
pub fn upright(kind: catalog.Kind) bool {
    return value(kind, "upright", false);
}
pub fn audioFollowsPlayback(kind: catalog.Kind) bool {
    return value(kind, "audio_follows_playback", false);
}
pub fn diagnose(kind: catalog.Kind, view: View, writer: *std.Io.Writer) !void {
    return dispatch(kind, "diagnose", .{ view, writer }, {});
}

// Audio ----------------------------------------------------------------------------------------

pub fn idleVaries(kind: catalog.Kind, actor: *const data.Actor) bool {
    return dispatch(kind, "idleVaries", .{actor}, true);
}
pub fn frameAttackAudio(kind: catalog.Kind) bool {
    return value(kind, "frame_attack_audio", false);
}

// Damage ---------------------------------------------------------------------------------------

pub fn admitDamage(kind: catalog.Kind, actor: *const data.Actor, damage: context.Damage) bool {
    return dispatch(kind, "admitDamage", .{ actor, damage }, true);
}
pub fn afterDamage(kind: catalog.Kind, hit: *context.Hit) !void {
    return dispatch(kind, "afterDamage", .{hit}, {});
}
pub fn immovable(kind: catalog.Kind, actor: *const data.Actor) bool {
    return dispatch(kind, "immovable", .{actor}, false);
}

// Use and scripts ------------------------------------------------------------------------------

pub fn useAfterScripts(kind: catalog.Kind) bool {
    return value(kind, "use_after_scripts", false);
}
/// The class's response to an authored use; true when it handled it.
pub fn use(kind: catalog.Kind, using: *context.Use) !bool {
    return dispatch(kind, "use", .{using}, false);
}
/// The entity an actor's projection names (`otherEntityNum`), for resident-world mirroring.
pub fn linkedIdentity(kind: catalog.Kind, actor: *const data.Actor) ?u32 {
    return dispatch(kind, "linkedIdentity", .{actor}, @as(?u32, null));
}
pub fn pausesScript(kind: catalog.Kind, actor: *const data.Actor) bool {
    return dispatch(kind, "pausesScript", .{actor}, false);
}

// Save -----------------------------------------------------------------------------------------

/// A restored attack's relations to other entities; each adapter checks the payloads it launches
/// (`validateSavedAttack`). The payload's own bounds are checked by domain/actor_attack.zig.
pub fn validateSavedAttack(saved: *const @import("../../domain/snapshot.zig").Saved, attack: data.ActorAttack) !void {
    inline for (adapters) |A| if (@hasDecl(A, "validateSavedAttack")) try A.validateSavedAttack(saved, attack);
}

/// Calls `hook` on the kind's adapter, or returns `fallback` when it has none.
inline fn dispatch(kind: catalog.Kind, comptime hook: []const u8, args: anytype, fallback: anytype) ReturnOf(hook, @TypeOf(fallback)) {
    switch (adapterOf(kind)) {
        inline 0...adapters.len - 1 => |i| {
            const A = adapters[i];
            return if (@hasDecl(A, hook)) @call(.auto, @field(A, hook), args) else fallback;
        },
        else => unreachable,
    }
}
/// Hooks that can fail return `anyerror!T`; the others return the fallback's type.
fn ReturnOf(comptime hook: []const u8, comptime T: type) type {
    return if (listed(hook, &.{ "mustGib", "scriptable", "follows", "attackLoad", "settle", "idleVaries", "admitDamage", "immovable", "pausesScript", "linkedIdentity" })) T else anyerror!T;
}
/// A declared value, or `fallback` when the adapter leaves it out.
fn value(kind: catalog.Kind, comptime name: []const u8, fallback: anytype) @TypeOf(fallback) {
    switch (adapterOf(kind)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], name)) @field(adapters[i], name) else fallback,
        else => unreachable,
    }
}

test "every kind has one adapter and every adapter owns only kinds its policy declares" {
    inline for (adapters, 0..) |A, i| for (A.policy.classes) |class| {
        try std.testing.expectEqual(@as(u8, i), owner[@intFromEnum(class.kind)]);
    };
}
