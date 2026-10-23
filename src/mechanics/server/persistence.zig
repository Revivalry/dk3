// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Save preparation owns staging and validation; projection commit follows only
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
//! after the complete snapshot has been admitted. No opaque engine state is saved.
const std = @import("std");
const entity_classes = @import("entity_classes/registry.zig");
const data = @import("../../game/domain/components.zig");
const format = @import("../domain/snapshot.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const storage = @import("../../engine/save_storage.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const c = abi.c;
pub fn mapName(buffer: []u8) []const u8 {
    return engine.mapName(buffer);
}
pub fn capture(allocator: std.mem.Allocator, bytes: []u8, world: *data.World, clients: *const @import("clients.zig").Clients, targets: *const @import("targets.zig").Router, now: i64, visited: []const format.Archive, journey: ?@import("../domain/travel.zig").Journey) ![]const u8 {
    const player = clients.entities[0] orelse return error.NoPlayerToSave;
    var map: [64]u8 = undefined;
    const header: format.Header = .{ .at_ms = now, .player_id = try world.persistentId(player), .episode = clients.episode, .next_id = world.next_id, .namespace = @intCast(world.id_first >> 24), .asset_crc = @truncate(@as(usize, @bitCast(engine.gateway.call(c.G_DK3_WORLD_CHECKSUM_V1, .{})))), .resources = try @import("resources.zig").capture(allocator), .pending = targets.pending, .journey = journey };
    return format.captureCampaign(allocator, bytes, world, mapName(&map), @intCast(std.math.clamp(engine.integer("g_spSkill"), 1, 5)), header, visited);
}
/// A save's preview picture: none (internal saves), with the HUD (autosaves, so play never
/// flickers) or clean (a save the player asked for).
pub const Preview = enum { none, hud, clean };
pub fn save(world: *data.World, clients: *const @import("clients.zig").Clients, targets: *const @import("targets.zig").Router, systems: *@import("world_systems.zig").State, slot: []const u8, now: i64, visited: []const format.Archive, residents: []const format.Archive, preview: Preview) !void {
    if (engine.integer("g_gametype") != c.GT_SINGLE_PLAYER) return error.SaveRequiresSinglePlayer;
    const player = clients.entities[0] orelse return error.NoPlayerToSave;
    if ((try world.get(player, data.Health)).current <= 0) return error.CannotSaveDeadPlayer;
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const bytes = try allocator.alloc(u8, format.maximum);
    const clock_start = engine.gateway.call(c.G_MILLISECONDS, .{});
    var map: [64]u8 = undefined;
    const header: format.Header = .{ .at_ms = now, .player_id = try world.persistentId(player), .episode = clients.episode, .next_id = world.next_id, .namespace = @intCast(world.id_first >> 24), .asset_crc = @truncate(@as(usize, @bitCast(engine.gateway.call(c.G_DK3_WORLD_CHECKSUM_V1, .{})))), .resources = try @import("resources.zig").capture(allocator), .pending = targets.pending };
    const saved = try format.captureRegion(allocator, bytes, world, mapName(&map), @intCast(std.math.clamp(engine.integer("g_spSkill"), 1, 5)), header, visited, residents);
    const captured_ms = engine.gateway.call(c.G_MILLISECONDS, .{});
    // This also catches semantic schema omissions before replacing a prior save.
    var admitted = try format.decode(allocator, saved);
    defer admitted.deinit(allocator);
    try admit(&admitted, systems);
    const validated_ms = engine.gateway.call(c.G_MILLISECONDS, .{});
    try storage.write(slot, saved, false);
    if (engine.integer("developer") >= 1) {
        var timing: [160]u8 = undefined;
        engine.print(std.fmt.bufPrintZ(&timing, "dk3 save timing: slot={s} bytes={d} capture_ms={d} validate_ms={d} write_ms={d}\n", .{ slot, saved.len, captured_ms - clock_start, validated_ms - captured_ms, engine.gateway.call(c.G_MILLISECONDS, .{}) - validated_ms }) catch "dk3 save timing\n");
    }
    var info: [768]u8 = undefined;
    const health = (try world.get(player, data.Health)).current;
    const character = (try world.get(player, data.Character)).*;
    // The preview picture alternates between two names, so a menu that already showed the old
    // one never shows it from the renderer's cache.
    var shot: [64]u8 = undefined;
    const previous = storage.readInfo(allocator, slot) catch null;
    const second = if (previous) |text| std.mem.indexOf(u8, text, "-a\"") != null else false;
    const shot_name = if (preview == .none) "" else try std.fmt.bufPrint(&shot, "dk3save-{s}-{s}", .{ slot, if (second) "b" else "a" });
    var date: [32]u8 = undefined;
    const unix: i64 = wallTime();
    const metadata = try std.fmt.bufPrint(&info, "dk3_save_info 2\nmap \"{s}\"\nhealth {d}\nlevel {d}\nnative_schema {d}\ntime {d}\ndate \"{s}\"\nskill {d}\nshot \"{s}\"\n", .{ mapName(&map), health, character.level, format.schema, unix, localDate(unix, &date), engine.integer("g_spSkill"), shot_name });
    storage.write(slot, metadata, true) catch engine.print("dk3 save: saved world; preview metadata could not be written\n");
    if (preview != .none) {
        var command: [96]u8 = undefined;
        engine.send(0, try std.fmt.bufPrintZ(&command, "dk3_saveshot {s} {s}", .{ shot_name, @tagName(preview) }));
    }
}
const is_windows = @import("builtin").os.tag == .windows;
const tm = if (is_windows) extern struct { sec: c_int, min: c_int, hour: c_int, mday: c_int, mon: c_int, year: c_int, wday: c_int, yday: c_int, isdst: c_int } else extern struct { sec: c_int, min: c_int, hour: c_int, mday: c_int, mon: c_int, year: c_int, wday: c_int, yday: c_int, isdst: c_int, gmtoff: c_long, zone: ?[*:0]const u8 };
extern "c" fn localtime_r(timer: *const i64, result: *tm) ?*tm;
extern "c" fn _localtime64_s(result: *tm, timer: *const i64) c_int;
extern "c" fn time(timer: *i64) i64;
fn wallTime() i64 {
    if (is_windows) {
        var result: i64 = 0;
        return time(&result);
    }
    var now_wall: std.c.timespec = undefined;
    return if (std.c.clock_gettime(std.c.CLOCK.REALTIME, &now_wall) == 0) now_wall.sec else 0;
}
/// The save's wall-clock time in the player's time zone, "2026-10-12 14:03".
fn localDate(unix: i64, buffer: []u8) []const u8 {
    var local: tm = undefined;
    if (is_windows) {
        if (_localtime64_s(&local, &unix) != 0) return "";
    } else if (localtime_r(&unix, &local) == null) return "";
    return std.fmt.bufPrint(buffer, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}", .{ @as(u32, @intCast(local.year + 1900)), @as(u32, @intCast(local.mon + 1)), @as(u32, @intCast(local.mday)), @as(u32, @intCast(local.hour)), @as(u32, @intCast(local.min)) }) catch "";
}
pub fn prepare(slot: []const u8, previous: bool) !format.Loaded {
    const allocator = std.heap.c_allocator;
    const bytes = try storage.read(allocator, slot, previous);
    defer allocator.free(bytes);
    return format.decode(allocator, bytes);
}
/// Admission may load immutable class metadata, but cannot mutate engine entities.
/// Projection rebuilding below is infallible
/// for the admitted entity families and current map's loaded definitions.
pub fn admit(loaded: *format.Loaded, systems: *@import("world_systems.zig").State) !void {
    inline for (projecting_classes.restore) |Class| if (@hasDecl(Class, "restoreAdmit")) try Class.restoreAdmit(&loaded.world);
    try systems.cinematics.admit(&loaded.world);
    try systems.scripts.admit(&loaded.world);
    var query = loaded.world.queryAccess(0, 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities()) |entity| {
        if (loaded.world.get(entity, data.Actor) catch null) |actor| {
            try systems.actors.ensure(actor.definition);
            const definition = systems.actors.table.definitions[actor.definition];
            if (actor.audio.cue) |cue| {
                if (cue >= definition.audio.len) return error.InvalidSavedActorAudio;
                const sequence = definition.audio[cue].sequence orelse return error.InvalidSavedActorAudio;
                if (actor.audio.started_ms == null or actor.audio.sampled_ms == null or actor.audio.frame < sequence.first or actor.audio.frame > sequence.last) return error.InvalidSavedActorAudio;
            }
            if (actor.idle_pose) |pose| {
                // Matched by its frames: a save made before a clip-rate change re-binds to the
                // class's current clip.
                var found = false;
                for (definition.idle_choices) |choice| if (pose.first == choice.sequence.first and pose.last == choice.sequence.last) {
                    actor.idle_pose = choice.sequence;
                    found = true;
                    break;
                };
                if (!found) return error.InvalidSavedActorIdle;
            }
        }
        if (loaded.world.get(entity, data.Binding) catch null) |binding| {
            if (effect(&loaded.world, entity)) continue;
            if (loaded.world.get(entity, data.WorldControl) catch null) |control| if (entity_classes.modelChecked(control.action)) {
                // A projected control is bound to the model its class names, or to none.
                if (entity_classes.savedModel(control.action)) |model| {
                    if (binding.model == 0 or binding.model > loaded.header.resources.models.len or !std.mem.eql(u8, loaded.header.resources.models[binding.model - 1], model)) return error.InvalidSavedControlModel;
                } else if (binding.model != 0) return error.InvalidSavedControlModel;
                continue;
            };
            const object = loaded.world.get(entity, data.MapObject) catch null;
            const brush = object != null and object.?.model.len > 1 and object.?.model[0] == '*';
            if (brush) {
                const model = try std.fmt.parseInt(u16, object.?.model[1..], 10);
                if (model == 0 or model >= systems.inline_models or binding.model != model) return error.InvalidSavedBrush;
            } else if (object != null and object.?.model.len == 0 and entity_classes.traitsOf(object.?.classname).train and @import("platforms.zig").pathPhase(&loaded.world, entity) != null) {
                // Authored invisible trains carry attachments without a BSP model.
                if (binding.model != 0 or (try loaded.world.get(entity, data.Body)).contents != 0) return error.InvalidSavedTrain;
            } else if ((loaded.world.get(entity, data.Player) catch null) == null) {
                const model_optional = modelless(&loaded.world, entity);
                if ((!model_optional and binding.model == 0) or binding.model > loaded.header.resources.models.len) {
                    var text: [192]u8 = undefined;
                    engine.print(try std.fmt.bufPrintZ(&text, "dk3 save: invalid model on entity {d} ({s}), model={d}, registered={d}\n", .{ try loaded.world.persistentId(entity), if (object) |value| value.classname else "dynamic", binding.model, loaded.header.resources.models.len }));
                    return error.InvalidSavedModel;
                }
                if (!restorable(&loaded.world, entity)) return error.UnsupportedSavedEntity;
            }
        }
    };
}
/// Binds what restored classes register before the first gamestate (their `restoreBegin`).
pub fn restoreBindings(world: *data.World) !void {
    inline for (projecting_classes.restore) |Class| if (@hasDecl(Class, "restoreBegin")) try Class.restoreBegin(world);
}
pub fn project(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, clients: *@import("clients.zig").Clients, states: []c.playerState_t, systems: *const @import("world_systems.zig").State, header: format.Header, now: i64) !void {
    try restoreBindings(world);
    slots.* = .{};
    clients.entities = @splat(null);
    clients.episode = header.episode;
    for (projections, 0..) |*projection, i| {
        projection.* = std.mem.zeroes(abi.EntityProjection);
        projection.state.number = @intCast(i);
        projection.shared.ownerNum = c.ENTITYNUM_NONE;
    }
    @memset(std.mem.sliceAsBytes(states), 0);
    states[0].gravity = 800;
    states[0].clientNum = 0;
    if (header.player_id != 0) {
        const player = world.find(header.player_id) orelse return error.MissingSavedPlayer;
        clients.entities[0] = player;
        const player_state = try world.get(player, data.Player);
        player_state.command_ms = now;
        var input: c.usercmd_t = undefined;
        engine.usercmd(0, &input);
        for ((try world.get(player, data.Transform)).angles, 0..) |angle, i| player_state.delta_angles[i] = @as(i32, @intFromFloat(@mod(angle, 360) * (65536.0 / 360.0))) -% input.angles[i];
    }
    var query = world.queryAccess(data.World.mask(.{data.Binding}), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.Binding)) |entity, binding| {
        // Saved transport slots are reserved explicitly; entity references remain
        // independent persistent IDs and stale ECS handles are never reused.
        slots.occupants[binding.slot] = entity;
        if (binding.slot == 0) {
            try clients.publish(world, projections, states, 0, now);
            continue;
        }
        try projectEntity(world, slots, projections, systems, entity, now);
    };
    inline for (projecting_classes.restore) |Class| if (@hasDecl(Class, "restoreEnd")) Class.restoreEnd(world, now);
    try @import("music.zig").restore(world, @import("std").heap.c_allocator);
}

/// The same class-owned projection is used after restoration and ownership transfer.
pub fn projectEntity(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, systems: *const @import("world_systems.zig").State, entity: @import("../../core/ecs/world.zig").Entity, now: i64) !void {
    const binding = (try world.get(entity, data.Binding)).*;
    if (world.get(entity, data.WorldControl) catch null) |control| {
        var publishing: entity_classes.Publish = .{ .world = world, .slots = slots, .projections = projections, .entity = entity, .now = now };
        if (try entity_classes.publish(control.action, &publishing)) return;
    }
    const projecting: @import("system_context.zig").Project = .{ .world = world, .slots = slots, .projections = projections, .systems = systems, .entity = entity, .now = now };
    inline for (projecting_classes.publishers) |Class| if (carries(world, entity, Class)) {
        if (try Class.project(&projecting)) return;
    };
    const object = (try world.get(entity, data.MapObject)).*;
    const body = (try world.get(entity, data.Body)).*;
    const transform = (try world.get(entity, data.Transform)).*;
    const projection_slot = &projections[binding.slot];
    var model: [64]u8 = undefined;
    _ = engine.gateway.call(c.G_SET_BRUSH_MODEL, .{ projection_slot, (try std.fmt.bufPrintZ(&model, "{s}", .{object.model})).ptr });
    projection_slot.state.eType = c.ET_MOVER;
    projection_slot.state.pos = @import("../../engine/trajectory.zig").stationary(transform.position);
    projection_slot.state.apos = @import("../../engine/trajectory.zig").stationary(transform.angles);
    projection_slot.shared.currentOrigin = transform.position;
    projection_slot.shared.currentAngles = @import("brushes.zig").collisionAngles(object.classname, transform.angles);
    projection_slot.shared.contents = @bitCast(body.contents);
    var hidden = @import("brushes.zig").hiddenClass(object.classname);
    if (world.get(entity, data.Destructible) catch null) |destructible| hidden = hidden or destructible.hidden or destructible.broken;
    if (world.get(entity, data.Wall) catch null) |wall| hidden = hidden or !wall.visible;
    if (hidden) projection_slot.shared.svFlags |= c.SVF_NOCLIENT;
    engine.link(projection_slot);
}
const projecting_classes = @import("../../game/server/projection_classes.zig");
/// Whether the entity carries any component a projecting class declares.
fn carries(world: *data.World, entity: @import("../../core/ecs/world.zig").Entity, comptime Class: type) bool {
    inline for (Class.projected) |Component| if ((world.get(entity, Component) catch null) != null) return true;
    return false;
}
/// Whether a class binds the entity as a model-less effect.
fn effect(world: *data.World, entity: @import("../../core/ecs/world.zig").Entity) bool {
    inline for (projecting_classes.publishers) |Class| if (@hasDecl(Class, "effect") and Class.effect and carries(world, entity, Class)) return true;
    return false;
}
/// A saved non-brush entity is admitted when a restorable class projects it.
fn restorable(world: *data.World, entity: @import("../../core/ecs/world.zig").Entity) bool {
    inline for (projecting_classes.publishers) |Class| {
        const admitted = if (@hasDecl(Class, "restorable")) Class.restorable else true;
        if (admitted and carries(world, entity, Class)) return true;
    }
    return false;
}
/// Whether a class draws the entity without a model.
fn modelless(world: *data.World, entity: @import("../../core/ecs/world.zig").Entity) bool {
    inline for (projecting_classes.publishers) |Class| if (@hasDecl(Class, "modelless") and carries(world, entity, Class)) {
        if (@TypeOf(Class.modelless) == bool) {
            if (Class.modelless) return true;
        } else if (Class.modelless(world, entity)) return true;
    };
    return false;
}
