// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Actor lifecycle and perception. Class combat and shared locomotion are separate systems.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const rules = @import("../domain/actors.zig");
const catalog = @import("actor_catalog");
const classes = @import("actor_classes/registry.zig");
const common = @import("actor_classes/common.zig");
const Playback = @import("../../core/domain/animation.zig").Playback;
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const v = @import("../../core/domain/vector.zig");
const c = abi.c;
/// Authored monster classnames start with this; each needs an actor class.
const monster_prefix = "monster_";
pub const Actors = struct {
    table: rules.Table = .{},
    weapons: @import("../domain/weapons.zig").Table = .{},
    episode: u8 = 1,
    /// The `g_spSkill` the table and the living actors are scaled for (`followDifficulty`).
    skill: i32 = 0,
    allocator: std.mem.Allocator = undefined,
    event_bytes: []const u8 = "",
    animations: [catalog.entries.len]bool = @splat(false),
    metadata: [catalog.entries.len][]const u8 = @splat(""),
    air_routes: @import("air_routes.zig").Routes = .{},
    air_ready: bool = false,
    ground_routes: @import("air_routes.zig").Routes = .{},
    ground_ready: bool = false,
    /// Per-map state of the classes that declare a `Store`.
    stores: classes.Stores = .{},
    pub fn spawn(self: *Actors, allocator: std.mem.Allocator, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, now: i64, episode: u8) !void {
        self.episode = episode;
        self.allocator = allocator;
        const bytes = try @import("../../engine/files.zig").read(.server, &engine.gateway, allocator, "dk3/tables/aidata.cfg", 4 * 1024 * 1024);
        self.skill = engine.integer("g_spSkill");
        self.table = try rules.Table.parse(bytes, rules.difficultyFactor(self.skill));
        self.event_bytes = try @import("../../engine/files.zig").read(.server, &engine.gateway, allocator, "dk3/tables/actor_events.cfg", 4 * 1024 * 1024);
        var candidates: [ecs.max_entities]ecs.Entity = undefined;
        var count: usize = 0;
        {
            var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Transform }), 0, 0);
            defer query.deinit();
            while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, object| {
                if (std.mem.startsWith(u8, object.classname, monster_prefix) and !classes.foreignClass(object.classname) and catalog.find(object.classname) == null) {
                    var message: [160]u8 = undefined;
                    engine.print(try std.fmt.bufPrintZ(&message, "dk3 actor: missing native controller for {s}\n", .{object.classname}));
                    return error.UnknownAuthoredActorClass;
                }
                if (catalog.find(object.classname) != null) {
                    candidates[count] = entity;
                    count += 1;
                }
            };
        }
        for (candidates[0..count]) |entity| try self.spawnOne(world, slots, projections, entity, now);
        try self.enterMap();
    }
    /// A map was entered or a save of it restored. Classes reset their per-map state, and classes
    /// that can arrive without being spawned here (`preload`, such as party members landing on a
    /// submap) have their models and metadata admitted before the destination's resource table
    /// is published.
    pub fn enterMap(self: *Actors) !void {
        try classes.enterMap(self);
        for (catalog.entries, 0..) |entry, id| if (classes.preload(entry.kind)) {
            try self.ensure(@intCast(id));
            _ = try @import("resources.zig").model(self.table.definitions[id].model);
        };
    }
    /// Resolves a class's animations, sounds and routes from its model metadata, once.
    pub fn ensure(self: *Actors, id: u8) !void {
        if (self.animations[id]) return;
        const definition = &self.table.definitions[id];
        if (!definition.loaded) return error.MissingActorDefinition;
        var path: [80]u8 = undefined;
        const name = try std.fmt.bufPrintZ(&path, "{s}.anim", .{definition.model});
        const converted = try @import("../../engine/files.zig").read(.server, &engine.gateway, self.allocator, name, 1 << 20);
        defer self.allocator.free(converted);
        const policy = catalog.entries[id];
        const metadata = try @import("../../core/domain/animation.zig").retime(self.allocator, converted, classes.clipFps(policy.kind));
        self.metadata[id] = metadata;
        const load: classes.Load = .{ .actors = self, .id = id, .kind = policy.kind, .classname = policy.classname, .metadata = metadata, .definition = definition, .events = self.event_bytes, .allocator = self.allocator };
        definition.idle = try load.find(policy.idle) orelse return error.MissingActorIdle;
        definition.run = try load.find(policy.run) orelse return error.MissingActorRun;
        definition.death = try load.find(policy.death) orelse return error.MissingActorDeath;
        for (classes.attacks(policy.kind), 0..) |attack, i| try loadAttack(load, attack, i);
        if (catalog.painAnimation(policy.kind)) {
            definition.pain[0] = try load.find("hita");
            definition.pain[1] = try load.find("hitb");
        }
        for (classes.clips(policy.kind)) |clip| try loadClip(load, clip);
        try classes.loadAnimations(policy.kind, load);
        const routes = classes.routes(policy.kind);
        if (routes.air and !self.air_ready) {
            try self.air_routes.init(self.allocator);
            self.air_ready = true;
        }
        if (routes.ground and !self.ground_ready) {
            try self.ground_routes.initGround(self.allocator);
            self.ground_ready = true;
        }
        definition.audio = try @import("../domain/actor_audio.zig").parse(self.allocator, self.event_bytes, metadata, policy.classname);
        if (std.mem.eql(u8, policy.idle, "amba") and classes.variedIdle(policy.kind)) definition.idle_choices = try @import("../domain/actor_audio.zig").idleChoices(self.allocator, metadata, definition.audio);
        self.animations[id] = true;
        for (classes.requires(policy.kind)) |classname| try self.ensure(catalog.find(classname) orelse return error.UnknownActorClass);
    }
    /// One attack clip and the strikes and sounds of its supplied event row.
    fn loadAttack(load: classes.Load, attack: []const u8, i: usize) !void {
        const definition = load.definition;
        const rule = classes.attackLoad(load.kind, i);
        definition.attacks[i] = try load.find(attack) orelse {
            if (rule.optional) {
                definition.attack_present[i] = false;
                return;
            }
            var text: [160]u8 = undefined;
            engine.print(std.fmt.bufPrintZ(&text, "dk3 actor: {s} has no attack sequence {s} in its model\n", .{ load.classname, attack }) catch "");
            return error.MissingActorAttack;
        };
        definition.attacks[i].fps *= rule.fps_scale;
        switch (rule.events) {
            .none => return,
            .first_frame => {
                definition.strikes[i] = 2;
                return;
            },
            .table => {},
        }
        const row = try load.event(attack);
        const frames: f32 = @floatFromInt(definition.attacks[i].last - definition.attacks[i].first);
        const fps: f32 = @floatFromInt(definition.attacks[i].fps);
        definition.attack_sounds[i] = row.field("sound1") orelse "";
        definition.second_attack_sounds[i] = row.field("sound2") orelse "";
        definition.attack_sound_enabled[i] = try row.number("frame1_enabled", 1) != 0;
        if (try row.number("sound2_alternative", 0) != 0) definition.attack_alternative[i] = std.math.clamp(try row.number("sound2_chance", 0) * 0.01, 0, 1);
        // A clip raises a frame's event as it advances past that frame: frame k's event comes when
        // the clip reaches frame k + 1. Strikes are stored as that raising frame.
        if (definition.second_attack_sounds[i].len != 0 and try row.number("frame2_enabled", 1) != 0) definition.second_sound_ms[i] = @intFromFloat((try row.number("frame2", 0) + 1) * 1000 / fps);
        if (rule.jump_strike and try row.number("frame2_enabled", 0) != 0) definition.jump_strike_ms = @intFromFloat((try row.number("frame2", 0) + 1) * 1000 / fps);
        const strike = try row.number("strike1", 0);
        if (strike < 0 or strike > frames) return error.InvalidActorStrike;
        definition.strikes[i] = @as(u16, @intFromFloat(strike)) + 1;
        const second = try row.number("strike2", 0);
        if (second < 0 or second > frames) return error.InvalidActorStrike;
        // An empty second-attack cell never strikes (the table writes it as 0; none authors 0).
        definition.second_strikes[i] = if (second > 0) @as(u16, @intFromFloat(second)) + 1 else null;
        definition.attack_sound_ms[i] = @intFromFloat((try row.number("frame1", 0) + 1) * 1000 / fps);
        // Out-of-clip events never occur. Keep the timing for class-owned
        // launch rules, but do not turn an unreachable sound into a late cue.
        if (try row.number("frame1", 1) > frames) definition.attack_sound_enabled[i] = false;
        if (try row.number("frame2", 1) > frames) definition.second_sound_ms[i] = null;
    }
    fn loadClip(load: classes.Load, clip: classes.Clip) !void {
        const definition = load.definition;
        const found = try load.find(clip.name) orelse if (clip.fallback) |fallback| switch (fallback) {
            inline else => |slot| fallback: {
                const value = @field(definition, @tagName(slot));
                break :fallback if (@typeInfo(@TypeOf(value)) == .optional) value orelse return error.MissingActorClip else value;
            },
        } else {
            var text: [160]u8 = undefined;
            engine.print(std.fmt.bufPrintZ(&text, "dk3 actor: {s} has no {s} sequence in its model\n", .{ load.classname, clip.name }) catch "");
            return error.MissingActorClip;
        };
        switch (clip.slot) {
            inline else => |slot| @field(definition, @tagName(slot)) = found,
        }
    }
    pub fn findSequence(self: *Actors, id: u8, name: []const u8) !?@import("../../core/domain/animation.zig").Sequence {
        try self.ensure(id);
        return @import("../../core/domain/animation.zig").find(self.metadata[id], name);
    }
    fn spawnOne(self: *Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, entity: ecs.Entity, now: i64) !void {
        const object = (try world.get(entity, data.MapObject)).*;
        if (classes.foreignSpawner(object.classname)) |spawnForeign| return spawnForeign(self, world, slots, projections, entity, now);
        const id = catalog.find(object.classname) orelse return error.UnknownActorClass;
        try self.ensure(id);
        const definition = &self.table.definitions[id];
        const health = try @import("properties.zig").number(object, "health", @floatFromInt(definition.health));
        if (health <= 0) return error.InvalidActorHealth;
        try world.put(entity, data.Actor{ .unique = @import("properties.zig").text(object, "uniqueid") orelse "", .ignore_player = object.flags & catalog.spawnflags.ignore_player != 0, .path = if (object.flags & catalog.spawnflags.path_follow != 0 and object.target.len > 0) if (@import("scripts.zig").named(world, object.target)) |point| try world.persistentId(point) else 0 else 0, .definition = id, .changed_ms = now, .think_ms = now });
        try world.put(entity, data.Hurt{});
        try world.put(entity, data.Ailments{});
        try world.put(entity, data.Health{ .current = @intFromFloat(health), .maximum = @intFromFloat(health) });
        try world.put(entity, data.Velocity{});
        try world.put(entity, data.Random{ .state = try world.persistentId(entity) });
        try world.put(entity, data.Body{ .mins = definition.mins, .maxs = definition.maxs, .contents = c.CONTENTS_BODY, .collision_mask = c.MASK_PLAYERSOLID, .mass = definition.mass });
        const model = try @import("resources.zig").model(definition.model);
        const slot = try slots.acquire(entity, null);
        try world.put(entity, data.Binding{ .slot = slot, .model = model });
        projections[slot] = std.mem.zeroes(abi.EntityProjection);
        var spawning: classes.Spawn = .{ .actors = self, .world = world, .slots = slots, .projections = projections, .entity = entity, .kind = catalog.entries[id].kind, .object = object, .definition = definition, .now = now };
        try classes.spawn(catalog.entries[id].kind, &spawning);
        try self.publish(world, entity, projections, now);
    }
    pub fn spawnDynamic(self: *Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, classname: []const u8, position: v.Vec3, angles: v.Vec3, now: i64) !ecs.Entity {
        return self.spawnAuthored(world, slots, projections, .{ .classname = classname }, .{ .position = position, .angles = angles }, now);
    }
    pub fn spawnAuthored(self: *Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, object: data.MapObject, pose: data.Transform, now: i64) !ecs.Entity {
        const entity = try world.create(null, .{ object, pose });
        errdefer world.destroy(entity) catch unreachable;
        try self.spawnOne(world, slots, projections, entity, now);
        return entity;
    }
    /// The clip an actor shows: the shared mode mapping, then its class's choice.
    pub fn playbackOf(self: *const Actors, world: *data.World, entity: ecs.Entity, now: i64) !Playback {
        const actor = try world.get(entity, data.Actor);
        const definition = &self.table.definitions[actor.definition];
        const kind = catalog.entries[actor.definition].kind;
        const view = self.viewOf(world, entity, actor, now);
        const alive = actor.mode != .dead;
        const striking = catalog.sequenceAttack(kind) and actor.melee.active;
        const sequence = if (!alive and actor.death_pose != null) actor.death_pose.? else if (alive and actor.reaction != null) actor.reaction.? else if (striking) definition.attacks[actor.melee.pose] else if (alive and actor.scripted_pose != null) actor.scripted_pose.? else switch (actor.mode) {
            .idle => actor.idle_pose orelse definition.idle,
            .flee, .chase => if (actor.path != 0 and actor.moving_pose != null) actor.moving_pose.? else definition.run,
            .attack => definition.attacks[if (catalog.sequenceAttack(kind)) actor.melee.pose else 0],
            .reload => definition.reload,
            .dead => definition.death,
        };
        const started = if (alive and actor.reaction != null) actor.reaction_started_ms else if (striking) actor.melee.started_ms else if (alive and actor.scripted_pose != null) actor.scripted_ms else if (catalog.sequenceAttack(kind) and actor.mode == .attack) actor.melee.started_ms else view.modeStarted();
        const shared: Playback = .{ .sequence = sequence, .started = started, .looping = actor.reaction == null and !actor.melee.active and (actor.mode == .idle or actor.mode == .flee or actor.mode == .chase) };
        return try classes.playback(kind, view) orelse shared;
    }
    fn viewOf(self: *const Actors, world: *data.World, entity: ecs.Entity, actor: *const data.Actor, now: i64) classes.View {
        return .{ .kind = catalog.entries[actor.definition].kind, .actor = actor, .definition = &self.table.definitions[actor.definition], .now = now, .actors = self, .world = world, .entity = entity };
    }
    pub fn publish(self: *const Actors, world: *data.World, entity: ecs.Entity, projections: []abi.EntityProjection, now: i64) !void {
        const actor = (try world.get(entity, data.Actor)).*;
        const definition = &self.table.definitions[actor.definition];
        const pose = (try world.get(entity, data.Transform)).*;
        const body = (try world.get(entity, data.Body)).*;
        const binding = (try world.get(entity, data.Binding)).*;
        const kind = catalog.entries[actor.definition].kind;
        const projection = &projections[binding.slot];
        projection.state.number = binding.slot;
        projection.state.eType = c.ET_GENERAL;
        projection.state.eFlags = (projection.state.eFlags & ~@as(i32, c.EF_DEAD)) | (if (actor.mode == .dead) @as(i32, c.EF_DEAD) else 0);
        projection.state.modelindex = if (actor.gibbed) 0 else binding.model;
        projection.state.angles2 = definition.scale;
        // The pitch toward the enemy it is engaging: skeletal models bend their spine to it.
        projection.state.angles = .{ aimPitch(actor, pose, body, now), 0, 0 };
        projection.state.generic1 = if (world.get(entity, data.Ailments) catch null) |ailment| @intFromFloat(ailment.freeze_level * 1000) else 0;
        projection.state.groundEntityNum = actor.ground_entity;
        projection.state.time2 = 0;
        var playback = try self.playbackOf(world, entity, now);
        var decoration: classes.Decoration = .{ .view = self.viewOf(world, entity, &actor, now), .playback = &playback, .state = &projection.state };
        try classes.decorate(kind, &decoration);
        if (world.get(entity, data.Ailments) catch null) |status| {
            if (status.stone) projection.state.generic1 = @import("../domain/ailments.zig").stone_tag;
            if (status.petrified_frame) |frame| playback = .{ .sequence = .{ .first = frame, .last = frame }, .started = now };
        }
        @import("../../engine/animation.zig").publish(&projection.state, playback, now);
        projection.state.pos = @import("../../engine/trajectory.zig").interpolated(pose.position);
        // An upright class's pitch is where it aims, not how it stands: like a player, its body
        // is drawn turned by yaw alone (aiming up at a ledge must not tip it back off its feet).
        const drawn: v.Vec3 = if (classes.upright(kind)) .{ 0, pose.angles[1], 0 } else pose.angles;
        projection.state.apos = @import("../../engine/trajectory.zig").interpolated(drawn);
        projection.shared.currentOrigin = pose.position;
        projection.shared.currentAngles = pose.angles;
        projection.shared.mins = body.mins;
        projection.shared.maxs = body.maxs;
        projection.shared.contents = @bitCast(body.contents);
        projection.shared.ownerNum = c.ENTITYNUM_NONE;
        engine.link(projection);
    }
    pub fn visible(from: v.Vec3, to: v.Vec3, skip: u16, target: u16) !bool {
        const hit = try engine.collisionService().trace(.{ .start = from, .end = to, .mins = @splat(0), .maxs = @splat(0), .slot = skip, .mask = c.MASK_SOLID });
        return hit.fraction == 1 or hit.entity == target;
    }
    /// Credits the kill and fires the actor's authored death outputs, once.
    pub fn dispatchDeath(self: *Actors, frame: *classes.Frame) !void {
        frame.actor.death_dispatched = true;
        (try frame.world.get(frame.entity, data.Actor)).death_dispatched = true;
        try @import("progression.zig").kill(frame.world, frame.hurt, frame.definition.health, self.episode, &self.weapons);
        try @import("actor_spawns.zig").death(self, frame.world, frame.slots, frame.projections, frame.router, frame.entity, frame.now);
    }
    pub fn step(self: *Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *@import("targets.zig").Router, navigation: @import("../../core/domain/navigation.zig").Service, now: i64, elapsed: u32) !void {
        try classes.tick(self, world, slots);
        for (slots.occupants) |occupant| {
            const entity = occupant orelse continue;
            if (!world.alive(entity)) continue;
            const actor_state = world.get(entity, data.Actor) catch continue;
            if (actor_state.stepped_ms == now) continue;
            actor_state.stepped_ms = now;
            var collision = try @import("actor_collision.zig").Frame.init(world, entity);
            collision.enter();
            defer collision.leave();
            const before = actor_state.*;
            try self.stepOne(world, slots, projections, router, navigation, entity, now, elapsed);
            try collision.finish(now);
            try self.alert(world, entity, before, now);
        }
    }
    /// Passes a monster's enemy to the monsters around it (`actor_alert.zig`) when it takes a new
    /// enemy, keeps one in sight while chasing, or dies.
    fn alert(self: *Actors, world: *data.World, entity: ecs.Entity, before: data.Actor, now: i64) !void {
        if (!world.alive(entity)) return;
        const alerts = @import("actor_alert.zig");
        if (!alerts.monster(world, entity)) return;
        const actor = (world.get(entity, data.Actor) catch return).*;
        const definition = self.table.definitions[actor.definition];
        const position = (try world.get(entity, data.Transform)).position;
        const reach = try alerts.radius(world, entity, definition);
        if (actor.mode == .dead) {
            if (before.mode != .dead) try alerts.enemy(world, entity, position, reach, (try world.get(entity, data.Hurt)).source, now);
            return;
        }
        if (actor.threat == 0 or actor.ignore_player) return;
        if (actor.threat != before.threat) {
            try alerts.enemy(world, entity, position, reach, actor.threat, now);
            try alerts.nearby(world, entity, position, &self.table.definitions, actor.threat, now);
        } else if (actor.mode == .chase and actor.threat_seen_ms == now and alerts.chaseCall(now)) try alerts.enemy(world, entity, position, reach, actor.threat, now);
    }
    fn stepOne(self: *Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, router: *@import("targets.zig").Router, navigation: @import("../../core/domain/navigation.zig").Service, entity: ecs.Entity, now: i64, elapsed: u32) !void {
        var actor = (world.get(entity, data.Actor) catch return).*;
        const binding = (try world.get(entity, data.Binding)).*;
        var pose = (try world.get(entity, data.Transform)).*;
        var body = (try world.get(entity, data.Body)).*;
        var velocity = (try world.get(entity, data.Velocity)).*;
        const hurt = (try world.get(entity, data.Hurt)).*;
        const dead = (try world.get(entity, data.Health)).current <= 0;
        const petrified = if (world.get(entity, data.Ailments) catch null) |status| status.petrified_frame != null else false;
        const kind = catalog.entries[actor.definition].kind;
        const definition = &self.table.definitions[actor.definition];
        var frame: classes.Frame = .{ .actors = self, .world = world, .slots = slots, .projections = projections, .router = router, .navigation = navigation, .entity = entity, .slot = binding.slot, .kind = kind, .actor = &actor, .pose = &pose, .body = &body, .velocity = &velocity, .hurt = hurt, .definition = definition, .dead = dead, .now = now, .elapsed = elapsed };
        if (dead and actor.gibbed and actor.death_dispatched and now >= actor.changed_ms + 100) {
            try retirement(world, entity, "gibbed", now);
            try @import("weapon_entities.zig").remove(world, slots, projections, entity);
            return;
        }
        if (dead and !actor.gibbed and !petrified and engine.integer("sv_violence") == 0 and engine.integer("gib_enable") != 0) {
            const material = catalog.traitsOf(kind).remains;
            const limits: @TypeOf(material).Thresholds = .{ .hit = engine.number("gib_damage", 1), .overkill = engine.number("gib_overkill", 1) };
            if (material.eligible((try world.get(entity, data.MapObject)).flags, hurt.amount, (try world.get(entity, data.Health)).current, @floatFromInt(definition.health), limits) or classes.mustGib(kind, &actor)) {
                try @import("actor_gibs.zig").spawn(world, slots, projections, entity, now);
                actor.gibbed = true;
                body.contents = 0;
                // Corpses have already fired their authored death outputs.
                if (actor.mode == .dead) actor.changed_ms = now;
            }
        }
        if (dead and classes.vanishesOnDeath(kind)) {
            try @import("progression.zig").kill(world, hurt, definition.health, self.episode, &self.weapons);
            try @import("actor_spawns.zig").death(self, world, slots, projections, router, entity, now);
            engine.unlink(&projections[binding.slot]);
            try slots.release(binding.slot, entity);
            try retirement(world, entity, "vanished", now);
            try world.destroy(entity);
            return;
        }
        if (dead and actor.mode != .dead and (!classes.ownsDeath(kind) or petrified)) {
            try classes.die(kind, &frame);
            actor.evasion.until_ms = null;
            actor.melee.active = false;
            actor.reaction = null;
            actor.reaction_until_ms = null;
            actor.mode = .dead;
            actor.changed_ms = now;
            body.contents = if (petrified) c.CONTENTS_BODY else if (actor.gibbed) 0 else c.CONTENTS_CORPSE;
            // Retain supplied horizontal bounds; final-pose corpse bounds remain to qualify.
            if (!petrified) body.maxs[2] = @min(body.maxs[2], 0);
        }
        if (petrified) {
            (try world.get(entity, data.Actor)).* = actor;
            (try world.get(entity, data.Body)).* = body;
            (try world.get(entity, data.Velocity)).linear = @splat(0);
            try self.publish(world, entity, projections, now);
            if (dead and !actor.death_dispatched) try self.dispatchDeath(&frame);
            return;
        }
        if (!dead) try classes.sense(kind, &frame);
        if (catalog.ambient(kind)) actor.receipt = hurt.revision;
        if (!dead and @import("held.zig").held(world, entity)) {
            try self.publish(world, entity, projections, now);
            return;
        }
        if (!dead) try classes.prepare(kind, &frame);
        const script = world.get(entity, data.Script) catch null;
        const acting = classes.scriptable(kind, &actor) and script != null and script.?.active;
        if (!dead and !acting) try classes.perceive(kind, &frame);
        if (!dead) {
            velocity = (try world.get(entity, data.Velocity)).*;
            if (try classes.preempt(kind, &frame)) return self.finish(&frame);
        }
        const following = classes.follows(kind, &actor) and actor.mode != .flee and actor.path != 0 and hurt.revision == actor.receipt and (actor.ignore_player or actor.threat == 0);
        if (!dead and body.motion_owner == null and (acting or following)) {
            velocity = (try world.get(entity, data.Velocity)).*;
            const speed = switch (classes.pathGait(kind)) {
                .walk => definition.walk_speed,
                .run => definition.speed,
            };
            const point = if (acting and script.?.moving) script.?.destination else if (!acting and following) try @import("scripts.zig").path(world, slots, projections, router, entity, &actor, pose, speed, now) else null;
            actor.mode = if (point != null) .chase else .idle;
            try classes.pathMove(kind, &frame, point, speed);
            return self.finish(&frame);
        }
        if (!@import("held.zig").held(world, entity)) {
            velocity = (try world.get(entity, data.Velocity)).*;
            switch (try classes.takeover(kind, &frame)) {
                .pass => {},
                .done => return,
                .stepped => return self.finish(&frame),
            }
        }
        if (!dead) try classes.think(kind, &frame);
        velocity = (try world.get(entity, data.Velocity)).*;
        frame.threat = if (@import("region_access.zig").find(world, actor.threat)) |source| (try source.get(data.Transform)).position else actor.threat_position;
        frame.slow = if (world.get(entity, data.Ailments) catch null) |ailment| 1 - 0.8 * ailment.freeze_level else 1;
        if (body.motion_owner == null) try classes.move(kind, &frame) else try common.move(&frame);
        if (!dead and actor.evasion.until_ms != null and actor.evasion.kind == .strafe) pose.angles[1] = actor.evasion.yaw;
        if (!dead) classes.settle(kind, &frame);
        try self.finish(&frame);
        if (dead and !actor.death_dispatched) try self.dispatchDeath(&frame);
    }
    /// Writes the step's working copies back and publishes the actor.
    fn finish(self: *Actors, frame: *classes.Frame) !void {
        try common.store(frame);
        try self.publish(frame.world, frame.entity, frame.projections, frame.now);
    }
};
/// Degrees up (positive) or down from an actor's chest to the enemy it attacks and saw within the
/// last second; 0 otherwise (a running body keeps its authored lean). Presentation only (the
/// reference turns monsters by yaw alone).
pub fn aimPitch(actor: data.Actor, pose: data.Transform, body: data.Body, now: i64) f32 {
    if (actor.threat == 0 or (actor.mode != .attack and actor.mode != .reload) or now - actor.threat_seen_ms > 1000) return 0;
    const chest = pose.position[2] + body.mins[2] + (body.maxs[2] - body.mins[2]) * 0.7;
    const rise = actor.threat_position[2] + 8 - chest;
    const run = @sqrt((actor.threat_position[0] - pose.position[0]) * (actor.threat_position[0] - pose.position[0]) + (actor.threat_position[1] - pose.position[1]) * (actor.threat_position[1] - pose.position[1]));
    if (run < 1) return 0;
    return std.math.clamp(std.math.atan2(rise, run) * 180 / std.math.pi, -60, 60);
}
/// Probe instrumentation (`dk3_runtime_pacify_monsters`): every monster of the world stops
/// perceiving the player, so renderer and lighting captures are not interrupted by attacks.
/// Difficulty changed during play (`g_spSkill`, the in-game options): the table's difficulty
/// columns and every living actor's health follow at once, keeping each actor's share of health.
/// What the skill already decided at spawn (which entities exist) stays.
pub fn followDifficulty(self: *Actors, world: *data.World, skill: i32) !void {
    if (skill == self.skill or self.skill == 0) return;
    const ratio = rules.difficultyFactor(skill) / rules.difficultyFactor(self.skill);
    self.skill = skill;
    if (ratio == 1) return;
    self.table.rescale(ratio);
    var query = world.queryAccess(data.World.mask(.{ data.Actor, data.Health }), 0, data.World.mask(.{data.Health}));
    defer query.deinit();
    while (query.next()) |view| for (view.write(data.Health)) |*health| {
        if (health.current <= 0) continue;
        health.maximum = @max(1, @as(i32, @intFromFloat(@round(@as(f32, @floatFromInt(health.maximum)) * ratio))));
        health.current = std.math.clamp(@as(i32, @intFromFloat(@round(@as(f32, @floatFromInt(health.current)) * ratio))), 1, health.maximum);
    };
    var message: [96]u8 = undefined;
    engine.print(std.fmt.bufPrintZ(&message, "dk3 difficulty: skill={d} ratio={d:.3}\n", .{ skill, ratio }) catch "dk3 difficulty\n");
}
/// Nothing is removed: other systems keep their references (destroying actors this way crashed
/// e1m1a). Hurting a monster makes it hostile again.
pub fn pacifyMonsters(world: *data.World) !usize {
    var count: usize = 0;
    var query = world.queryAccess(data.World.mask(.{data.Actor}), 0, data.World.mask(.{data.Actor}));
    defer query.deinit();
    while (query.next()) |view| for (view.write(data.Actor)) |*actor| {
        if (!std.mem.startsWith(u8, catalog.entries[actor.definition].classname, monster_prefix)) continue;
        actor.ignore_player = true;
        actor.threat = 0;
        count += 1;
    };
    return count;
}

pub fn diagnostics(self: *const Actors, world: *data.World, slots: *const Slots, now: i64) !void {
    for (slots.occupants) |occupant| {
        const entity = occupant orelse continue;
        const actor = world.get(entity, data.Actor) catch continue;
        const pose = (try world.get(entity, data.Transform)).*;
        const body = (try world.get(entity, data.Body)).*;
        const aim = v.add(pose.position, v.scale(v.add(body.mins, body.maxs), 0.5));
        var sight = false;
        if (slots.occupants[0]) |player| {
            const state = (try world.get(player, data.Player)).*;
            const start = v.add((try world.get(player, data.Transform)).position, .{ 0, 0, state.view_height });
            const trace = try engine.collisionService().trace(.{ .start = start, .end = aim, .mins = @splat(0), .maxs = @splat(0), .slot = 0, .mask = c.MASK_SHOT });
            sight = !trace.start_solid and (trace.fraction == 1 or trace.entity == (try world.get(entity, data.Binding)).slot);
        }
        const velocity = (try world.get(entity, data.Velocity)).linear;
        const kind = catalog.entries[actor.definition].kind;
        var text: [1024]u8 = undefined;
        var writer = std.Io.Writer.fixed(&text);
        try writer.print("dk3 zig actor: id={d} state={s} health={d} pos={d:.3},{d:.3},{d:.3} threat={d} witness={d} class={s} unique={s} path={d} ignore={d} sight={d} aim={d:.3},{d:.3},{d:.3} velocity={d:.3},{d:.3},{d:.3} ground={d} now={d} angles={d:.3},{d:.3},{d:.3}", .{ try world.persistentId(entity), @tagName(actor.mode), (try world.get(entity, data.Health)).current, pose.position[0], pose.position[1], pose.position[2], actor.threat, actor.witness_ms, catalog.entries[actor.definition].classname, actor.unique, actor.path, @intFromBool(actor.ignore_player), @intFromBool(sight), aim[0], aim[1], aim[2], velocity[0], velocity[1], velocity[2], actor.ground_entity, now, pose.angles[0], pose.angles[1], pose.angles[2] });
        if (world.get(entity, data.Script) catch null) |script| if (script.active) try writer.writeAll(" script=1");
        // What holds it up: the hull's support just below (a walkable floor has normal z ≥ 0.7).
        const support = try @import("actor_collision.zig").service().trace(.{ .start = pose.position, .end = v.add(pose.position, .{ 0, 0, -0.25 }), .mins = body.mins, .maxs = body.maxs, .slot = (try world.get(entity, data.Binding)).slot, .mask = body.collision_mask });
        if (actor.cover.destination) |point| try writer.print(" cover={d:.0},{d:.0},{d:.0}", .{ point[0], point[1], point[2] });
        if (actor.cover.looking_until_ms) |until| try writer.print(" looking_until={d}", .{until});
        try writer.print(" support={d:.2},{d:.2},{d:.2},{d:.2},{d}", .{ support.fraction, support.normal[0], support.normal[1], support.normal[2], @intFromBool(support.start_solid) });
        if (actor.route.waypoint) |point| try writer.print(" waypoint={d:.0},{d:.0},{d:.0} jump={d} drop={d} blocked={d}", .{ point.point[0], point.point[1], point.point[2], @intFromBool(point.jump), @intFromBool(point.drop), @intFromBool(actor.route.blocked) });
        try classes.diagnose(kind, self.viewOf(world, entity, actor, now), &writer);
        try writer.writeAll("\n\x00");
        const line = writer.buffered();
        engine.print(line[0 .. line.len - 1 :0]);
    }
    engine.print("dk3 zig actor states complete\n");
}

fn retirement(world: *data.World, entity: ecs.Entity, reason: []const u8, now: i64) !void {
    if (engine.integer("dk3_runtime_restore_audit") == 0) return;
    var map_name: [c.MAX_QPATH]u8 = undefined;
    var message: [160]u8 = undefined;
    engine.print(try std.fmt.bufPrintZ(&message, "dk3 actor retired: map={s} id={d} reason={s} at={d}\n", .{ engine.mapName(&map_name), try world.persistentId(entity), reason, now }));
}
/// Restored or transferred actors are projected by their class (projection_classes.zig).
pub const projected = .{data.Actor};
pub fn project(projecting: *const @import("system_context.zig").Project) !bool {
    try projecting.systems.actors.publish(projecting.world, projecting.entity, projecting.projections, projecting.now);
    return true;
}
