// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Native snapshot ingestion, shared movement prediction and world rendering.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
const std = @import("std");
const abi = @import("engine/abi.zig");
const engine = @import("engine/client.zig");
const bridge = @import("mechanics/player_state.zig");
const data = @import("game/domain/components.zig");
const move = @import("mechanics/domain/player_move.zig");
const v = @import("core/domain/vector.zig");
const c = abi.c;
const weapons = @import("mechanics/domain/weapons.zig");
var selected_weapon: i32 = 0;
var resident_worlds: @import("mechanics/client/resident_worlds.zig").State = .{};
var inventory_mask: i32 = 0;
var weapon_table: weapons.Table = .{};
var inline_models: [c.MAX_MODELS]c.qhandle_t = @splat(0);
var game: c.gameState_t = undefined;
var display: c.glconfig_t = undefined;
var snapshot: c.snapshot_t = undefined;
var display_entities: @TypeOf(snapshot.entities) = undefined;
var world: ?data.World = null;
var predicted: ?@import("core/ecs/world.zig").Entity = null;
var have_snapshot = false;
var snapshot_number: i32 = -1;
var command_sequence: i32 = 0;
var gamestate_sequence: i32 = 0;
var client_number: i32 = 0;
var view_angles: v.Vec3 = @splat(0);
var weapon_view: @import("mechanics/client/weapon_view.zig").View = .{};
var view_motion: @import("mechanics/domain/view_motion.zig").State = .{};
var camera_height: f32 = 22;
var camera_offset: f32 = 0;
var camera_position: v.Vec3 = @splat(0);
var hud: @import("mechanics/client/hud.zig").Hud = .{};
var foreign_presented: [c.MAX_GENTITIES]u32 = @splat(0);
var foreign_count: usize = 0;
var presentation: render_classes.Counters = .{};
const render_classes = @import("mechanics/client/render_classes/registry.zig");
const weapon_classes = @import("mechanics/client/weapon_classes/registry.zig");
fn loadingProgress(done: usize, total: usize) !void {
    loading.publish(loading.bar.registration(done, total));
    _ = engine.gateway.call(c.CG_UPDATESCREEN, .{});
}
const loading = @import("mechanics/client/loading_bar.zig");
fn loadingNow() i32 {
    return @intCast(engine.gateway.call(c.CG_MILLISECONDS, .{}));
}
export fn dllEntry(callback: abi.Syscall) callconv(.c) void {
    engine.gateway.bind(callback);
}
fn shutdown() void {
    view_motion = .{};
    resident_worlds.deinit();
    @import("core/client/interpolation.zig").reset();
    @import("mechanics/client/scoreboard.zig").reset();
    @import("mechanics/client/messages.zig").reset();
    @import("mechanics/client/cinematics.zig").reset();
    @import("mechanics/client/sword_aura.zig").reset();
    @import("mechanics/client/fx_particles.zig").reset();
    @import("mechanics/client/gibs.zig").reset();
    inline for (presenters) |Class| if (@hasDecl(Class, "reset")) Class.reset();
    weapon_view.deinit();
    if (world) |*value| value.deinit();
    world = null;
    predicted = null;
}
fn init(server_message: i32, sequence: i32, client: i32, boundary: i32) !void {
    shutdown();
    @import("mechanics/client/models.zig").reset();
    @import("mechanics/client/objectives.zig").reset();
    @import("mechanics/client/held_weapons.zig").reset();
    @import("mechanics/client/events.zig").reset();
    selected_weapon = 0;
    @import("mechanics/client/music.zig").reset();
    inventory_mask = 0;
    if (engine.integer("dk3_runtime_probe") != 2) return error.ReplacementGameplayNotQualified;
    _ = engine.gateway.call(c.CG_GETGAMESTATE, .{&game});
    if (!std.mem.eql(u8, try engine.config(&game, c.CS_GAME_VERSION), bridge.version)) return error.RuntimeMismatch;
    const info = try engine.config(&game, c.CS_SERVERINFO);
    const name = engine.info(info, "mapname") orelse return error.MissingMap;
    for (name) |ch| if (!std.ascii.isAlphanumeric(ch) and ch != '_') return error.InvalidMap;
    var path: [128]u8 = undefined;
    const map = try std.fmt.bufPrintZ(&path, "maps/{s}.bsp", .{name});
    var previous_map: [64]u8 = @splat(0);
    _ = engine.gateway.call(c.CG_CVAR_VARIABLESTRINGBUFFER, .{ @as([*:0]const u8, "dk3_loading_map"), &previous_map, @as(isize, previous_map.len) });
    _ = engine.gateway.call(c.CG_CVAR_SET, .{ @as([*:0]const u8, "dk3_loading_previous_map"), &previous_map });
    var map_buffer: [64]u8 = undefined;
    _ = engine.gateway.call(c.CG_CVAR_SET, .{ @as([*:0]const u8, "dk3_loading_map"), (try std.fmt.bufPrintZ(&map_buffer, "{s}", .{name})).ptr });
    _ = engine.gateway.call(c.CG_GETGLCONFIG, .{&display});
    const gametype = std.fmt.parseInt(i32, engine.info(info, "g_gametype") orelse "0", 10) catch 0;
    loading.publish(loading.bar.begin(gametype == c.GT_SINGLE_PLAYER, loadingNow()));
    _ = engine.gateway.call(c.CG_UPDATESCREEN, .{});
    _ = engine.gateway.call(c.CG_CM_LOADMAP, .{map.ptr});
    loading.mark("collision", loadingNow());
    @import("mechanics/client/fog.zig").reset();
    _ = engine.gateway.call(c.CG_R_LOADWORLDMAP, .{map.ptr});
    loading.mark("render-world", loadingNow());
    try @import("mechanics/client/sky.zig").init(name, &game);
    @memset(&inline_models, 0);
    const model_count = engine.gateway.call(c.CG_CM_NUMINLINEMODELS, .{});
    if (model_count < 1 or model_count > inline_models.len) return error.InlineModelLimit;
    var resources: usize = @intCast(model_count);
    for (1..c.MAX_MODELS) |i| if ((try engine.config(&game, c.CS_MODELS + i)).len > 0) {
        resources += 1;
    };
    for (1..c.MAX_SOUNDS) |i| if ((try engine.config(&game, c.CS_SOUNDS + i)).len > 0) {
        resources += 1;
    };
    var loaded: usize = 0;
    for (1..@intCast(model_count)) |i| {
        var model_name: [20]u8 = undefined;
        const model = try std.fmt.bufPrintZ(&model_name, "*{d}", .{i});
        inline_models[i] = @intCast(engine.gateway.call(c.CG_R_REGISTERMODEL, .{model.ptr}));
        loaded += 1;
        if (loaded % 8 == 0) try loadingProgress(loaded, resources);
    }
    loading.mark("inline-models", loadingNow());
    for (1..c.MAX_MODELS) |i| if ((try engine.config(&game, c.CS_MODELS + i)).len > 0) {
        const model = try engine.config(&game, c.CS_MODELS + i);
        if (std.mem.endsWith(u8, model, ".sp2")) {
            _ = try @import("core/client/sprites.zig").register(model);
        } else _ = try @import("mechanics/client/models.zig").get(&game, @intCast(i));
        loaded += 1;
        if (loaded % 8 == 0) try loadingProgress(loaded, resources);
    };
    loading.mark("models", loadingNow());
    for (1..c.MAX_SOUNDS) |i| {
        const sound = try engine.config(&game, c.CS_SOUNDS + i);
        if (sound.len == 0) continue;
        _ = try engine.registerSound(sound);
        loaded += 1;
        if (loaded % 8 == 0) try loadingProgress(loaded, resources);
    }
    loading.mark("sounds", loadingNow());
    const table_bytes = try @import("engine/files.zig").read(.client, &engine.gateway, std.heap.c_allocator, "dk3/tables/weapons.cfg", 4 * 1024 * 1024);
    defer std.heap.c_allocator.free(table_bytes);
    weapon_table = try weapons.Table.parse(table_bytes);
    weapon_view.init();
    try hud.init();
    try resident_worlds.captureInitial(&game, &inline_models);
    loading.publish(loading.bar.registered());
    loading.mark("registered", loadingNow());
    world = data.World.init(std.heap.c_allocator, 128);
    predicted = try world.?.create(null, .{ data.Transform{}, data.Velocity{}, data.Player{}, data.Health{}, data.Weapons{}, data.Character{}, data.Ailments{} });
    have_snapshot = false;
    client_number = client;
    command_sequence = sequence;
    gamestate_sequence = boundary;
    snapshot_number = server_message - 1;
    _ = engine.gateway.call(c.CG_ADDCOMMAND, .{@as([*:0]const u8, "viewpos")});
    _ = engine.gateway.call(c.CG_ADDCOMMAND, .{@as([*:0]const u8, "dk3_runtime_render_world")});
    _ = engine.gateway.call(c.CG_ADDCOMMAND, .{@as([*:0]const u8, "use")});
    for ([_][*:0]const u8{ "cin_skip", "dk3_runtime_presentation", "weapon", "weapnext", "weapprev", "attribute", "inventory", "invnext", "invprev", "attribute_next", "attribute_increase", "save", "load", "+scores", "-scores", "say", "say_team", "ready", "team", "callvote", "vote" }) |command_name| _ = engine.gateway.call(c.CG_ADDCOMMAND, .{command_name});
    inline for (presenters) |Class| if (@hasDecl(Class, "console_commands")) for (Class.console_commands) |command_name| {
        _ = engine.gateway.call(c.CG_ADDCOMMAND, .{command_name});
    };
    engine.print("dk3 zig: shared movement prediction initialized\n");
}
fn draw(now: i32) !void {
    const prior_collision = engine.gateway.call(c.CG_DK3_COLLISION_CURRENT_V1, .{});
    defer if (prior_collision != 0) {
        _ = engine.gateway.call(c.CG_DK3_COLLISION_SELECT_V1, .{prior_collision});
    };
    if (resident_worlds.initial != null and engine.gateway.call(c.CG_DK3_COLLISION_SELECT_V1, .{@as(isize, try resident_worlds.collision())}) == 0) return error.PredictionWorldUnavailable;
    if (world == null) return;
    try resident_worlds.step();
    var latest: i32 = 0;
    var server_time: i32 = 0;
    _ = engine.gateway.call(c.CG_GETCURRENTSNAPSHOTNUMBER, .{ &latest, &server_time });
    if (latest > snapshot_number) {
        if (engine.gateway.call(c.CG_GETSNAPSHOT, .{ @as(isize, latest), &snapshot }) == 0) return;
        snapshot_number = latest;
        // A primed connection can carry a ring-buffer frame from before the
        // map restart. Its player/entity payload has no active-world ownership
        // until ClientBegin; do not ingest events, poses or reliable commands.
        if (snapshot.snapFlags & c.SNAPFLAG_NOT_ACTIVE != 0) {
            engine.print("dk3 zig client: waiting for active snapshot\n");
            return;
        }
        if (!have_snapshot) engine.print("dk3 zig client: first snapshot applied\n");
        have_snapshot = true;
        weapon_view.state.synchronize(@truncate(@as(u32, @bitCast(snapshot.ps.persistant[c.PERS_SPAWN_COUNT]))));
        const sequence_number: u32 = @bitCast(snapshot.ps.eventSequence);
        for (0..c.MAX_PS_EVENTS) |i| {
            const serial = sequence_number -% @as(u32, @intCast(c.MAX_PS_EVENTS - i));
            const index = serial & (c.MAX_PS_EVENTS - 1);
            if (snapshot.ps.events[index] != c.EV_FIRE_WEAPON) continue;
            const id = snapshot.ps.eventParms[index];
            if (id > 0 and id <= 28) weapon_view.fire(@intCast(id), serial, snapshot.ps.commandTime);
        }
        while (command_sequence < snapshot.serverCommandSequence) {
            command_sequence += 1;
            if (engine.gateway.call(c.CG_GETSERVERCOMMAND, .{@as(isize, command_sequence)}) != 0) {
                if (command_sequence > gamestate_sequence) {
                    try resident_worlds.serverCommand();
                    _ = try resident_worlds.enter(&inline_models);
                } else {
                    // The engine deliberately retains unexecuted reliable
                    // commands across gamestates. Resident resources do not
                    // survive that boundary; commands for them are obsolete.
                    var name: [96]u8 = undefined;
                    _ = engine.gateway.call(c.CG_ARGV, .{ @as(isize, 0), &name, @as(isize, name.len) });
                    const command_name = std.mem.sliceTo(&name, 0);
                    if (std.mem.startsWith(u8, command_name, "dk3_world_") or std.mem.eql(u8, command_name, "dk3_region_wait")) {
                        var message: [160]u8 = undefined;
                        engine.print(try std.fmt.bufPrintZ(&message, "dk3 world command: obsolete={s} sequence={d} gamestate={d}\n", .{ command_name, command_sequence, gamestate_sequence }));
                    }
                }
                try @import("mechanics/client/cinematics.zig").command();
                try @import("mechanics/client/events.zig").command();
                @import("mechanics/client/messages.zig").command(now);
                @import("mechanics/client/scoreboard.zig").command();
                @import("mechanics/client/save_preview.zig").command();
                inline for (presenters) |Class| if (@hasDecl(Class, "command")) Class.command();
                if (@import("mechanics/client/commands.zig").restored()) |restored| {
                    view_motion = .{};
                    @import("core/client/interpolation.zig").reset();
                    @import("mechanics/client/messages.zig").reset();
                    @import("mechanics/client/models.zig").reset();
                    @import("mechanics/client/objectives.zig").reset();
                    @import("mechanics/client/held_weapons.zig").reset();
                    @import("mechanics/client/events.zig").reset();
                    inline for (presenters) |Class| if (@hasDecl(Class, "world_state") and Class.world_state) Class.reset();
                    weapon_view.init();
                    weapon_view.state.synchronize(@truncate(@as(u32, @bitCast(snapshot.ps.persistant[c.PERS_SPAWN_COUNT]))));
                    if (restored.fire) |fire| weapon_view.fire(fire.weapon, fire.serial, fire.started_ms);
                    selected_weapon = snapshot.ps.weapon;
                    engine.print("dk3 zig client: restoration applied\n");
                }
                if (@import("mechanics/client/commands.zig").selectedWeapon(snapshot.ps.dk3Inventory)) |id| selected_weapon = id;
            }
        }
        _ = engine.gateway.call(c.CG_GETGAMESTATE, .{&game});
        if (@as(u32, @bitCast(snapshot.ps.dk3World)) != resident_worlds.active_id) return error.SnapshotWorldMismatch;
        if (snapshot.numEntities < 0 or snapshot.numEntities > snapshot.entities.len) return error.InvalidSnapshot;
        @import("core/client/interpolation.zig").ingest(&snapshot, @import("mechanics/client/cinematics.zig").boundary);
    }
    if (resident_worlds.waiting or !have_snapshot or snapshot_number < 0 or snapshot.ps.clientNum != client_number) return;
    if (snapshot.numEntities < 0 or snapshot.numEntities > snapshot.entities.len) return error.InvalidSnapshot;
    try @import("mechanics/client/music.zig").update(&game);
    try @import("mechanics/client/events.zig").environment(snapshot.ps.dk3SoundEnvironment);
    engine.entity_world = resident_worlds.active_id;
    (try resident_worlds.view(resident_worlds.active_id)).game.* = game;
    // The pusher has already carried ps.origin to serverTime, independently of
    // the last user command. Replay against that same committed brush pose.
    engine.setSnapshot(snapshot.entities[0..@intCast(snapshot.numEntities)], snapshot.serverTime);
    for (snapshot.entities[0..@intCast(snapshot.numEntities)]) |event| {
        const scope = try resident_worlds.selectPresentation(@bitCast(event.dk3World));
        defer scope.deinit();
        const owner = try resident_worlds.view(@bitCast(event.dk3World));
        try @import("mechanics/client/events.zig").consume(owner.game, &.{event});
    }
    @memcpy(display_entities[0..@intCast(snapshot.numEntities)], snapshot.entities[0..@intCast(snapshot.numEntities)]);
    for (display_entities[0..@intCast(snapshot.numEntities)]) |*entity| @import("core/client/interpolation.zig").apply(entity, now);
    @import("mechanics/client/attachments.zig").apply(snapshot.entities[0..@intCast(snapshot.numEntities)], display_entities[0..@intCast(snapshot.numEntities)], snapshot.serverTime, now);
    @import("mechanics/client/ragdolls.zig").reconcile(snapshot.entities[0..@intCast(snapshot.numEntities)]);
    if (selected_weapon == 0 or snapshot.ps.dk3Inventory != inventory_mask) {
        selected_weapon = snapshot.ps.weapon;
        inventory_mask = snapshot.ps.dk3Inventory;
    }
    const w = &world.?;
    const player_entity = predicted.?;
    const transform = try w.get(player_entity, data.Transform);
    const velocity = try w.get(player_entity, data.Velocity);
    const player = try w.get(player_entity, data.Player);
    transform.* = .{ .position = snapshot.ps.origin, .angles = snapshot.ps.viewangles };
    velocity.linear = snapshot.ps.velocity;
    player.* = bridge.read(&snapshot.ps);
    view_motion.synchronize(.{ .world = snapshot.ps.dk3World, .incarnation = snapshot.ps.persistant[c.PERS_SPAWN_COUNT], .teleport = player.teleport_bit, .camera = snapshot.ps.dk3CameraActive, .mode = snapshot.ps.pm_type }, player.command_ms, now);
    const loadout = try w.get(player_entity, data.Weapons);
    loadout.* = bridge.readWeapons(&snapshot.ps);
    const character = try w.get(player_entity, data.Character);
    const ailments = try w.get(player_entity, data.Ailments);
    character.* = bridge.readCharacter(&snapshot.ps);
    ailments.* = .{ .mask = @as(u32, @bitCast(snapshot.ps.dk3Status)) & (7 | 128), .freeze_level = snapshot.ps.dk3FreezeLevel };
    const current: i32 = @intCast(engine.gateway.call(c.CG_GETCURRENTCMDNUMBER, .{}));
    var number = @max(0, current - c.CMD_BACKUP + 1);
    while (number <= current) : (number += 1) {
        var input: c.usercmd_t = undefined;
        if (engine.gateway.call(c.CG_GETUSERCMD, .{ @as(isize, number), &input }) == 0 or input.serverTime <= player.command_ms or input.serverTime > now) continue;
        bridge.holdView(player, transform.angles, input);
        const command = bridge.command(input, &player.delta_angles);
        var motion: @import("core/domain/slide.zig").State = .{ .position = transform.position, .velocity = velocity.linear };
        if (ailments.mask & 128 != 0) motion.velocity = @splat(0);
        var events: weapons.Events = .{};
        var weapon_context: weapons.Context = .{ .ps = loadout, .healthy = snapshot.ps.stats[c.STAT_HEALTH] > 0, .single_player = engine.integer("g_gametype") == c.GT_SINGLE_PLAYER, .table = &weapon_table, .events = &events, .service = engine.collisionService(), .slot = @intCast(client_number), .shot_mask = c.MASK_SHOT, .attack_boost = character.attribute(.attack, command.time_ms) };
        const movement = try move.runWithHook(player, &motion, command, bridge.characterParameters(@intCast(client_number), character.*, ailments.*, command.time_ms), engine.collisionService(), weapon_context.hook());
        var step: f32 = 0;
        for (movement.events[0..movement.event_count]) |event| switch (event) {
            .step => |height| step += height,
            else => {},
        };
        view_motion.command(command.time_ms, if (player.mode == .normal and snapshot.ps.dk3CameraActive == 0) step else 0, now);
        for (events.values[0..events.count], 0..) |event, i| switch (event) {
            .fired => |shot| weapon_view.fire(shot.weapon, loadout.event_sequence -% @as(u32, @intCast(events.count - i)), shot.command_ms),
            .no_ammo => {},
        };
        transform.position = motion.position;
        transform.angles = command.angles;
        velocity.linear = motion.velocity;
    }
    // Move presentation from the snapshot's physics frame to the rendered
    // frame once, using the ground found by replay (jumping/walking off releases
    // the carry). Client time can precede the newest snapshot.
    transform.position = @import("mechanics/client/ground_motion.zig").adjust(transform.position, player.ground_entity, snapshot.ps.dk3World, snapshot.entities[0..@intCast(snapshot.numEntities)], snapshot.serverTime, now);
    view_angles = transform.angles;
    _ = engine.gateway.call(c.CG_SETUSERCMDVALUE, .{ @as(isize, selected_weapon), engine.floatArg(1) });
    var ref = std.mem.zeroes(c.refdef_t);
    ref.width = display.vidWidth;
    ref.height = display.vidHeight;
    ref.time = now;
    const psychic = @import("mechanics/domain/psychic_warp.zig").visual(snapshot.ps.dk3PsyEnd, now);
    ref.fov_x = 90 + psychic.fov;
    ref.fov_y = std.math.atan(@tan(ref.fov_x * std.math.pi / 360) * @as(f32, @floatFromInt(ref.height)) / @as(f32, @floatFromInt(ref.width))) * 360 / std.math.pi;
    ref.vieworg = transform.position;
    ref.vieworg[2] += player.view_height;
    camera_height = player.view_height;
    camera_offset = if (player.mode == .normal and snapshot.ps.dk3CameraActive == 0) view_motion.offset(player.view_height, now) else 0;
    ref.vieworg[2] += camera_offset;
    if (snapshot.ps.dk3CameraActive != 0) {
        const camera = @import("core/client/interpolation.zig").camera(now);
        ref.vieworg = camera.position;
        ref.fov_x = camera.fov;
        ref.fov_y = std.math.atan(@tan(ref.fov_x * std.math.pi / 360) * @as(f32, @floatFromInt(ref.height)) / @as(f32, @floatFromInt(ref.width))) * 360 / std.math.pi;
    }
    const basis = v.basis(if (snapshot.ps.dk3CameraActive != 0) @import("core/client/interpolation.zig").camera(now).angles else v.add(v.add(v.add(view_angles, classViewOffset(now)), .{ 0, 0, psychic.roll }), @import("mechanics/client/area_effects.zig").shake(snapshot.entities[0..@intCast(snapshot.numEntities)], ref.vieworg, now)));
    ref.viewaxis[0] = basis.forward;
    ref.viewaxis[1] = v.scale(basis.right, -1);
    ref.viewaxis[2] = v.cross(ref.viewaxis[0], ref.viewaxis[1]);
    ref.areamask = snapshot.areamask;
    camera_position = ref.vieworg;
    if (engine.integer("cg_debugMover") != 0) {
        var ground_origin: v.Vec3 = @splat(0);
        for (snapshot.entities[0..@intCast(snapshot.numEntities)]) |entity| {
            if (entity.number == @as(i32, player.ground_entity) and entity.dk3World == snapshot.ps.dk3World) ground_origin = @import("engine/trajectory.zig").evaluate(entity.pos, now);
        }
        var message: [384]u8 = undefined;
        engine.print(try std.fmt.bufPrintZ(&message, "dk3 mover view: now={d} snapshot={d} command={d} ground={d} authoritative_ground={d} feet={d:.4} authoritative_feet={d:.4} brush={d:.4} camera={d:.4} offset={d:.4} velocity={d:.4}\n", .{ now, snapshot.serverTime, player.command_ms, player.ground_entity, snapshot.ps.groundEntityNum, transform.position[2], snapshot.ps.origin[2], ground_origin[2], ref.vieworg[2], camera_offset, velocity.linear[2] }));
    }
    const lightstyles = try engine.config(&game, c.CS_DK3_LIGHTSTYLES);
    try @import("mechanics/client/sky.zig").update(&game);
    ref.dk3Lightstyles = if (lightstyles.len > 0) try @import("mechanics/domain/lightstyle_table.zig").decode(lightstyles) else @splat(1);
    _ = engine.gateway.call(c.CG_R_CLEARSCENE, .{});
    @import("mechanics/client/fog.zig").submit();
    _ = engine.gateway.call(c.CG_S_CLEARLOOPINGSOUNDS, .{@as(isize, c.qfalse)});
    var weapon_end_ms: ?i64 = null;
    presentation = .{ .now = now };
    foreign_count = 0;
    for (display_entities[0..@intCast(snapshot.numEntities)]) |entity| {
        const scope = try resident_worlds.selectPresentation(@bitCast(entity.dk3World));
        defer scope.deinit();
        const owner = try resident_worlds.view(@bitCast(entity.dk3World));
        const entities = display_entities[0..@intCast(snapshot.numEntities)];
        var draw_context: render_classes.Draw = .{ .entity = entity, .entities = entities, .game = owner.game, .ref = &ref, .client = client_number, .now = now, .counters = &presentation };
        if (entity.eType == c.ET_DK3_EFFECT) {
            try @import("mechanics/client/weapon_effects.zig").draw(entity, entities, now, &ref, client_number);
            if (entity.otherEntityNum == client_number and entity.weapon == loadout.weapon) if (weapon_classes.viewEnd(entity)) |end| {
                weapon_end_ms = end;
            };
            continue;
        }
        if (entity.eType == c.ET_GENERAL and try render_classes.drawEffect(&draw_context)) continue;
        if (entity.eType == c.ET_MISSILE and try @import("mechanics/client/projectiles.zig").sprite(entity, now, &ref, &presentation)) continue;
        if (entity.eType == c.ET_MISSILE) try weapon_classes.drawMissile(.{ .entity = entity, .entities = entities, .now = now, .ref = &ref, .client = client_number });
        if (entity.eType == c.ET_DK3_ITEM and entity.dk3Team != 0) {
            try @import("mechanics/client/objectives.zig").draw(owner.game, entity, display_entities[0..@intCast(snapshot.numEntities)], client_number, now);
            continue;
        }
        if (entity.eType == c.ET_PLAYER and entity.number == client_number and entity.eFlags & c.EF_DEAD == 0) {
            try @import("mechanics/client/events.zig").loop(owner.game, entity, @import("engine/trajectory.zig").evaluate(entity.pos, now));
            continue;
        }
        var handle: c.qhandle_t = 0;
        if ((entity.solid == c.SOLID_BMODEL or (entity.eType == c.ET_MOVER and render_classes.inlineModel(entity.generic1))) and entity.modelindex > 0 and entity.modelindex < owner.inline_models.len) {
            handle = owner.inline_models[@intCast(entity.modelindex)];
        } else if (entity.eType == c.ET_PLAYER or entity.eType == c.ET_DK3_ITEM or entity.eType == c.ET_MISSILE or entity.eType == c.ET_GENERAL) handle = try @import("mechanics/client/models.zig").get(owner.game, entity.modelindex);
        if (handle == 0) continue;
        var rendered = std.mem.zeroes(c.refEntity_t);
        // The renderer owns its world numbering; the network world id only names the owner.
        rendered.dk3World = owner.render;
        rendered.hModel = handle;
        if (entity.eType == c.ET_PLAYER) rendered.customSkin = try @import("mechanics/client/models.zig").playerSkin(owner.game, entity.clientNum);
        const animation = try @import("engine/animation.zig").sample(entity, now);
        rendered.frame = animation.frame;
        rendered.oldframe = animation.oldframe;
        rendered.backlerp = animation.backlerp;
        presentation.models += 1;
        if (rendered.frame != rendered.oldframe and rendered.backlerp > 0 and rendered.backlerp < 1) {
            presentation.blended += 1;
            presentation.entity = entity.number;
            presentation.frame = rendered.frame;
            presentation.oldframe = rendered.oldframe;
            presentation.backlerp = rendered.backlerp;
        }
        rendered.reType = c.RT_MODEL;
        rendered.origin = @import("engine/trajectory.zig").evaluate(entity.pos, now);
        rendered.oldorigin = rendered.origin;
        const orientation = v.basis(@import("engine/trajectory.zig").evaluate(entity.apos, now));
        rendered.axis[0] = orientation.forward;
        rendered.axis[1] = v.scale(orientation.right, -1);
        rendered.axis[2] = v.cross(rendered.axis[0], rendered.axis[1]);
        if (entity.eType == c.ET_GENERAL and entity.angles2[0] > 0 and entity.angles2[1] > 0 and entity.angles2[2] > 0) {
            for (&rendered.axis, entity.angles2) |*axis, scale| axis.* = v.scale(axis.*, scale);
            rendered.nonNormalizedAxes = c.qtrue;
        }
        rendered.shaderRGBA = @splat(255);
        if (entity.eType == c.ET_DK3_ITEM) {
            rendered.renderfx |= c.RF_MINLIGHT | c.RF_LIGHTING_ORIGIN;
            rendered.lightingOrigin = v.add(rendered.origin, .{ 0, 0, 16 });
        }
        var model: render_classes.Model = .{ .draw = draw_context, .rendered = &rendered };
        const stone = entity.generic1 == @import("mechanics/domain/ailments.zig").stone_tag;
        if (stone) {
            rendered.shaderRGBA[3] = 179;
            rendered.skinNum = 3;
        }
        if (entity.eType == c.ET_GENERAL) try render_classes.decorate(&model);
        if (entity.eType == c.ET_MISSILE) try @import("mechanics/client/projectiles.zig").decorate(&rendered, entity, now);
        // Fading/energy models do not cast an opaque silhouette. Ordinary
        // actors, bodies, pickups, props and physical projectiles do.
        if (rendered.shaderRGBA[3] < 255) rendered.renderfx |= c.RF_NOSHADOW;
        // Converted MD3 surfaces carry ordinary/alpha/bright/alpha-bright
        // variants. Selecting alpha preserves each surface's own authored skin.
        if ((entity.eType == c.ET_GENERAL or entity.eType == c.ET_MISSILE) and rendered.shaderRGBA[3] < 255 and std.mem.endsWith(u8, try engine.config(owner.game, c.CS_MODELS + @as(usize, @intCast(entity.modelindex))), ".dkm")) rendered.skinNum = if (stone or model.bright) 3 else 1;
        if (entity.eType == c.ET_PLAYER) {
            if (entity.dk3BodyAppearance > 0) {
                const appearance: usize = @intCast(entity.dk3BodyAppearance - 1);
                if (appearance >= @import("appearance_catalog").entries.len) return error.InvalidPlayerAppearance;
                const entry = @import("appearance_catalog").entries[appearance];
                rendered.customSkin = @intCast(engine.gateway.call(c.CG_R_REGISTERSKIN, .{entry.skin.ptr}));
                try @import("mechanics/client/neural_models.zig").playerAppearance(appearance, &rendered);
            } else try @import("mechanics/client/neural_models.zig").player(owner.game, entity.clientNum, &rendered);
        } else if (entity.modelindex > 0 and entity.modelindex < c.MAX_MODELS) {
            if (try @import("mechanics/client/neural_models.zig").material(try engine.config(owner.game, c.CS_MODELS + @as(usize, @intCast(entity.modelindex))), @intCast(rendered.skinNum))) |skin| rendered.customSkin = skin;
        }
        if (entity.modelindex > 0 and entity.modelindex < c.MAX_MODELS) try @import("mechanics/client/neural_models.zig").animate(try engine.config(owner.game, c.CS_MODELS + @as(usize, @intCast(entity.modelindex))), entity, now, &rendered);
        _ = try @import("mechanics/client/ragdolls.zig").apply(entity, now, &rendered);
        @import("mechanics/client/skeletal_aim.zig").apply(entity, &rendered, now);
        try @import("mechanics/client/events.zig").loop(owner.game, entity, rendered.origin);
        _ = engine.gateway.call(c.CG_R_ADDREFENTITYTOSCENE, .{&rendered});
        if (@as(u32, @bitCast(entity.dk3World)) != resident_worlds.active_id) {
            foreign_presented[foreign_count] = @bitCast(entity.dk3Identity);
            foreign_count += 1;
        }
        if (entity.eType == c.ET_PLAYER) try @import("mechanics/client/held_weapons.zig").draw(&rendered, entity.weapon);
        if (entity.eType == c.ET_GENERAL) try render_classes.overlay(&model);
        if (entity.eType == c.ET_GENERAL and entity.generic1 > 0 and entity.generic1 <= 1000) try @import("mechanics/client/status_visuals.zig").frost(rendered, @as(f32, @floatFromInt(entity.generic1)) / 1000);
    }
    try @import("mechanics/client/ragdolls.zig").drawDetached(&resident_worlds, now);
    if (snapshot.ps.dk3CameraActive != 0) @import("mechanics/client/cinematics.zig").audio(ref.vieworg);
    @import("mechanics/client/impacts.zig").draw(now, &ref);
    @import("mechanics/client/fx_particles.zig").draw(now, &ref);
    if (player.mode == .normal and snapshot.ps.stats[c.STAT_HEALTH] > 0) try weapon_view.draw(loadout.*, character.*, &ref, client_number, now, weapon_end_ms, @import("core/domain/vector.zig").length(snapshot.ps.velocity) < 1);
    try resident_worlds.apertures(&ref);
    if (!try resident_worlds.renderPreview(&ref)) _ = engine.gateway.call(c.CG_R_RENDERSCENE, .{&ref});
    const save_picture = @import("mechanics/client/save_preview.zig");
    save_picture.update();
    const hide_hud = save_picture.hidesHud();
    if (snapshot.ps.dk3CameraActive != 0) {
        @import("mechanics/client/cinematics.zig").overlay(snapshot.ps.dk3CameraBlend, display);
    } else if (!hide_hud) {
        @import("mechanics/client/status_visuals.zig").screen(ailments.*, display);
        if (psychic.blend[3] <= 0) @import("mechanics/client/status_visuals.zig").psychic(.{ 1, 0, 0, @as(f32, @floatFromInt(snapshot.ps.damageCount)) / 255 }, display);
        @import("mechanics/client/status_visuals.zig").psychic(psychic.blend, display);
        inline for (presenters) |Class| if (@hasDecl(Class, "screen")) Class.screen(snapshot.entities[0..@intCast(snapshot.numEntities)], client_number, now, display);
        hud.column_taken = false;
        inline for (presenters) |Class| if (@hasDecl(Class, "holdsInventoryColumn")) {
            if (Class.holdsInventoryColumn()) hud.column_taken = true;
        };
        try hud.render(display, .{ .current = snapshot.ps.stats[c.STAT_HEALTH], .armor = snapshot.ps.stats[c.STAT_ARMOR] }, character.*, .{ .mask = @bitCast(snapshot.ps.dk3Keys), .quest = @bitCast(snapshot.ps.dk3Quest) }, loadout.*, &weapon_table, selected_weapon, now);
        inline for (presenters) |Class| if (@hasDecl(Class, "hud")) Class.hud(&snapshot.ps, now, display);
    }
    _ = engine.gateway.call(c.CG_S_RESPATIALIZE, .{ @as(isize, client_number), &ref.vieworg, &ref.viewaxis, @as(isize, @intFromBool(player.water_level == 3)) });
    if (hide_hud) return;
    @import("mechanics/client/messages.zig").render(hud.font, display, now);
    try @import("mechanics/client/scoreboard.zig").render(hud.font, display, &game, &snapshot.ps, now);
}
fn console() isize {
    var buffer: [128]u8 = @splat(0);
    _ = engine.gateway.call(c.CG_ARGV, .{ @as(isize, 0), &buffer, @as(isize, buffer.len) });
    const name = std.mem.sliceTo(&buffer, 0);
    if (world == null or !have_snapshot) return 0;
    if (std.mem.eql(u8, name, "dk3_runtime_render_world")) {
        resident_worlds.command() catch |err| {
            var message: [160]u8 = undefined;
            engine.print(std.fmt.bufPrintZ(&message, "dk3 render world: failed {s}\n", .{@errorName(err)}) catch unreachable);
        };
        return 1;
    }
    if (std.mem.eql(u8, name, "dk3_runtime_presentation")) {
        const character_view = bridge.readCharacter(&snapshot.ps);
        var attributes: [256]u8 = undefined;
        engine.print(std.fmt.bufPrintZ(&attributes, "dk3 character view: base={d},{d},{d},{d},{d} effective={d},{d},{d},{d},{d}\n", .{ character_view.attributes[0], character_view.attributes[1], character_view.attributes[2], character_view.attributes[3], character_view.attributes[4], character_view.attribute(.power, presentation.now), character_view.attribute(.attack, presentation.now), character_view.attribute(.speed, presentation.now), character_view.attribute(.acro, presentation.now), character_view.attribute(.vita, presentation.now) }) catch unreachable);
        @import("mechanics/client/attachments.zig").diagnostics(snapshot.entities[0..@intCast(snapshot.numEntities)], display_entities[0..@intCast(snapshot.numEntities)], snapshot.serverTime, presentation.now);
        @import("mechanics/client/neural_models.zig").diagnostics(presentation.now);
        @import("mechanics/client/ragdolls.zig").diagnostics();
        var message: [512]u8 = undefined;
        engine.print(std.fmt.bufPrintZ(&message, "dk3 view motion: now={d} height={d:.3} offset={d:.3} steps={d} pos={d:.3},{d:.3},{d:.3}\n", .{ presentation.now, camera_height, camera_offset, view_motion.steps, camera_position[0], camera_position[1], camera_position[2] }) catch unreachable);
        engine.print(std.fmt.bufPrintZ(&message, "dk3 weapon presentation: now={d} incarnation={d} weapon={d} phase={s} serial={d} frame={d} oldframe={d} backlerp={d:.4} started={d}\n", .{ weapon_view.presented_ms, weapon_view.state.incarnation orelse 0, weapon_view.state.weapon, @tagName(weapon_view.state.phase), weapon_view.state.fire_serial orelse 0, weapon_view.presented.frame, weapon_view.presented.oldframe, weapon_view.presented.backlerp, weapon_view.started_ms }) catch unreachable);
        for (foreign_presented[0..foreign_count]) |identity| engine.print(std.fmt.bufPrintZ(&message, "dk3 foreign presentation: identity={d} at={d}\n", .{ identity, presentation.now }) catch unreachable);
        engine.print(std.fmt.bufPrintZ(&message, "dk3 presentation: now={d} camera={d} models={d} blended={d} entity={d} frame={d} oldframe={d} backlerp={d:.4} snapshot={d} ions={d} lamps={d} gibs={d} chunks={d} motion_blended={d}\n", .{ presentation.now, snapshot.ps.dk3CameraActive, presentation.models, presentation.blended, presentation.entity, presentation.frame, presentation.oldframe, presentation.backlerp, snapshot.serverTime, presentation.ions, presentation.lamps, presentation.gibs, presentation.chunks, @import("core/client/interpolation.zig").blendedMotion(presentation.now) }) catch unreachable);
        return 1;
    }
    if (@import("mechanics/client/scoreboard.zig").input(name)) return 1;
    if (hud.command(name)) return 1;
    inline for (presenters) |Class| if (@hasDecl(Class, "console")) {
        if (Class.console(name, presentation.now)) return 1;
    };
    if (std.mem.eql(u8, name, "weapon")) {
        _ = engine.gateway.call(c.CG_ARGV, .{ @as(isize, 1), &buffer, @as(isize, buffer.len) });
        const id = std.fmt.parseInt(u5, std.mem.sliceTo(&buffer, 0), 10) catch return 1;
        if (@import("weapon_catalog").find(id)) |entry| if (@as(u32, @bitCast(snapshot.ps.dk3Inventory)) & (@as(u32, 1) << id) != 0) {
            if (selected_weapon == id and snapshot.ps.weapon == id) if (entry.spec.reselect_command) |command| {
                _ = engine.gateway.call(c.CG_SENDCLIENTCOMMAND, .{command.ptr});
                weapon_view.reselect();
            };
            selected_weapon = id;
        };
        return 1;
    }
    if (std.mem.eql(u8, name, "weapnext") or std.mem.eql(u8, name, "weapprev")) {
        const direction: i32 = if (std.mem.eql(u8, name, "weapnext")) 1 else -1;
        var id = selected_weapon;
        for (0..28) |_| {
            id = @mod(id - 1 + direction, 28) + 1;
            const entry = @import("weapon_catalog").find(@intCast(id)).?;
            if (entry.spec.auto_select and @as(u32, @bitCast(snapshot.ps.dk3Inventory)) & (@as(u32, 1) << @as(u5, @intCast(id))) != 0) {
                selected_weapon = id;
                break;
            }
        }
        return 1;
    }
    if (!std.mem.eql(u8, name, "viewpos")) return 0;
    const transform = world.?.get(predicted.?, data.Transform) catch return 0;
    var message: [200]u8 = undefined;
    engine.print(std.fmt.bufPrintZ(&message, "zig viewpos: {d:.3} {d:.3} {d:.3}, angles {d:.2} {d:.2} {d:.2}\n", .{ transform.position[0], transform.position[1], transform.position[2], view_angles[0], view_angles[1], view_angles[2] }) catch unreachable);
    return 1;
}
fn failure(err: anyerror) noreturn {
    var message: [160]u8 = undefined;
    engine.fatal(std.fmt.bufPrintZ(&message, "Zig client: {s}", .{@errorName(err)}) catch unreachable);
}
export fn vmMain(command: c_int, arg0: isize, arg1: isize, arg2: isize, arg3: isize, arg4: isize, arg5: isize, arg6: isize, arg7: isize, arg8: isize, arg9: isize, arg10: isize, arg11: isize) callconv(.c) isize {
    _ = .{ arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 };
    switch (command) {
        c.CG_INIT => init(@intCast(arg0), @intCast(arg1), @intCast(arg2), @intCast(arg3)) catch |err| failure(err),
        c.CG_SHUTDOWN => shutdown(),
        c.CG_DRAW_ACTIVE_FRAME => draw(@intCast(arg0)) catch |err| failure(err),
        c.CG_CONSOLE_COMMAND => return console(),
        c.CG_CROSSHAIR_PLAYER, c.CG_LAST_ATTACKER => return -1,
        else => {},
    }
    return 0;
}
const presenters = @import("game/client/client_classes.zig").presenters;
/// The view angle offsets the client classes add (`viewOffset`).
fn classViewOffset(now: i64) @import("core/domain/vector.zig").Vec3 {
    var total: @import("core/domain/vector.zig").Vec3 = @splat(0);
    inline for (presenters) |Class| if (@hasDecl(Class, "viewOffset")) {
        total = @import("core/domain/vector.zig").add(total, Class.viewOffset(now));
    };
    return total;
}
