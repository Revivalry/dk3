// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Scripted co-op player bot for headless end-to-end verification. A sandboxed
//! Lua route (`dk3_coop_script`) chooses actions; this driver performs them as
//! the single-player client with ordinary user commands and client commands,
//! and prints every outcome as a `dk3 coop:` evidence line. It never places the
//! player, grants items or activates entities directly.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const c = abi.c;
const v = @import("../../core/domain/vector.zig");
const nav = @import("../../core/domain/navigation.zig");
const route = @import("../domain/coop_route.zig");
const skill = @import("../domain/bot_skill.zig");
const combat = @import("../domain/bot_combat.zig");
const motor_module = @import("coop_motor.zig");
const targets = @import("coop_targets.zig");
const scripting = @import("coop_script.zig");
const link_module = @import("coop_link.zig");
const routes = @import("bot_routes.zig");
const survival = @import("bot_survival.zig");
const properties = @import("properties.zig");
const player_state = @import("../player_state.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const Clients = @import("clients.zig").Clients;
const catalog = @import("actor_catalog");
pub const Frame = motor_module.Frame;
const hull_mins: v.Vec3 = .{ -15, -15, -24 };
const hull_maxs: v.Vec3 = .{ 15, 15, 32 };
/// Movement actions fail when the bot stops approaching its goal for this long.
const stall_ms = 25_000;
/// How far ahead of itself one engaged frame pays an action's deadline, so the
/// action outlives the shot being traded.
const fight_stand_ms: i64 = 5_000;
/// Engine spawn runs three settle frames and reconnects kept clients before the
/// fourth; a bot allocated earlier would be dropped by that reconnection pass.
const settle_frames = 4;

fn surfaceStance(frame: Frame, found: targets.Resolved, offset: v.Vec3) v.Vec3 {
    if (found.entity) |entity| {
        const body = frame.world.get(entity, data.Body) catch return v.add(found.point, offset);
        const pose = frame.world.get(entity, data.Transform) catch return v.add(found.point, offset);
        const local: v.Vec3 = .{ (body.mins[0] + body.maxs[0]) / 2 + offset[0], (body.mins[1] + body.maxs[1]) / 2 + offset[1], body.maxs[2] + offset[2] };
        var point = @import("../domain/poses.zig").point(local, .{}, .{ .position = pose.position, .angles = pose.angles });
        point[2] += -hull_mins[2] + 1;
        return point;
    }
    return v.add(.{ found.point[0], found.point[1], found.maxs[2] - hull_mins[2] + 1 }, offset);
}

const Running = struct {
    action: route.Action,
    started_ms: i64,
    deadline_ms: i64,
    stepped_ms: i64,
    progress: route.Progress = .{},
    target: u32 = 0,
    signature: u64 = 0,
    approach: ?v.Vec3 = null,
    approach_ms: i64 = 0,
    pressed_ms: ?i64 = null,
    presses: u8 = 0,
    contact_ms: ?i64 = null,
    /// A held fight whose stand never found the prey: the tether is
    /// dropped and the bot closes on the enemy outright.
    hold_closed: bool = false,
    /// How long a hunt waits without approaching its prey before giving up on
    /// it. Full at first; once one enemy in this hunt has proved out of reach,
    /// the rest of the hunt is judged by a shorter window, because a room
    /// whose guards stand behind rails the route cannot cross costs a full
    /// window per guard (e1m2b's pipe room: one prey spent all 30 s of its
    /// `clear` wobbling at a rail, and the walk to the chute then ran out).
    hunt_stall_ms: i64 = stall_ms,
    phase: u8 = 0,
    /// Where the bot stood when the action began; held fights tether here.
    home: v.Vec3 = @splat(0),
    /// A precise corridor resumes from its safe footing after a fight or
    /// health detour, rather than cutting directly back through another floor.
    corridor_return: ?v.Vec3 = null,
    returning_to_corridor: bool = false,
    /// Continuous absence of any navigation route since this time.
    no_route_ms: ?i64 = null,
    /// The authored control the motor detoured to when progress was last reset.
    watched: u32 = 0,
    /// The selector matched nothing when the action began.
    missing: bool = false,
    anchor: v.Vec3 = @splat(0),
    tracked: [64]u32 = @splat(0),
    tracked_count: usize = 0,
    /// Cautious move: when the enemy was last engaged.
    stand_ms: i64 = 0,
    /// The aggressor being dealt with: since when, cover, and firing stand.
    engagement: survival.Engagement = .{},
    /// How much of the action's own allowance a fight has already spent on
    /// pushing its deadline; see the push in `standGround`.
    fight_ms: i64 = 0,
    /// Out of an unseen shooter's line of fire while holding.
    cover: ?v.Vec3 = null,
    cover_until_ms: i64 = 0,
    engaged_ms: i64 = 0,
    /// A trade of fire being measured: since when, the player's health and
    /// the prey's then (losing it badly sends the player behind cover).
    trade_ms: i64 = 0,
    trade_health: i32 = 0,
    trade_prey: u32 = 0,
    trade_prey_health: i32 = 0,
    /// After a stand that ran out its time, keep moving until this time.
    stand_after_ms: i64 = 0,
    detail: [192]u8 = undefined,
    fn say(self: *Running, comptime format: []const u8, args: anytype) []const u8 {
        return std.fmt.bufPrint(&self.detail, format, args) catch self.detail[0..0];
    }
};
const Evaluation = struct { intent: motor_module.Intent = .{}, result: route.Result = .running, goal: ?v.Vec3 = null };
pub const Driver = struct {
    enabled: bool = false,
    index: ?u16 = null,
    rendered: bool = false,
    frames: u32 = 0,
    load_pending_ms: ?i64 = null,
    script: ?scripting.Script = null,
    level: route.Name = .{},
    visit: u32 = 0,
    level_started_ms: i64 = 0,
    body: enum { none, running, returned } = .none,
    running: ?Running = null,
    outcome: ?scripting.Outcome = null,
    outcome_text: [192]u8 = undefined,
    state: enum { playing, finished, failed } = .playing,
    motor: motor_module.Motor = .{},
    link: link_module.Link = .{},
    report: motor_module.Report = .{},
    status_ms: i64 = 0,
    died_ms: ?i64 = null,
    reload_ms: i64 = 0,
    reloads: u32 = 0,
    /// The latest save slot the route asked for (a checkpoint), the fallback
    /// when no autosave can be loaded after a companion's death.
    last_save: [64]u8 = @splat(0),
    quit_ms: ?i64 = null,
    deaths_allowed: i64 = 0,
    level_deaths_allowed: i64 = 0,
    actions: u32 = 0,
    /// Stage the running level body declared last (0 before its first stage).
    stage: u32 = 0,
    /// Diagnostic count; restoration replans the stage from the saved world.
    stage_actions: u32 = 0,
    /// Controls this visit has operated (use/shoot/touch that reacted); the
    /// planner never re-operates them, since many toggle back.
    operated: [64]u32 = @splat(0),
    operated_count: usize = 0,
    develop_ms: i64 = 0,
    hurt_revision: u32 = 0,
    /// When a hostile last hurt the player, and which.
    fired_on_ms: i64 = -100_000,
    attacker: u32 = 0,
    /// Aggressors let be for now (unreachable, unhurt or unfinished).
    ignoring: survival.Ignore = .{},
    /// Hostiles an area clear gave up on: a chase that reached nothing for its
    /// whole progress window, against an enemy that never touched the player,
    /// means it lies out of reach (across a drop, a shut door, the level's own
    /// one-way). A player clears the room he is in and goes on. Authored kills
    /// never give up on the target the route named.
    hunt_let_be: survival.Ignore = .{},
    attribute_cursor: usize = 0,
    detour: survival.Detour = .{},

    /// Called at every module initialization. Run-wide counters live in cvars
    /// because the engine unloads the module on each full map load.
    pub fn configure(self: *Driver) void {
        self.deinit();
        engine.register("dk3_coop_script", "", 0);
        engine.register("dk3_coop_render", "0", 0);
        engine.register("dk3_coop_fast", "0", 0);
        engine.register("dk3_coop_fast_frame_ms", "16", 0);
        engine.register("dk3_coop_skill", "10", 0);
        engine.register("dk3_coop_status_ms", "1000", 0);
        engine.register("dk3_coop_quit", "1", 0);
        engine.register("dk3_coop_deaths", "0", 0);
        engine.register("dk3_coop_level", "", 0);
        engine.register("dk3_coop_load", "", 0);
        engine.register("dk3_coop_checkpoint", "", 0);
        engine.register("dk3_coop_saved_checkpoint", "", 0);
        engine.register("dk3_coop_resume_checkpoint", "", 0);
        engine.register("dk3_coop_last_save", "", 0);
        engine.register("dk3_coop_level_deaths", "", 0);
        var path: [c.MAX_QPATH]u8 = @splat(0);
        _ = engine.gateway.call(c.G_CVAR_VARIABLE_STRING_BUFFER, .{ @as([*:0]const u8, "dk3_coop_script"), &path, @as(isize, path.len) });
        const name = std.mem.sliceTo(&path, 0);
        if (name.len == 0) return;
        if (engine.integer("g_gametype") != c.GT_SINGLE_PLAYER or engine.integer("dk3_runtime_probe") != 2) {
            engine.print("dk3 coop: event=fail reason=\"the co-op bot drives the single-player campaign (g_gametype 2, dk3_runtime_probe 2)\"\n");
            return;
        }
        self.enabled = true;
        self.rendered = engine.integer("dk3_coop_render") != 0;
        self.motor.level = skill.normalize(engine.integer("dk3_coop_skill"));
        self.script = scripting.Script.load(name) catch {
            self.fail(0, "route script did not load");
            return;
        };
        self.deaths_allowed = self.script.?.option("deaths");
        self.level_deaths_allowed = self.script.?.option("level_deaths");
        // Retries from one checkpoint replay deterministically; vary the bot's
        // own choices per attempt so a retry is a new attempt, reproducibly.
        self.motor.vary(@intCast(@max(0, engine.integer("dk3_coop_deaths"))));
        var text: [256]u8 = undefined;
        engine.print(std.fmt.bufPrintZ(&text, "dk3 coop: event=loaded script={s} skill={d} deaths_allowed={d} deaths_used={d}\n", .{ name, self.motor.level, self.deaths_allowed, engine.integer("dk3_coop_deaths") }) catch unreachable);
    }
    pub fn deinit(self: *Driver) void {
        if (self.script) |*value| value.deinit();
        self.link.deinit();
        self.* = .{};
    }
    /// Allocates the single-player client once the spawn has settled. The
    /// caller runs the ordinary slot-0 begin path for the returned slot.
    pub fn admit(self: *Driver, occupied: bool, now: i64) ?u16 {
        if (self.quit_ms) |at| if (now >= at) {
            self.quit_ms = null;
            _ = engine.gateway.call(c.G_SEND_CONSOLE_COMMAND, .{ @as(isize, c.EXEC_APPEND), @as([*:0]const u8, "quit\n") });
        };
        if (!self.enabled) return null;
        self.frames +|= 1;
        if (self.rendered) {
            // The local engine resets cheat-tagged timing cvars on gamestate
            // admission. Keep the server's normal 50 ms simulation ticks, but
            // allow client/fragment transport to advance between server ticks.
            if (engine.integer("dk3_coop_fast") != 0) {
                const frame_ms = std.math.clamp(engine.integer("dk3_coop_fast_frame_ms"), 8, 50);
                if (engine.integer("fixedtime") != frame_ms) {
                    var value: [16]u8 = undefined;
                    _ = engine.gateway.call(c.G_CVAR_SET, .{ @as([*:0]const u8, "fixedtime"), (std.fmt.bufPrintZ(&value, "{d}", .{frame_ms}) catch unreachable).ptr });
                }
                if (engine.integer("timedemo") != 1) _ = engine.gateway.call(c.G_CVAR_SET, .{ @as([*:0]const u8, "timedemo"), @as([*:0]const u8, "1") });
            }
            if (occupied and self.index == null and self.frames >= settle_frames and self.state != .failed) {
                self.index = 0;
                engine.print("dk3 coop: event=admitted slot=0 rendered=1\n");
            }
            return null;
        }
        if (occupied or self.frames < settle_frames or self.state == .failed) return null;
        const allocated = engine.gateway.call(c.G_BOT_ALLOCATE_CLIENT, .{});
        if (allocated != 0) {
            if (allocated > 0) _ = engine.gateway.call(c.G_BOT_FREE_CLIENT, .{allocated});
            self.fail(now, "the co-op bot needs the free single-player client slot 0");
            return null;
        }
        var info: [256]u8 = undefined;
        const text = std.fmt.bufPrintZ(&info, "\\name\\Co-op Bot\\model\\hiro\\dk3_coop\\1\\dk3_runtime_build\\{s}", .{@import("../player_state.zig").version}) catch unreachable;
        _ = engine.gateway.call(c.G_SET_USERINFO, .{ @as(isize, 0), text.ptr });
        self.index = 0;
        engine.print("dk3 coop: event=admitted slot=0\n");
        return 0;
    }
    /// Network-client duties; also runs while the world is held for admission.
    pub fn pump(self: *Driver) void {
        if (!self.enabled or self.rendered) return;
        const index = self.index orelse return;
        self.link.pump(index);
    }

    /// End of every frame: answer commands queued during it, and mark the bot's
    /// projection so the engine builds but never transmits its snapshots (a bot
    /// has no network channel). Ordinary publication rewrites the flags.
    pub fn finishFrame(self: *Driver, projections: []abi.EntityProjection) void {
        self.pump();
        if (!self.enabled or self.rendered) return;
        if (self.index) |index| projections[index].shared.svFlags |= c.SVF_BOT;
    }
    pub fn acceptsInput(self: *const Driver, index: u16) bool {
        return !self.enabled or !self.rendered or index != 0 or @import("bot_input.zig").submitting == index;
    }
    pub fn step(self: *Driver, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, clients: *Clients, service: nav.Service, gates: *@import("navigation_gates.zig").State, map: []const u8, now: i64) !void {
        if (!self.enabled) return;
        const index = self.index orelse return;
        const entity = clients.entities[index] orelse return;
        const frame: Frame = .{ .world = world, .slots = slots, .projections = projections, .clients = clients, .service = service, .index = index, .entity = entity, .now = now, .gates = gates };
        if (self.link.failure) |err| {
            var text: [96]u8 = undefined;
            self.fail(now, std.fmt.bufPrint(&text, "world publication rejected: {s}", .{@errorName(err)}) catch "world publication rejected");
        }
        if (self.state != .playing) {
            self.report = try motor_module.drive(&self.motor, frame, .{});
            return;
        }
        if (try self.loadRequested(frame)) return;
        if (!std.mem.eql(u8, map, self.level.slice())) try self.enter(frame, map);
        const player = (try world.get(entity, data.Player)).*;
        const health = (try world.get(entity, data.Health)).*;
        if (@import("../domain/checkpoint.zig").requiresRestart(player.mode, health.current)) {
            try self.dead(frame, health.current > 0);
            return;
        }
        if (self.died_ms != null) {
            // Restored in place from the death checkpoint: replay this level body.
            self.died_ms = null;
            self.event(now, "restored", "death checkpoint restored in place");
            try self.restart(frame, true);
        }
        try self.develop(frame);
        try self.wounds(frame);
        var evaluation: Evaluation = .{};
        var budget: usize = 16;
        while (budget > 0) : (budget -= 1) {
            if (self.running == null) {
                if (self.body != .running) break;
                const query: scripting.Query = .{ .frame = frame, .map = self.level.slice(), .visit = self.visit, .stage = &self.stage, .stage_actions = &self.stage_actions, .operated = self.operated[0..self.operated_count] };
                const outcome = self.outcome;
                self.outcome = null;
                switch (self.script.?.advance(&query, outcome)) {
                    .action => |action| if (action.op == .finish) {
                        self.finish(now, action.slot.slice());
                        return;
                    } else self.begin(frame, action),
                    .returned => {
                        self.body = .returned;
                        self.event(now, "level_done", self.level.slice());
                        break;
                    },
                    .failed => {
                        self.fail(now, self.script.?.message());
                        return;
                    },
                }
                if (self.state != .playing) return;
            }
            const running = &self.running.?;
            evaluation = try self.evaluate(frame, running, player);
            switch (evaluation.result) {
                .running => break,
                .done => |detail| self.complete(now, true, detail),
                .failed => |detail| self.complete(now, false, detail),
            }
        }
        if (self.state != .playing) return;
        try self.survive(frame, &evaluation);
        self.report = try motor_module.drive(&self.motor, frame, evaluation.intent);
        if (now >= self.status_ms) {
            // Route authoring may ask for a finer trace (dk3_coop_status_ms).
            const interval = engine.integer("dk3_coop_status_ms");
            self.status_ms = now + if (interval > 0) interval else 1000;
            try self.status(frame, evaluation.goal);
        }
    }

    /// Development restart: `dk3_coop_load <slot>` loads an ordinary save once
    /// the bot is in the world; the save's map is then entered as a resumption.
    fn loadRequested(self: *Driver, frame: Frame) !bool {
        if (self.load_pending_ms) |since| {
            if (frame.now - since > 15_000) self.fail(frame.now, "requested save did not finish loading");
            self.report = try motor_module.drive(&self.motor, frame, .{});
            return true;
        }
        var slot: [64]u8 = @splat(0);
        _ = engine.gateway.call(c.G_CVAR_VARIABLE_STRING_BUFFER, .{ @as([*:0]const u8, "dk3_coop_load"), &slot, @as(isize, slot.len) });
        const name = std.mem.sliceTo(&slot, 0);
        if (name.len == 0) return false;
        const player = (try frame.world.get(frame.entity, data.Player)).*;
        if (player.mode != .normal or @import("cinematics.zig").active(frame.world)) {
            self.report = try motor_module.drive(&self.motor, frame, .{});
            return true;
        }
        var command: [96]u8 = undefined;
        const text = try std.fmt.bufPrintZ(&command, "load {s}", .{name});
        _ = engine.gateway.call(c.G_CVAR_SET, .{ @as([*:0]const u8, "dk3_coop_load"), @as([*:0]const u8, "") });
        self.event(frame.now, "load", text);
        self.load_pending_ms = frame.now;
        link_module.client(frame.index, text);
        return true;
    }
    /// A queued load must commit before any route can act on its world.
    pub fn worldRestored(self: *Driver) void {
        if (self.load_pending_ms == null) return;
        self.load_pending_ms = null;
        self.level = .{};
        self.running = null;
        self.outcome = null;
        self.body = .none;
        self.motor.reset();
    }
    /// Evidence of every hit taken: attacker identity and class, damage, health.
    fn wounds(self: *Driver, frame: Frame) !void {
        const hurt = (try frame.world.get(frame.entity, data.Hurt)).*;
        if (hurt.revision == self.hurt_revision) return;
        self.hurt_revision = hurt.revision;
        var text: [192]u8 = undefined;
        self.event(frame.now, "hurt", try std.fmt.bufPrint(&text, "amount={d} health={d} source={d} class={s} weapon={d}", .{ hurt.amount, (try frame.world.get(frame.entity, data.Health)).current, hurt.source, className(frame.world, hurt.source), hurt.weapon }));
        // Its own bolt came back (ion bolts bounce): stop firing into that
        // wall for a moment rather than keep hitting itself.
        if (hurt.amount > 0 and hurt.source == try frame.world.persistentId(frame.entity)) self.motor.hold_fire_until = frame.now + 1500;
        // Hit by a hostile: travel stops to shoot back (`standGround`).
        if (hurt.amount > 0) if (frame.world.find(hurt.source)) |source| if (frame.world.get(source, data.Actor) catch null) |actor| if (route.hostile(catalog.entries[actor.definition].kind)) {
            self.fired_on_ms = frame.now;
            self.attacker = hurt.source;
        };
    }
    /// Spend earned attribute points as they arrive, like a player levelling up.
    fn develop(self: *Driver, frame: Frame) !void {
        if (frame.now < self.develop_ms) return;
        self.develop_ms = frame.now + 1000;
        const character = (try frame.world.get(frame.entity, data.Character)).*;
        if (character.points <= 0) return;
        // Damage first (what ends boss fights), then rate of fire and health.
        const order = [_]@import("../domain/character.zig").Attribute{ .power, .attack, .vita, .speed, .acro };
        for (order) |attribute| {
            if (character.attributes[@intFromEnum(attribute)] >= 5) continue;
            var command: [32]u8 = undefined;
            link_module.client(frame.index, try std.fmt.bufPrintZ(&command, "attribute {s}", .{@tagName(attribute)}));
            var text: [96]u8 = undefined;
            self.event(frame.now, "develop", try std.fmt.bufPrint(&text, "attribute={s} level={d} points={d}", .{ @tagName(attribute), character.level, character.points }));
            return;
        }
    }
    /// Badly hurt: detour to the nearest reachable health pickup in view range
    /// before continuing, still fighting on the way. Use/shoot/ride keep focus.
    fn survive(self: *Driver, frame: Frame, evaluation: *Evaluation) !void {
        if (self.running == null) return;
        const running = &self.running.?;
        switch (running.action.op) {
            .move, .touch, .pickup, .kill, .exit, .frame, .wait => {},
            else => return,
        }
        // A held position or a precise straight segment is the route's
        // decision; never detour out of it.
        if (running.action.hold or (running.action.direct and !running.action.cautious) or evaluation.intent.leash != null or (evaluation.intent.direct and !running.action.cautious)) return;
        const world = frame.world;
        const health = (try world.get(frame.entity, data.Health)).*;
        const position = (try world.get(frame.entity, data.Transform)).position;
        const query: survival.Detour.Query = .{ .world = world, .service = frame.service, .slot = frame.index, .position = position, .health = health, .now = frame.now, .rise = if (running.action.direct) 32 else 128 };
        // No progress, or the way to it is shut and the motor went for a
        // door's control: the detour is not worth it.
        if (try self.detour.current(query, self.report.control != 0)) |point| {
            if (running.action.direct and running.corridor_return == null) running.corridor_return = try corridorPoint(frame, position);
            evaluation.intent.destination = point;
            evaluation.intent.direct = false;
            return;
        }
        // Waiting is the route's decision to stay (for a timed door, say).
        if (running.action.op == .frame or running.action.op == .wait) return;
        const found = try self.detour.choose(query) orelse return;
        if (running.action.direct and running.corridor_return == null) running.corridor_return = try corridorPoint(frame, position);
        var text: [96]u8 = undefined;
        self.event(frame.now, "detour", std.fmt.bufPrint(&text, "health={d} pickup={d} distance={d:.0}", .{ health.current, found.id, found.distance }) catch "health");
    }
    fn enter(self: *Driver, frame: Frame, map: []const u8) !void {
        const previous = self.level;
        if (self.running) |*running| {
            if (running.action.op == .exit) {
                self.complete(frame.now, true, running.say("travelled to {s}", .{map}));
            } else self.event(frame.now, "abandoned", @tagName(running.action.op));
        }
        self.running = null;
        self.outcome = null;
        self.level = route.Name.from(map) catch return error.InvalidMapName;
        self.motor.reset();
        // A fresh module that finds its own last level in the run cvar resumes
        // after a full map load (death checkpoint or save); otherwise it arrived.
        var last: [64]u8 = @splat(0);
        _ = engine.gateway.call(c.G_CVAR_VARIABLE_STRING_BUFFER, .{ @as([*:0]const u8, "dk3_coop_level"), &last, @as(isize, last.len) });
        const resumed = previous.empty() and std.mem.eql(u8, std.mem.sliceTo(&last, 0), map);
        var cvar: [96]u8 = undefined;
        const visits_name = try std.fmt.bufPrintZ(&cvar, "dk3_coop_visit_{s}", .{map});
        self.visit = @intCast(@max(0, engine.integer(visits_name)));
        if (!resumed) {
            self.visit += 1;
            var value: [16]u8 = undefined;
            _ = engine.gateway.call(c.G_CVAR_SET, .{ visits_name.ptr, (try std.fmt.bufPrintZ(&value, "{d}", .{self.visit})).ptr });
        }
        var level_value: [80]u8 = undefined;
        _ = engine.gateway.call(c.G_CVAR_SET, .{ @as([*:0]const u8, "dk3_coop_level"), (try std.fmt.bufPrintZ(&level_value, "{s}", .{map})).ptr });
        var text: [160]u8 = undefined;
        self.event(frame.now, "level", try std.fmt.bufPrint(&text, "map={s} visit={d} resumed={d} from={s}", .{ map, self.visit, @intFromBool(resumed), if (previous.empty()) "-" else previous.slice() }));
        self.level_started_ms = frame.now;
        try self.restart(frame, resumed);
    }
    fn restart(self: *Driver, frame: Frame, resumed: bool) !void {
        self.stage = 0;
        self.stage_actions = 0;
        self.operated_count = 0;
        self.running = null;
        self.outcome = null;
        self.motor.reset();
        self.body = .none;
        if (try self.script.?.begin(self.level.slice(), self.visit, resumed)) {
            self.body = .running;
        } else {
            var text: [96]u8 = undefined;
            self.fail(frame.now, try std.fmt.bufPrint(&text, "route has no level body for map {s}", .{self.level.slice()}));
        }
    }
    fn dead(self: *Driver, frame: Frame, companion_loss: bool) !void {
        if (self.died_ms == null) {
            self.died_ms = frame.now;
            self.reloads = 0;
            const used = engine.integer("dk3_coop_deaths") + 1;
            var value: [16]u8 = undefined;
            _ = engine.gateway.call(c.G_CVAR_SET, .{ @as([*:0]const u8, "dk3_coop_deaths"), (try std.fmt.bufPrintZ(&value, "{d}", .{used})).ptr });
            // Per-level count survives module reloads in a "map count" cvar.
            var previous: [80]u8 = @splat(0);
            _ = engine.gateway.call(c.G_CVAR_VARIABLE_STRING_BUFFER, .{ @as([*:0]const u8, "dk3_coop_level_deaths"), &previous, @as(isize, previous.len) });
            var words = std.mem.tokenizeScalar(u8, std.mem.sliceTo(&previous, 0), ' ');
            const same = std.mem.eql(u8, words.next() orelse "", self.level.slice());
            const in_level = (if (same) std.fmt.parseInt(i64, words.next() orelse "0", 10) catch 0 else 0) + 1;
            var level_value: [96]u8 = undefined;
            _ = engine.gateway.call(c.G_CVAR_SET, .{ @as([*:0]const u8, "dk3_coop_level_deaths"), (try std.fmt.bufPrintZ(&level_value, "{s} {d}", .{ self.level.slice(), in_level })).ptr });
            const pose = (try frame.world.get(frame.entity, data.Transform)).*;
            const hurt = (try frame.world.get(frame.entity, data.Hurt)).*;
            var text: [256]u8 = undefined;
            self.level_deaths_allowed = self.script.?.optionFor("level_deaths", self.level.slice());
            self.event(frame.now, "death", try std.fmt.bufPrint(&text, "deaths={d} level_deaths={d} allowed={d}/{d} op={s} pos={d:.0},{d:.0},{d:.0} source={d} class={s} weapon={d} companion_loss={d}", .{ used, in_level, self.level_deaths_allowed, self.deaths_allowed, if (self.running) |running| @tagName(running.action.op) else "-", pose.position[0], pose.position[1], pose.position[2], hurt.source, className(frame.world, hurt.source), hurt.weapon, @intFromBool(companion_loss) }));
            if (in_level > self.level_deaths_allowed or (self.deaths_allowed > 0 and used > self.deaths_allowed)) {
                self.fail(frame.now, "the player died beyond the route's death allowance");
                return;
            }
            self.running = null;
        }
        // Ordinary recovery: attack requests the authored death checkpoint. A
        // companion loss leaves health intact, so load the latest autosave.
        if (companion_loss and frame.now - self.died_ms.? > 6000 and frame.now >= self.reload_ms) {
            self.reload_ms = frame.now + 10000;
            self.reloads += 1;
            // The route's latest checkpoint (or this map's arrival save), then
            // the save the run resumed from and the autosave (which may be a
            // map behind): any of them may not exist.
            if (self.last_save[0] == 0) _ = engine.gateway.call(c.G_CVAR_VARIABLE_STRING_BUFFER, .{ @as([*:0]const u8, "dk3_coop_last_save"), &self.last_save, @as(isize, self.last_save.len) });
            // The route's latest checkpoint, of this level or (when this
            // level's arrival was too hurt to save) the one before: a
            // player reloads the last good save, not the hurt arrival.
            if (!std.mem.startsWith(u8, std.mem.sliceTo(&self.last_save, 0), "coop-")) self.last_save = @splat(0);
            const slot = std.mem.sliceTo(&self.last_save, 0);
            var command: [96]u8 = undefined;
            // The stage the loaded save resumes at: the checkpoint's own, the
            // resumed save's (as the run was started), else the arrival's
            // (none yet) — never what an earlier choice left behind, nor the
            // stage of a save that was missing and so never loaded.
            var value: [96]u8 = @splat(0);
            const recorded: ?[*:0]const u8 = switch (self.reloads % 4) {
                1, 2 => if (slot.len > 0) "dk3_coop_saved_checkpoint" else null,
                3 => "dk3_coop_resume_checkpoint",
                else => null,
            };
            if (recorded) |name| _ = engine.gateway.call(c.G_CVAR_VARIABLE_STRING_BUFFER, .{ name, &value, @as(isize, value.len) });
            if (value[0] == 0) _ = try std.fmt.bufPrintZ(&value, "{s} 0 0", .{self.level.slice()});
            _ = engine.gateway.call(c.G_CVAR_SET, .{ @as([*:0]const u8, "dk3_coop_checkpoint"), @as([*:0]const u8, @ptrCast(&value)) });
            link_module.client(frame.index, switch (self.reloads % 4) {
                1, 2 => if (slot.len > 0) try std.fmt.bufPrintZ(&command, "load {s}", .{slot}) else try std.fmt.bufPrintZ(&command, "load coop-{s}", .{self.level.slice()}),
                3 => "load coop-resume",
                else => "load autosave",
            });
        }
        self.report = try motor_module.drive(&self.motor, frame, .{ .attack_when_dead = frame.now - self.died_ms.? > 4500 });
    }

    fn begin(self: *Driver, frame: Frame, action: route.Action) void {
        self.actions += 1;
        const quiet = action.op == .frame;
        const pose = (frame.world.get(frame.entity, data.Transform) catch unreachable).*;
        self.running = .{ .action = action, .started_ms = frame.now, .deadline_ms = frame.now + action.timeout_ms, .stepped_ms = frame.now, .anchor = action.around orelse pose.position, .home = pose.position };
        // A detour to a door's control belonged to the previous action's goal.
        self.motor.route = .{};
        self.motor.control = null;
        if (quiet) return;
        var text: [192]u8 = undefined;
        self.event(frame.now, "action", describe(&text, action));
    }
    fn complete(self: *Driver, now: i64, ok: bool, detail: []const u8) void {
        const running = self.running orelse return;
        const length = @min(detail.len, self.outcome_text.len);
        std.mem.copyForwards(u8, self.outcome_text[0..length], detail[0..length]);
        self.outcome = .{ .ok = ok, .detail = self.outcome_text[0..length] };
        if (ok and running.action.op == .frame) {
            self.running = null;
            return;
        }
        // A save is not progress a restored world reflects (it may complete
        // after the save it requested was written).
        if (running.action.op != .save) self.stage_actions += 1;
        switch (running.action.op) {
            .use, .shoot, .touch => if (ok and running.target != 0 and self.operated_count < self.operated.len and
                std.mem.indexOfScalar(u32, self.operated[0..self.operated_count], running.target) == null)
            {
                self.operated[self.operated_count] = running.target;
                self.operated_count += 1;
            },
            else => {},
        }
        var text: [320]u8 = undefined;
        const line = std.fmt.bufPrintZ(&text, "dk3 coop: t={d} event={s} op={s} ms={d} detail=\"{s}\"\n", .{ now, if (ok) "done" else "failed", @tagName(running.action.op), now - running.started_ms, self.outcome_text[0..length] }) catch return;
        engine.print(line);
        self.running = null;
    }
    fn fail(self: *Driver, now: i64, reason: []const u8) void {
        if (self.state == .failed) return;
        self.state = .failed;
        var text: [640]u8 = undefined;
        engine.print(std.fmt.bufPrintZ(&text, "dk3 coop: t={d} event=fail map={s} reason=\"{s}\"\n", .{ now, self.level.slice(), reason[0..@min(reason.len, 512)] }) catch unreachable);
        if (engine.integer("dk3_coop_quit") != 0) self.quit_ms = now + 500;
    }
    /// A save admitted as the death checkpoint records which
    /// stage of which level it captured so a restoration resumes there.
    pub fn checkpointSaved(self: *Driver, slot: []const u8) void {
        if (!self.enabled or self.level.empty()) return;
        if (self.running) |*running| if (running.action.op == .save and std.mem.eql(u8, running.action.slot.slice(), slot)) {
            running.phase = 2;
        };
        var value: [96]u8 = undefined;
        const text = std.fmt.bufPrintZ(&value, "{s} {d} {d}", .{ self.level.slice(), self.stage, self.stage_actions }) catch return;
        _ = engine.gateway.call(c.G_CVAR_SET, .{ @as([*:0]const u8, "dk3_coop_checkpoint"), text.ptr });
        // Kept apart for a later reload of that save after another one.
        _ = engine.gateway.call(c.G_CVAR_SET, .{ @as([*:0]const u8, "dk3_coop_saved_checkpoint"), text.ptr });
    }
    /// A driver defect ends the run with evidence instead of stopping the server.
    pub fn crash(self: *Driver, err: anyerror, now: i64) void {
        if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace);
        var text: [96]u8 = undefined;
        self.fail(now, std.fmt.bufPrint(&text, "driver error {s}", .{@errorName(err)}) catch "driver error");
    }
    fn event(self: *Driver, now: i64, kind: []const u8, detail: []const u8) void {
        _ = self;
        var text: [512]u8 = undefined;
        engine.print(std.fmt.bufPrintZ(&text, "dk3 coop: t={d} event={s} detail=\"{s}\"\n", .{ now, kind, detail[0..@min(detail.len, 400)] }) catch return);
    }
    fn finish(self: *Driver, now: i64, summary: []const u8) void {
        if (self.state != .playing) return;
        self.state = .finished;
        var text: [512]u8 = undefined;
        engine.print(std.fmt.bufPrintZ(&text, "dk3 coop: t={d} event=finish map={s} actions={d} deaths={d} detail=\"{s}\"\n", .{ now, self.level.slice(), self.actions, engine.integer("dk3_coop_deaths"), summary }) catch unreachable);
        if (engine.integer("dk3_coop_quit") != 0) self.quit_ms = now + 500;
    }
    fn status(self: *Driver, frame: Frame, goal: ?v.Vec3) !void {
        const world = frame.world;
        const pose = (try world.get(frame.entity, data.Transform)).*;
        const health = (try world.get(frame.entity, data.Health)).*;
        const player = (try world.get(frame.entity, data.Player)).*;
        const loadout = (try world.get(frame.entity, data.Weapons)).*;
        const waypoint = self.report.waypoint orelse nav.Waypoint{ .point = @splat(0) };
        const destination = goal orelse @as(v.Vec3, @splat(0));
        var text: [768]u8 = undefined;
        const head = try std.fmt.bufPrint(&text, "dk3 coop: t={d} event=status map={s} op={s} mode={s} hp={d} armor={d} weapon={d} ammo={d} inventory={x} pos={d:.0},{d:.0},{d:.0} goal={d:.0},{d:.0},{d:.0} waypoint={d:.0},{d:.0},{d:.0} ", .{
            frame.now,             self.level.slice(),                                            if (self.running) |running| @tagName(running.action.op) else "idle",
            @tagName(player.mode), health.current,                                                health.armor,
            loadout.weapon,        loadout.ammo[@intCast(std.math.clamp(loadout.weapon, 0, 31))], loadout.dk3Inventory,
            pose.position[0],      pose.position[1],                                              pose.position[2],
            destination[0],        destination[1],                                                destination[2],
            waypoint.point[0],     waypoint.point[1],                                             waypoint.point[2],
        });
        const report = self.report;
        var obstacle_class: []const u8 = "-";
        var obstacle_phase: []const u8 = "-";
        var obstacle_index: u32 = 0;
        if (report.obstacle < frame.slots.occupants.len) if (frame.slots.occupants[report.obstacle]) |blocker| {
            if (world.get(blocker, data.MapObject) catch null) |object| obstacle_class = object.classname;
            obstacle_index = (world.persistentId(blocker) catch 0) & 0xffffff;
            if (world.get(blocker, data.Mover) catch null) |mover| obstacle_phase = @tagName(mover.state);
        };
        var obstacle_buffer: [96]u8 = undefined;
        const obstacle_text = try std.fmt.bufPrint(&obstacle_buffer, "{d}:{s}#{d} phase={s}", .{ report.obstacle, obstacle_class, obstacle_index, obstacle_phase });
        const velocity = (try world.get(frame.entity, data.Velocity)).linear;
        // Companions: health and distance (an exit waits for them, and the
        // level is lost with them).
        var party_buffer: [96]u8 = undefined;
        const party_text = @import("../../game/server/session_classes.zig").party.summary(world, (try world.get(frame.entity, data.Transform)).position, &party_buffer);
        engine.print(try std.fmt.bufPrintZ(text[head.len..], "{s}vel={d:.0},{d:.0},{d:.0} input={d},{d},{d} water={d} ground={d} hold={d} sub={d} breath={d} areas={d},{d} jump={d} crouch={d} ladder={d} blocked={d} no_route={d} enemy={d} enemy_hp={d} fired={d} control={d} passage={d} obstacle={s} sidestep={d} dodge={d} hostiles={d} party={s} actions={d}\n", .{
            head,                          velocity[0],                                 velocity[1],
            velocity[2],                   report.input[0],                             report.input[1],
            report.input[2],               player.water_level,                          player.ground_entity,
            @intFromBool(report.holding),  report.submerged_ms,                         report.breathing,
            waypoint.from_area,            waypoint.to_area,                            @intFromBool(waypoint.jump),
            @intFromBool(waypoint.crouch), @intFromBool(waypoint.ladder),               @intFromBool(report.blocked),
            @intFromBool(report.no_route), report.enemy,                                report.enemy_health,
            @intFromBool(report.fired),    report.control,                              report.passage,
            obstacle_text,                 @intFromBool(report.sidestepped),            @intFromBool(report.dodging),
            try livingHostiles(world),     if (party_text.len > 0) party_text else "-", self.actions,
        }));
    }

    /// The pace a hop asks for, from the hop itself. The jump leaves the ground
    /// rising at the player's own jump speed and gravity returns the body to the
    /// landing's height after a time that follows from the two, so the pace that
    /// covers exactly the gap between takeoff and landing in that time is the
    /// pace the run-up is made at. A running jump off a ledge sails over the
    /// landing below it and past it (e1m2b's plank ends above a beam: jumped at
    /// the run, the body passed a hundred units over the beam and fell in the
    /// pit beyond it), and a crawl falls short of the same beam. A jump cannot
    /// rise to a landing above its own apex: asked to reach one, the run stays
    /// the whole run and something else (a lift, a shotcycler) does the rest.
    fn hopPace(frame: Frame, takeoff: v.Vec3, landing: v.Vec3, now: i64) !f32 {
        const world = frame.world;
        // The body's own numbers, the same the movement adapter pays with, so a
        // hero whose speed and acrobatics have grown measures a longer hop.
        const movement = player_state.characterParameters(frame.index, (try world.get(frame.entity, data.Character)).*, (try world.get(frame.entity, data.Ailments)).*, now);
        const gap = nav.horizontalDistance(takeoff, landing);
        if (gap < 1) return 1;
        // Height above the takeoff after t: jump*t - gravity*t^2/2. The body is
        // at the landing's height at the later root of that, arriving as it
        // falls -- the slower of the two, the way a player times a drop.
        const reach = movement.jump_speed * movement.jump_speed + 2 * movement.gravity * (takeoff[2] - landing[2]);
        if (reach <= 0) return 1;
        const flight = (movement.jump_speed + @sqrt(reach)) / movement.gravity;
        return std.math.clamp(gap / flight / movement.speed, 0.25, 1);
    }

    fn evaluate(self: *Driver, frame: Frame, running: *Running, player: data.Player) !Evaluation {
        const world = frame.world;
        const action = running.action;
        const now = frame.now;
        const elapsed = now - running.stepped_ms;
        running.stepped_ms = now;
        if (self.report.no_route) {
            if (running.no_route_ms == null) running.no_route_ms = now;
        } else running.no_route_ms = null;
        const pose = (try world.get(frame.entity, data.Transform)).*;
        const eye = v.add(pose.position, .{ 0, 0, player.view_height });
        var result: Evaluation = .{ .intent = .{ .fight = action.fight, .weapon = if (action.weapon != 0) action.weapon else null, .crouch = action.crouch } };
        // Cinematics and other authored holds freeze the player: the action and
        // its deadline wait, exactly as a person's would.
        const holds = player.mode != .normal or @import("cinematics.zig").active(world);
        // A campaign ending's intermission asks for a key once it has shown.
        if (player.mode == .frozen) {
            var exits = world.queryAccess(data.World.mask(.{data.Exit}), 0, 0);
            defer exits.deinit();
            while (exits.next()) |view| for (view.read(data.Exit)) |exit| if (exit.ending_started) |started| if (now > started + 6000) {
                result.intent.press_to_continue = true;
            };
        }
        // Shot from out of view: turn to the shooter, as a person does, so the
        // fight can begin (the motor engages what it sees). Held in place (a
        // wait for a door) and still shot from where it cannot be answered,
        // step out of the line of fire.
        if (self.report.enemy == 0 and now - self.fired_on_ms < 2500) if (world.find(self.attacker)) |shooter| if ((world.get(shooter, data.Health) catch null) != null and (try world.get(shooter, data.Health)).current > 0) {
            const at = (try world.get(shooter, data.Transform)).position;
            result.intent.look_at = at;
            if ((action.op == .wait or action.op == .frame) and now - self.fired_on_ms < 1200 and running.cover_until_ms < now) {
                if (try @import("bot_evasion.zig").cover(try motor_module.pilotFrame(frame), pose.position, v.add(at, .{ 0, 0, 24 }))) |aside| {
                    running.cover = v.add(pose.position, aside);
                    running.cover_until_ms = now + 2500;
                }
            }
        };
        if (running.cover) |spot| if (now < running.cover_until_ms and (action.op == .wait or action.op == .frame)) {
            result.intent.destination = spot;
        } else {
            running.cover = null;
        };
        if (holds and action.op != .cinematic and action.op != .wait and action.op != .frame) {
            running.deadline_ms += elapsed;
            running.progress.since_ms += elapsed;
            return result;
        }
        if (now > running.deadline_ms) return .{ .result = .{ .failed = running.say("timed out after {d} s", .{@divTrunc(action.timeout_ms, 1000)}) } };
        switch (action.op) {
            .frame => {
                if (action.weapon != 0) result.intent.weapon = action.weapon;
                result.intent.crouch = action.crouch;
                if (action.target) |selector| if (action.around) |offset| {
                    const found = try targets.resolve(frame, selector, .mover) orelse return failed(running, "waiting surface not found");
                    const point = if (found.entity == null) v.add(found.point, offset) else surfaceStance(frame, found, offset);
                    result.goal = point;
                    result.intent.destination = if (nav.horizontalDistance(pose.position, point) < 8 and @abs(pose.position[2] - point[2]) < 16) null else point;
                    result.intent.direct = true;
                    result.intent.brake = true;
                    result.intent.leave_mover = true;
                    self.motor.unstick_until = 0;
                    self.motor.jump_until = 0;
                };
                if (now > running.started_ms) result.result = .{ .done = "frame" };
            },
            .wait => if (now - running.started_ms >= action.duration_ms) {
                result.result = .{ .done = "waited" };
            },
            .move => {
                const found = try targets.resolve(frame, action.target orelse return failed(running, "move needs a target"), .any) orelse return failed(running, "move target not found");
                // Literal route points already name the desired player origin.
                // Projecting a ladder's upper point onto the floor below it
                // falsely completes the climb without moving the player.
                const moving_stance = action.around != null and found.entity != null and
                    ((world.get(found.entity.?, data.Mover) catch null) != null or @import("platforms.zig").pathPhase(world, found.entity.?) != null);
                const goal = if (moving_stance) surfaceStance(frame, found, action.around.?) else if (action.direct or action.target.?.entityless()) found.point else if (found.brush)
                    (try @import("bot_routes.zig").touchPointFrom(found.mins, found.maxs, frame.index, .{ .position = pose.position, .service = frame.service })) orelse try standing(frame, found.point)
                else
                    try standing(frame, found.point);
                result.goal = goal;
                result.intent.destination = goal;
                result.intent.leave_mover = moving_stance or (action.direct and action.target.?.entityless());
                result.intent.direct = action.direct;
                if (action.direct and action.vertical_radius > 0) result.intent.swim_depth = goal[2];
                result.intent.brake = action.direct;
                result.intent.crouch = action.crouch;
                // A walk off a narrow ledge drops close under it.
                result.intent.pace = action.pace orelse 1;
                // A precise straight segment ends standing on the floor with its
                // momentum spent, so the next one does not inherit a drift.
                const settled = !action.settle or !action.direct or player.water_level > 0 or (player.ground_entity != c.ENTITYNUM_NONE and nav.horizontalDistance((try world.get(frame.entity, data.Velocity)).linear, @splat(0)) < 120);
                // Standing where it was asked ends the walk, whoever is shooting
                // at the body while it stands there: what attacks is the next
                // sentence's business (a `clear`, a `kill`, or walking on under
                // fire). Checked after the fight, an engagement holds the end of
                // the walk off however exactly the body stands on its goal --
                // e1m7a's ramp held ten units from its mark for two minutes, the
                // pilot running after a shooter it never once saw.
                if (route.arrivedWithin(pose.position, goal, action.arrival(), if (action.vertical_radius > 0) action.vertical_radius else @max(action.arrival(), 56)) and settled) {
                    result.result = .{ .done = running.say("arrived {d:.0},{d:.0},{d:.0}", .{ pose.position[0], pose.position[1], pose.position[2] }) };
                } else {
                    if (try self.standGround(frame, running, player, pose, &result)) return result;
                    if (stalled(frame, running, self.report, pose.position, goal, now)) return stuck(running, self.report, pose.position);
                }
            },
            .touch => {
                if (try self.standGround(frame, running, player, pose, &result)) return result;
                const found = try held(frame, running, .any) orelse return absent(running, "trigger consumed");
                if (running.signature != targets.signature(world, found.id)) return done(running, "trigger fired");
                if (route.overlaps(pose.position, hull_mins, hull_maxs, found.mins, found.maxs)) return done(running, "touched");
                const goal = try volumeGoal(frame, found);
                result.goal = goal;
                result.intent.destination = goal;
                result.intent.direct_radius = 400;
                if (stalled(frame, running, self.report, pose.position, goal, now)) return stuck(running, self.report, pose.position);
            },
            .use, .shoot => {
                result.intent.arena = action.arena;
                if (action.op == .use) result.intent.leave_mover = true;
                if (action.op == .shoot and action.hold) {
                    result.intent.destination = if (nav.horizontalDistance(pose.position, running.home) < 8 and @abs(pose.position[2] - running.home[2]) < 16) null else running.home;
                    result.intent.direct = true;
                    result.intent.brake = true;
                    self.motor.unstick_until = 0;
                    self.motor.jump_until = 0;
                }
                if (action.op == .use) if (try self.standGround(frame, running, player, pose, &result)) return result;
                const found = try held(frame, running, .any) orelse return absent(running, "target removed");
                // A worker at the console a button is set in holds it back:
                // move him on as a player would (a shot sends a worker running).
                // Worth attempting only with a shot to threaten him by, and only
                // while it is still worth the wait: a body left holding nothing
                // but its claws has no way to send him running, and it stands off
                // him until the press spends its minute (e1m3b's console worker
                // after a death had taken the guns away). With no shove to make,
                // the press goes in beside him instead.
                const shove = action.fight and action.op == .use and now - running.started_ms < 12_000 and combat.rangedFor((try world.get(frame.entity, data.Weapons)).*, &frame.clients.weapon_table, .{ .advancing = true });
                if (shove) if (found.entity) |control| if (nav.horizontalDistance(found.point, pose.position) < 200 and @abs(found.point[2] - pose.position[2]) < 96) if (try routes.civilianBlocker(world, frame.projections, control)) |blocker| {
                    self.motor.nuisance = blocker;
                    result.intent.fight = true;
                    result.intent.preferred = blocker;
                    if (world.find(blocker)) |worker| {
                        const at = (try world.get(worker, data.Transform)).position;
                        result.intent.look_at = at;
                        // Behind the console from here: close in for a clear shot.
                        if (self.report.enemy != blocker or self.report.lane_blocked) result.intent.destination = at;
                    }
                    running.progress = .{};
                    return result;
                };
                if (action.op == .use) {
                    if (running.signature != targets.signature(world, found.id)) return done(running, "activated");
                    // A press that changed nothing is retried: the use line can
                    // graze a small button. Movers (buttons, doors) must react;
                    // other usables (an already full health tree) may not.
                    if (running.pressed_ms) |at| if (now - at >= 750) {
                        running.presses += 1;
                        running.pressed_ms = null;
                        const reacts = (world.get(found.entity.?, data.Mover) catch null) != null;
                        if (!reacts or running.presses >= 4) return if (reacts) failed(running, "pressed four times without the control reacting") else done(running, "pressed without visible state change");
                    };
                    // Only presses of this control count (not a lift button the
                    // planner presses on the way).
                    if (self.report.used and self.report.used_slot == (found.slot orelse c.ENTITYNUM_NONE) and running.pressed_ms == null) running.pressed_ms = now;
                } else if (try destroyed(world, found.entity.?)) return done(running, "destroyed");
                const slot = found.slot orelse return failed(running, "target has no physical presence");
                const loadout = (try world.get(frame.entity, data.Weapons)).*;
                var excluded = @import("weapon_classes/registry.zig").lingeringMask();
                if (action.op == .shoot and action.weapon == 0) {
                    const pilot_frame = try motor_module.pilotFrame(frame);
                    for (@import("weapon_catalog").entries) |entry| if (entry.spec.splash_hazard) {
                        const radius = entry.spec.projectile.splash_radius;
                        if (v.length(v.subtract(found.point, eye)) < radius or
                            try @import("bot_pilot.zig").allyNear(pilot_frame, eye, found.point, radius * 1.25))
                            excluded |= @as(i32, 1) << entry.id;
                    };
                }
                // This action may move between firing positions. Placed
                // attacks belong to an explicit route request, rather than
                // leaving delayed blasts on the route to the next control.
                const gun: u5 = combat.preferred(loadout, &frame.clients.weapon_table, action.weapon) orelse combat.selectFor(loadout, &frame.clients.weapon_table, v.length(v.subtract(found.point, eye)), .{ .excluded = excluded, .advancing = true });
                const shot_reach = @min(@as(f32, 2000), if (@import("weapon_catalog").find(gun)) |entry| entry.spec.bot_range orelse frame.clients.weapon_table.entries[gun].range else 2000);
                const reach: f32 = if (action.op == .use) 88 else shot_reach;
                // A health station heals only within 64 of its origin: press it
                // from closer, or the press does nothing.
                const station_far = action.op == .use and routes.isStation(world, found.entity.?) and v.length(v.subtract((try world.get(found.entity.?, data.Transform)).position, pose.position)) > 56;
                // Aim at the centre, else at another part of the control's
                // face: a worker standing in front of a wide door hides only
                // part of it.
                var aim_at: ?v.Vec3 = null;
                const spread = v.scale(v.subtract(found.maxs, found.mins), 0.3);
                // A blast round leaves from the muzzle below the eye and bursts
                // on the first thing it meets: a shot is aimed only where its own
                // round can travel, and a stand that cannot send it there is not
                // a firing position but an obstacle to walk around.
                var shot_lane: ?@import("bot_routes.zig").Lane = null;
                if (action.op == .shoot) {
                    if (@import("weapon_catalog").find(gun)) |entry| {
                        const flight = entry.spec.projectile;
                        if (entry.spec.splash_hazard) shot_lane = .{
                            .muzzle = @import("weapon_catalog").flightLaunch(@intCast(gun), frame.clients.weapon_table.entries[@intCast(gun)], 0, 0).muzzle,
                            .reach = flight.splash_radius,
                            .direct = flight.direct_scale > 0,
                        };
                    }
                }
                // A shot may name the part of a long target to aim at (a
                // window's far end, away from the party): tried first.
                var preferred: v.Vec3 = @splat(0);
                const named = action.op == .shoot and action.around != null;
                if (named) for (0..3) |axis| {
                    preferred[axis] = std.math.clamp(action.around.?[axis], found.mins[axis] + 1, found.maxs[axis] - 1) - found.point[axis];
                };
                const aim_points = [_]v.Vec3{ preferred, .{ 0, 0, 0 }, .{ spread[0], 0, 0 }, .{ -spread[0], 0, 0 }, .{ 0, spread[1], 0 }, .{ 0, -spread[1], 0 }, .{ 0, 0, spread[2] }, .{ 0, 0, -spread[2] } };
                // Two passes over the same parts of the control. The first asks
                // that a splash round burst where its blast still covers the
                // mark: a window's far end, named to keep the blast off a
                // companion, is a poor aim for a round that carries no direct
                // damage and bursts only where it lands. The second takes any
                // part it can see rather than never firing at all. The lane
                // stays a hard requirement either way: a stand the round cannot
                // travel from is an obstacle to walk around, not a position.
                if (!station_far) for ([_]bool{ true, false }) |must_tell| {
                    if (aim_at != null) break;
                    for (aim_points, 0..) |offset, tried| {
                        if (tried == 0 and !named) continue;
                        const point = v.add(found.point, offset);
                        if (v.length(v.subtract(point, eye)) > reach) continue;
                        const bolt: f32 = if (action.op == .shoot) 3 else 0;
                        // Trigger volumes are seen through (a music trigger across
                        // a doorway, e1m4c), unless the control is one.
                        const own_trigger = frame.projections[slot].shared.contents & c.CONTENTS_TRIGGER != 0;
                        const sight = try engine.collisionService().trace(.{ .start = eye, .end = point, .mins = @splat(-bolt), .maxs = @splat(bolt), .slot = frame.index, .mask = if (own_trigger) c.MASK_SHOT | c.CONTENTS_TRIGGER else c.MASK_SHOT });
                        if (sight.entity == slot or sight.fraction == 1) {
                            if (shot_lane) |want| {
                                if (!(try routes.laneClear(frame.index, eye, point, want, slot))) continue;
                                if (!routes.roundSafe(eye, point, want)) continue;
                                if (must_tell and !routes.roundTells(point, found.point, want)) continue;
                            }
                            aim_at = point;
                            break;
                        }
                    }
                };
                // A route may name the weapon for a shot (the glove for glass
                // under water, where an ion bolt would discharge).
                if (action.op == .shoot) result.intent.weapon = gun;
                if (aim_at) |point| {
                    result.intent.face = point;
                    // After a missed press, step in closer for the next one.
                    if (running.presses > 0) result.intent.destination = v.add(pose.position, v.scale(v.normalize(.{ found.point[0] - pose.position[0], found.point[1] - pose.position[1], 0 }), @min(@as(f32, 24), @max(@as(f32, 0), nav.horizontalDistance(pose.position, found.point) - 40))));
                    if (action.op == .use) result.intent.use_slot = slot else result.intent.shoot_slot = slot;
                } else if (action.hold) {
                    // Firing position chosen by the route: keep the lane, do not close in.
                    result.intent.face = found.point;
                } else {
                    if (running.approach == null or now >= running.approach_ms) {
                        running.approach_ms = now + 2000;
                        var obstructions: [@import("bot_routes.zig").approach_points]u16 = @splat(c.ENTITYNUM_NONE);
                        running.approach = try routes.approachWithin(world, found.entity.?, frame.entity, if (action.op == .use) .use else .shoot, frame.service, frame.projections, engine.integer("developer") >= 2, &obstructions, shot_lane, reach);
                        // None reachable as the world stands: choose one as if
                        // every navigation gate were open; the motor's planner
                        // then opens the way to it.
                        if (running.approach == null) if (frame.gates) |state| {
                            state.open();
                            defer state.restore();
                            running.approach = try routes.approachWithin(world, found.entity.?, frame.entity, if (action.op == .use) .use else .shoot, frame.service, frame.projections, engine.integer("developer") >= 2, &obstructions, shot_lane, reach);
                        };
                    }
                    const goal = running.approach orelse found.point;
                    result.goal = goal;
                    result.intent.destination = goal;
                    result.intent.direct_radius = 200;
                    if (stalled(frame, running, self.report, pose.position, goal, now)) return stuck(running, self.report, pose.position);
                }
            },
            .pickup => {
                if (try self.standGround(frame, running, player, pose, &result)) return result;
                // An already collected item is not a failure: replays after a
                // checkpoint restoration meet the world as it was saved.
                const found = try held(frame, running, .pickup) orelse return done(running, if (running.missing) "absent" else "taken");
                const entity = found.entity orelse return failed(running, "pickup needs an entity");
                const pickup = world.get(entity, data.Pickup) catch return done(running, "taken");
                if (!pickup.visible) return done(running, "taken");
                if (!try @import("items.zig").wanted(world, frame.entity, pickup.*, &frame.clients.weapon_table, now)) return done(running, "not needed");
                const goal = @import("../../core/domain/navigation_input.zig").pickupPoint(found.point, (try world.get(entity, data.Body)).mins, hull_mins);
                result.goal = goal;
                result.intent.destination = goal;
                result.intent.direct = action.direct;
                result.intent.brake = action.direct;
                if (route.arrived(pose.position, goal, 12)) {
                    if (running.contact_ms == null) running.contact_ms = now;
                    if (now - running.contact_ms.? > 2000) return failed(running, "wanted pickup remains uncollected at the approach point");
                }
                if (stalled(frame, running, self.report, pose.position, goal, now)) return stuck(running, self.report, pose.position);
            },
            .ride => {
                result.intent.leave_mover = true;
                result.intent.crouch = action.crouch;
                const found = try held(frame, running, .mover) orelse return failed(running, if (running.missing) "lift not found" else "lift removed");
                const lift_moving = targets.moving(world, found.entity.?);
                const lift_pose = (try world.get(found.entity.?, data.Transform)).*;
                const lift = lift_pose.position;
                var centre = surfaceStance(frame, found, @splat(0));
                // Standing on a part carried by the lift (a button on a cage
                // train's floor) is riding it too.
                var riding = found.slot != null and player.ground_entity == found.slot.?;
                if (!riding and player.ground_entity < frame.slots.occupants.len) if (frame.slots.occupants[player.ground_entity]) |part| if (world.get(part, data.Attachment) catch null) |attachment| {
                    riding = attachment.parent_id == found.id;
                };
                if (running.phase >= 1) centre = if (running.approach) |local|
                    @import("../domain/poses.zig").point(local, .{}, lift_pose)
                else
                    pose.position;
                // A cage lift (a train with walls and a roof) is boarded at its
                // floor, not its top: a floor of it level with the rider's feet
                // means it is here.
                var boardable = false;
                if (running.phase == 0) if (found.slot) |slot| {
                    const feet = pose.position[2] + hull_mins[2];
                    const inset = @min(24.0, (found.maxs[0] - found.mins[0]) / 2, (found.maxs[1] - found.mins[1]) / 2);
                    const xs = [_]f32{ centre[0], std.math.clamp(pose.position[0], found.mins[0] + inset, found.maxs[0] - inset), found.mins[0] + inset, found.maxs[0] - inset };
                    const ys = [_]f32{ centre[1], std.math.clamp(pose.position[1], found.mins[1] + inset, found.maxs[1] - inset), found.mins[1] + inset, found.maxs[1] - inset };
                    // A cage's bounds include its roof, walls and supports.
                    // Find a real floor beside the boarding ledge instead of
                    // assuming its box centre is a walkable surface.
                    probe_floor: {
                        for (xs) |px| for (ys) |py| {
                            const probe = try engine.collisionService().trace(.{ .start = .{ px, py, feet + 40 }, .end = .{ px, py, feet - 40 }, .mins = .{ -4, -4, 0 }, .maxs = .{ 4, 4, 0 }, .slot = frame.index, .mask = c.MASK_PLAYERSOLID });
                            if (!probe.start_solid and probe.fraction < 1 and probe.entity == slot and probe.normal[2] > 0.7 and @abs(probe.end[2] - feet) <= 24) {
                                boardable = true;
                                centre = .{ px, py, probe.end[2] - hull_mins[2] + 1 };
                                running.approach = @import("../domain/poses.zig").point(centre, lift_pose, .{});
                                break :probe_floor;
                            }
                        };
                    }
                };
                if (running.phase == 0) {
                    if (riding) {
                        running.phase = 1;
                        running.anchor = lift;
                        self.event(now, "ride-board", running.say("id={d} lift={d:.0},{d:.0},{d:.0}", .{ found.id, lift[0], lift[1], lift[2] }));
                    } else if (lift_moving and !inside(pose.position, found.mins, found.maxs, 8)) {
                        // It left without the rider: never chase a moving
                        // platform (or stand beneath it); wait for it to stop.
                        // A rider momentarily airborne inside it keeps up.
                        result.intent.destination = null;
                        if (now - running.started_ms > 45000) return failed(running, "the lift kept moving without the rider");
                    } else if (!boardable and found.maxs[2] - (pose.position[2] + hull_mins[2]) > 40) {
                        // Raised above the rider: wait clear of its shaft (a
                        // plat coming down onto a player below goes back up,
                        // and returns on its own once nobody is under it).
                        const under = pose.position[0] >= found.mins[0] - 15 and pose.position[0] <= found.maxs[0] + 15 and pose.position[1] >= found.mins[1] - 15 and pose.position[1] <= found.maxs[1] + 15;
                        if (under) {
                            var out: v.Vec3 = .{ pose.position[0] - centre[0], pose.position[1] - centre[1], 0 };
                            if (v.length(out) < 1) out = .{ 1, 0, 0 };
                            result.intent.destination = v.add(pose.position, v.scale(v.normalize(out), 64));
                            result.intent.direct = true;
                            result.intent.direct_radius = 300;
                        } else result.intent.destination = null;
                        if (now - running.started_ms > 45000) return failed(running, "the lift stayed above the rider");
                    } else if (boardable) {
                        // Deck at the rider's feet: step straight onto it. The
                        // area graph is compiled without movers, so it has no
                        // platform under a lift and a routed walk to the centre
                        // leaves the ledge and drops the rider into the shaft.
                        const aboard = centre;
                        result.goal = aboard;
                        result.intent.destination = aboard;
                        result.intent.direct = true;
                        result.intent.direct_radius = 32;
                        if (stalled(frame, running, self.report, pose.position, aboard, now)) return stuck(running, self.report, pose.position);
                    } else {
                        result.goal = centre;
                        result.intent.destination = centre;
                        result.intent.direct_radius = 300;
                        if (stalled(frame, running, self.report, pose.position, centre, now)) return stuck(running, self.report, pose.position);
                    }
                }
                if (running.phase >= 1) {
                    // Straight at the centre: the area graph has no platform
                    // under the rider and would route off its edge.
                    result.intent.destination = .{ centre[0], centre[1], pose.position[2] };
                    result.intent.direct = true;
                    result.intent.direct_radius = 300;
                    result.intent.brake = true;
                    self.motor.unstick_until = 0;
                    self.motor.jump_until = 0;
                    // Aboard and still: a lift sent from on board (a cage
                    // train's own button) is pressed, as a rider does.
                    if (running.phase == 1 and !lift_moving and now - running.started_ms > 1500) if (try boardButton(frame, found.entity.?, pose.position)) |button| {
                        result.intent.face = button.point;
                        result.intent.use_slot = button.slot;
                        // Up to it across the floor of the lift.
                        var inward = v.normalize(.{ centre[0] - button.point[0], centre[1] - button.point[1], 0 });
                        if (button.entity) |control| if (world.get(control, data.Mover) catch null) |press| {
                            // Press from the authored front of the panel.
                            // The lift centre may be behind its wall.
                            const travel = v.subtract(press.opened, press.closed);
                            if (!press.angular and v.length(travel) > 0.01) inward = v.scale(v.normalize(travel), -1);
                        };
                        result.intent.destination = .{ button.point[0] + inward[0] * 40, button.point[1] + inward[1] * 40, pose.position[2] };
                        // A stationary deck may have a wall or support
                        // between its centre and this panel. Let the normal
                        // supported corridor planner route to its front.
                        result.intent.direct = false;
                    };
                    // The lift's own travel counts, not the rider's hops; a cart
                    // pausing at a corner of its path has not arrived yet.
                    if (@abs(lift[2] - running.anchor[2]) > 16) running.phase = 2;
                    if (running.phase == 2) {
                        // A named destination disambiguates a looping cart's
                        // brief unloading stop from its other corners. Actual
                        // support and stopped brush motion are still required.
                        if (action.around) |wanted| if (!lift_moving and riding and nav.horizontalDistance(lift, wanted) <= 24 and @abs(lift[2] - wanted[2]) <= 16) {
                            return done(running, running.say("rode to requested stop {d:.0},{d:.0},{d:.0}", .{ lift[0], lift[1], lift[2] }));
                        };
                        if (lift_moving) {
                            running.contact_ms = null;
                        } else if (running.contact_ms == null) {
                            running.contact_ms = now;
                            self.event(now, "ride-stop", running.say("id={d} riding={any} lift={d:.0},{d:.0},{d:.0}", .{ found.id, riding, lift[0], lift[1], lift[2] }));
                        } else if (now - running.contact_ms.? >= 200 and riding and action.around == null) {
                            // (Landed again first: a rider in mid-hop at the stop
                            // has not arrived.)
                            // A stop part-way along the run (the next corner
                            // carries on the same way) is pressed on from.
                            const onward = if (try nextStop(world, found.entity.?)) |stop| @abs(stop.next[2] - stop.at[2]) > 16 and (stop.next[2] > stop.at[2]) == (lift[2] > running.anchor[2]) else false;
                            if (onward and running.presses < 4 and try boardButton(frame, found.entity.?, pose.position) != null) {
                                running.presses += 1;
                                running.phase = 1;
                                running.anchor = lift;
                                running.contact_ms = null;
                            } else return done(running, running.say("rode to height {d:.0}", .{pose.position[2]}));
                        }
                    }
                }
            },
            .kill => return try self.hunt(frame, running, pose, result),
            .finish => return done(running, "finish"),
            .exit => {
                result.intent.leave_mover = true;
                if (try self.standGround(frame, running, player, pose, &result)) return result;
                const found = try self.exitFor(frame, running) orelse return failed(running, running.say("no exit to {s}", .{if (action.map.empty()) "any map" else action.map.slice()}));
                const goal = try volumeGoal(frame, found);
                result.goal = goal;
                result.intent.destination = goal;
                result.intent.exit = found.id;
                // An exit that takes companions along waits for them to catch
                // up (within 150 units), as long as the action lasts: just
                // outside it, since a touch counts only on entering.
                const flags = (try world.get(found.entity.?, data.MapObject)).flags;
                const waiting_for_party = flags & 6 != 0 and !try @import("../../game/server/session_classes.zig").party.required(world, frame.entity, flags);
                // A touch that did not take (the party arrived after it, say)
                // is made again: out of the exit and back in.
                if (running.contact_ms) |since| if (now - since > 3000 and running.presses < 4) {
                    running.presses += 1;
                    running.pressed_ms = now;
                    running.contact_ms = null;
                };
                const stepping_out = if (running.pressed_ms) |at| now - at < 1500 else false;
                // Wait on the exit's approach for followers. Chasing a
                // stranded companion's raw position can leave the walkable
                // corridor and also prevents its ordinary catch-up recovery
                // from ever observing enough separation to run.
                if ((waiting_for_party or stepping_out) and nav.horizontalDistance(pose.position, goal) < 160) {
                    const middle = v.scale(v.add(found.mins, found.maxs), 0.5);
                    var out = v.subtract(pose.position, middle);
                    out[2] = 0;
                    if (v.length(out) < 1) out = v.subtract(running.home, middle);
                    out[2] = 0;
                    const size = v.subtract(found.maxs, found.mins);
                    result.intent.destination = v.add(middle, v.scale(v.normalize(out), @max(size[0], size[1]) / 2 + 64));
                    result.intent.destination.?[2] = pose.position[2];
                    result.intent.exit = 0;
                    running.contact_ms = null;
                    running.progress = .{};
                    return result;
                }
                if (route.overlaps(pose.position, hull_mins, hull_maxs, found.mins, found.maxs)) {
                    if (running.contact_ms == null) running.contact_ms = now;
                    if (now - running.contact_ms.? > 2500 and running.presses >= 4) return failed(running, "touched the exit but the campaign did not depart");
                } else if (stalled(frame, running, self.report, pose.position, goal, now)) return stuck(running, self.report, pose.position);
            },
            .cinematic => {
                if (holds) {
                    running.phase = 1;
                } else if (running.phase == 1) {
                    return done(running, "finished");
                } else if (now - running.started_ms > 3000) return done(running, "none started");
            },
            .look => {
                result.intent.view = .{ action.yaw, action.pitch };
                const yaw_error = @abs(@mod(action.yaw - pose.angles[1] + 180, 360) - 180);
                if (yaw_error < 2 and @abs(action.pitch - pose.angles[0]) < 2) return done(running, "facing");
            },
            .weapon => {
                const loadout = (try world.get(frame.entity, data.Weapons)).*;
                if (loadout.dk3Inventory & (@as(i32, 1) << action.weapon) == 0) return failed(running, running.say("weapon {d} is not in the inventory", .{action.weapon}));
                result.intent.weapon = action.weapon;
                if (loadout.weapon == action.weapon and loadout.weaponstate == 0) return done(running, "selected");
            },
            .leap => {
                const takeoff = (action.target orelse return failed(running, "leap needs a takeoff")).point orelse return failed(running, "leap takeoff must be a point");
                const surface = if (action.landing) |selector| try targets.resolve(frame, selector, .mover) else null;
                if (action.landing != null and surface == null) return failed(running, "jump landing surface not found");
                const landing = if (surface) |found| surfaceStance(frame, found, action.around orelse @splat(0)) else action.around orelse return failed(running, "leap needs a landing point");
                result.goal = landing;
                result.intent.leave_mover = true;
                const departure = if (surface != null) v.Vec3{ takeoff[0], takeoff[1], pose.position[2] } else takeoff;
                const steering_landing = if (surface != null) v.Vec3{ landing[0], landing[1], pose.position[2] } else landing;
                const grounded = player.ground_entity != c.ENTITYNUM_NONE;
                result.intent.direct = true;
                if (action.blast) {
                    // Shotcycler jump: running through the takeoff looking at
                    // the floor, fire as the jump leaves the ground; the kick
                    // lifts the player, the run carries it over.
                    const loadout = (try world.get(frame.entity, data.Weapons)).*;
                    const velocity = (try world.get(frame.entity, data.Velocity)).linear;
                    result.intent.weapon = action.weapon;
                    result.intent.fight = false;
                    const facing_yaw = skill.yaw(v.subtract(landing, takeoff));
                    switch (running.phase) {
                        0 => {
                            result.intent.destination = takeoff;
                            result.intent.direct = true;
                            result.intent.view = .{ facing_yaw, 89 };
                            const ready = loadout.weapon == action.weapon and loadout.weaponstate != 1 and loadout.weaponstate != 2 and @abs(@mod(pose.angles[1] - facing_yaw + 180, 360) - 180) < 6 and pose.angles[0] > 80;
                            // Hold back short of the takeoff until the gun is up.
                            if (!ready) result.intent.destination = v.add(running.home, .{ 0, 0, 0 });
                            if (loadout.ammo[action.weapon] <= 0) return failed(running, "no shells for the jump");
                            if (grounded and ready and nav.horizontalDistance(pose.position, takeoff) < 20) {
                                running.phase = 1;
                                running.anchor = pose.position;
                            } else if (now - running.started_ms > 8000) return failed(running, "never ready at the takeoff");
                        },
                        1 => {
                            result.intent.view = .{ facing_yaw, 89 };
                            result.intent.destination = landing;
                            result.intent.jump = true;
                            result.intent.trigger = true;
                            if (!grounded) {
                                running.phase = 2;
                                running.presses = 0;
                            }
                            if (now - running.started_ms > 10000) return failed(running, "blast jump never left the ground");
                        },
                        else => {
                            result.intent.view = .{ facing_yaw, 89 };
                            result.intent.destination = landing;
                            _ = velocity;
                            if (grounded and now - running.started_ms > 300) {
                                if (nav.horizontalDistance(pose.position, landing) < 48 and @abs(pose.position[2] - landing[2]) < 32) return done(running, running.say("landed {d:.0},{d:.0},{d:.0}", .{ pose.position[0], pose.position[1], pose.position[2] }));
                                return failed(running, running.say("landed short at {d:.0},{d:.0},{d:.0}", .{ pose.position[0], pose.position[1], pose.position[2] }));
                            }
                        },
                    }
                    return result;
                }
                // A hop goes at the pace its own gap asks for, throughout: the
                // route may name one (a hop whose arc must not be its own), and
                // otherwise the ballistic answer is worked out below.
                result.intent.pace = action.pace orelse try hopPace(frame, takeoff, landing, now);
                switch (running.phase) {
                    0 => {
                        // A preceding stair/ledge climb may still hold jump.
                        // Release it on support before issuing this new jump;
                        // otherwise walking off the lip looks like takeoff.
                        if (grounded and player.jump_held) {
                            self.motor.jump_until = 0;
                            result.intent.destination = null;
                            return result;
                        }
                        // Run straight through the takeoff at full speed from where
                        // the route left the player (its run-up); jump on reaching
                        // it, or as soon as the raised joint lifts the player.
                        result.intent.destination = departure;
                        const riding_source = grounded and player.ground_entity < frame.slots.occupants.len and if (frame.slots.occupants[player.ground_entity]) |under| targets.moving(world, under) else false;
                        const lifted = !riding_source and pose.position[2] >= running.home[2] + 7;
                        // At full speed a frame covers some 16 units: one that
                        // carries the player past the takeoff (close to the
                        // run's line) jumps there rather than running on.
                        const run: v.Vec3 = .{ takeoff[0] - running.home[0], takeoff[1] - running.home[1], 0 };
                        const offset: v.Vec3 = .{ pose.position[0] - takeoff[0], pose.position[1] - takeoff[1], 0 };
                        const passed = v.length(run) > 1 and v.dot(offset, v.normalize(run)) > -4 and v.length(v.subtract(offset, v.scale(v.normalize(run), v.dot(offset, v.normalize(run))))) < 20;
                        if (grounded and (nav.horizontalDistance(pose.position, takeoff) < 14 or lifted or passed)) {
                            running.phase = 1;
                            running.anchor = pose.position;
                            // Steer toward the landing in the departure command.
                            // Keeping the approach direction for one more frame
                            // also accelerates a short reversing hop away from
                            // its landing before air control can turn it around.
                            result.intent.destination = steering_landing;
                            result.intent.view = .{ skill.yaw(v.subtract(landing, pose.position)), 0 };
                            result.intent.jump = true;
                        } else if (now - running.started_ms > 5000) return failed(running, "never reached the takeoff");
                    },
                    1 => {
                        result.intent.view = .{ skill.yaw(v.subtract(landing, pose.position)), 0 };
                        result.intent.destination = steering_landing;
                        result.intent.jump = true;
                        if (!grounded) running.phase = 2;
                        if (now - running.started_ms > 6000) return failed(running, "running jump never left the ground");
                    },
                    else => {
                        result.intent.destination = steering_landing;
                        result.intent.view = .{ skill.yaw(v.subtract(landing, pose.position)), 0 };
                        if (grounded) {
                            if (surface) |found| {
                                if (found.slot != null and player.ground_entity == found.slot.?) return done(running, "landed on moving surface");
                                if ((try world.get(frame.entity, data.Velocity)).linear[2] <= 0)
                                    return failed(running, running.say("missed moving landing at {d:.0},{d:.0},{d:.0}", .{ pose.position[0], pose.position[1], pose.position[2] }));
                                return result;
                            }
                            const landing_height = if (action.vertical_radius > 0) @abs(pose.position[2] - landing[2]) <= action.vertical_radius else pose.position[2] > landing[2] - 32;
                            if (nav.horizontalDistance(pose.position, landing) < (if (action.radius > 0) action.radius else @as(f32, 96)) and landing_height) return done(running, running.say("landed {d:.0},{d:.0},{d:.0}", .{ pose.position[0], pose.position[1], pose.position[2] }));
                            // Contact with a rising slope while still climbing
                            // is not a short landing. Keep steering the jump
                            // until the body actually settles or falls.
                            if ((try world.get(frame.entity, data.Velocity)).linear[2] <= 0)
                                return failed(running, running.say("landed short at {d:.0},{d:.0},{d:.0}", .{ pose.position[0], pose.position[1], pose.position[2] }));
                        }
                    },
                }
                if ((surface != null or action.radius > 0) and running.phase >= 1 and !grounded) {
                    // Brake in the air before the centre of a small moving
                    // landing. Full run-up speed otherwise carries the body
                    // off its far edge before the next command can settle it.
                    const velocity = (try world.get(frame.entity, data.Velocity)).linear;
                    const flat: v.Vec3 = .{ velocity[0], velocity[1], 0 };
                    const toward: v.Vec3 = .{ landing[0] - pose.position[0], landing[1] - pose.position[1], 0 };
                    if (v.dot(flat, toward) > 0 and v.length(toward) < v.length(flat) * 0.35) {
                        result.intent.destination = v.subtract(pose.position, v.scale(v.normalize(flat), 128));
                    }
                }
            },
            .jump => {
                result.intent.jump = now - running.started_ms < 250;
                if (now - running.started_ms >= 450) return done(running, "jumped");
            },
            .save => {
                if (running.phase == 0) {
                    running.phase = 1;
                    var command: [96]u8 = undefined;
                    link_module.client(frame.index, try std.fmt.bufPrintZ(&command, "save {s}", .{action.slot.slice()}));
                }
                if (running.phase == 2) {
                    const vitality = (try world.get(frame.entity, data.Health)).*;
                    if (vitality.current * 4 < vitality.maximum)
                        return done(running, "saved; recovery checkpoint retained because health is low");
                    self.last_save = @splat(0);
                    @memcpy(self.last_save[0..@min(action.slot.slice().len, 63)], action.slot.slice()[0..@min(action.slot.slice().len, 63)]);
                    _ = engine.gateway.call(c.G_CVAR_SET, .{ @as([*:0]const u8, "dk3_coop_last_save"), @as([*:0]const u8, @ptrCast(&self.last_save)) });
                    return done(running, "saved and checkpoint admitted");
                }
            },
        }
        return result;
    }
    fn exitFor(self: *Driver, frame: Frame, running: *Running) !?targets.Resolved {
        _ = self;
        if (running.target != 0) return if (frame.world.find(running.target)) |entity| try targets.describe(frame, entity) else null;
        if (running.action.target) |selector| {
            const found = try targets.resolve(frame, selector, .exit) orelse return null;
            if (!running.action.map.empty()) {
                const object = try frame.world.get(found.entity.?, data.MapObject);
                if (!std.ascii.eqlIgnoreCase(properties.text(object.*, "map") orelse "", running.action.map.slice())) return null;
            }
            running.target = found.id;
            return found;
        }
        const origin = (try frame.world.get(frame.entity, data.Transform)).position;
        var best: ?targets.Resolved = null;
        var nearest: f32 = std.math.inf(f32);
        var best_fired = true;
        var query = frame.world.queryAccess(data.World.mask(.{ data.Exit, data.MapObject }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, object| {
            if (!running.action.map.empty()) {
                const destination = properties.text(object, "map") orelse continue;
                if (!std.ascii.eqlIgnoreCase(destination, running.action.map.slice())) continue;
            }
            const candidate = try targets.describe(frame, entity);
            const distance = v.length(v.subtract(candidate.point, origin));
            // Walk into a touchable exit, not one another entity fires.
            const fired = object.targetname.len != 0;
            if (fired and !best_fired) continue;
            if (fired == best_fired and distance >= nearest) continue;
            nearest = distance;
            best = candidate;
            best_fired = fired;
        };
        if (best) |found| running.target = found.id;
        return best;
    }
    /// Deal with what attacks first: a hostile whose threat is the player,
    /// alive within 1000 units, is fought before the route goes on, as a
    /// player clears what shoots at him (`cautious` also takes on any enemy
    /// in sight). In sight with a clear lane and in reach: hold there
    /// (tethered, dodging) and shoot; otherwise close in along the area
    /// graph for a firing line. One that cannot be reached, hurt or finished
    /// within 25 s is let be for a while.
    fn standGround(self: *Driver, frame: Frame, running: *Running, player: data.Player, pose: data.Transform, result: *Evaluation) !bool {
        _ = player;
        const action = running.action;
        const now = frame.now;
        const world = frame.world;
        if (!action.fight or (action.direct and !action.cautious) or action.hold) return false;
        const pilot_frame = try motor_module.pilotFrame(frame);
        // Halfway up a ladder the rungs are the body's one way down: a stop to
        // fight there sends it back to the floor, so the climb comes first.
        if (try @import("bot_pilot.zig").onRungs(pilot_frame, pose.position)) return self.rejoinCorridor(frame, running, pose.position, result);
        const aggressor = try survival.pick(pilot_frame, pose.position, .{ .self_id = try world.persistentId(frame.entity), .seen = self.report.enemy, .cautious = action.cautious, .engaged = running.engagement.id, .ignore = &self.ignoring }) orelse {
            running.engagement.id = 0;
            return self.rejoinCorridor(frame, running, pose.position, result);
        };
        // Badly hurt with a health pack near: break off and fetch it first
        // (the health detour), unless the aggressor is nearly finished.
        const decision = try survival.engage(&running.engagement, .{
            .frame = pilot_frame,
            .report = self.report,
            .position = pose.position,
            .health = (try world.get(frame.entity, data.Health)).*,
            .loadout = (try world.get(frame.entity, data.Weapons)).*,
            .detouring = self.detour.target != 0,
            .health_rise = if (action.direct) 32 else 128,
        }, aggressor);
        var at = (try aggressor.ref.get(data.Transform)).position;
        if (aggressor.ref.get(data.Body) catch null) |body| at[2] += (body.mins[2] + body.maxs[2]) * 0.5;
        switch (decision) {
            .none => return self.rejoinCorridor(frame, running, pose.position, result),
            .ignore => |until| {
                self.ignoring.ignore(aggressor.id, until.until);
                if (until.stale) running.progress = .{};
                return self.rejoinCorridor(frame, running, pose.position, result);
            },
            .hold => |stand| {
                result.intent.destination = null;
                result.intent.leash = stand;
                // Ducked, a shooter's rounds aimed at the chest mostly pass
                // over: hold the stand low while the target stays in sight
                // from there, as a player does.
                const low = v.add(pose.position, .{ 0, 0, -2 });
                const sight = try engine.collisionService().trace(.{ .start = low, .end = at, .mins = @splat(0), .maxs = @splat(0), .slot = frame.index, .mask = @as(u32, c.MASK_SHOT) & ~@as(u32, c.CONTENTS_BODY) });
                // Keep running speed when prey can reach the stand in one
                // stride. Crouching against a nearby melee crowd is fatal.
                if (sight.fraction == 1 and aggressor.distance > 256) result.intent.crouch = true;
            },
            .approach => |goal| {
                if (action.direct) {
                    // The supplied corridor owns the footing. A combat route
                    // can leave its bridge or pool rim even when its endpoint
                    // is on the same floor. Advance the corridor while firing;
                    // explicit kill orders can still pursue off that route.
                    self.ignoring.ignore(aggressor.id, now + 5000);
                    running.engagement.id = 0;
                    return self.rejoinCorridor(frame, running, pose.position, result);
                }
                result.intent.destination = goal;
            },
        }
        if (action.direct and running.corridor_return == null) running.corridor_return = try corridorPoint(frame, pose.position);
        running.returning_to_corridor = false;
        result.intent.face = null;
        result.intent.direct = false;
        result.intent.brake = false;
        result.intent.fight = true;
        result.intent.preferred = aggressor.id;
        result.intent.look_at = at;
        running.progress = .{};
        // A fight buys its action time, but only as much again as that action
        // was authored with. `engage` lets one enemy go after 25 s and the next
        // nearest is taken on at once, so a hall full of hostiles pushes for
        // ever: e1m7a's gallery kept a sixty-second move open for eighty
        // minutes of game time on a hunt for a shooter the pilot never saw, and
        // the run reported nothing at all. Bounded, the action ends on its own
        // clock and the route decides what to do about it.
        if (running.fight_ms < action.timeout_ms) if (now + fight_stand_ms > running.deadline_ms) {
            const push = @min(now + fight_stand_ms - running.deadline_ms, action.timeout_ms - running.fight_ms);
            running.deadline_ms += push;
            running.fight_ms += push;
        };
        return true;
    }
    fn rejoinCorridor(self: *Driver, frame: Frame, running: *Running, position: v.Vec3, result: *Evaluation) !bool {
        // Keep the original corridor anchor while the supply trip is active.
        // Rejoining before `survive` advances it would clear/rewrite that anchor
        // on every frame and leave it at the pickup on another floor.
        if (self.detour.target != 0) return false;
        const point = running.corridor_return orelse return false;
        if (route.arrivedWithin(position, point, 24, 24)) {
            running.corridor_return = null;
            running.returning_to_corridor = false;
            running.progress = .{};
            return false;
        }
        if (!running.returning_to_corridor) {
            running.returning_to_corridor = true;
            running.progress = .{};
            self.event(frame.now, "rejoin", running.say("returning to corridor {d:.0},{d:.0},{d:.0}", .{ point[0], point[1], point[2] }));
        }
        result.intent.destination = point;
        result.intent.direct = false;
        if ((try frame.world.get(frame.entity, data.Player)).water_level >= 2) {
            const body = try frame.world.get(frame.entity, data.Body);
            const line = try engine.collisionService().trace(.{ .start = position, .end = point, .mins = body.mins, .maxs = body.maxs, .slot = frame.index, .mask = body.collision_mask });
            if (!line.start_solid and !line.all_solid and line.fraction == 1) {
                result.intent.direct = true;
                result.intent.swim_depth = point[2];
            }
        }
        result.intent.brake = false;
        result.intent.leash = null;
        result.intent.preferred = 0;
        result.goal = point;
        if (stalled(frame, running, self.report, position, point, frame.now)) result.* = stuck(running, self.report, position);
        return true;
    }
    fn corridorPoint(frame: Frame, position: v.Vec3) !v.Vec3 {
        const body = try frame.world.get(frame.entity, data.Body);
        const floor = try engine.collisionService().trace(.{ .start = position, .end = v.add(position, .{ 0, 0, -72 }), .mins = body.mins, .maxs = body.maxs, .slot = frame.index, .mask = body.collision_mask & ~@as(u32, c.CONTENTS_BODY) });
        // A fight can begin midway through a hop. Return to its supported
        // footing, rather than forever trying to settle at that airborne height.
        return if (!floor.start_solid and !floor.all_solid and floor.fraction < 1 and floor.normal[2] > 0.7) floor.end else position;
    }
    /// A button within reach that sends this lift (it targets the lift, or
    /// rides on it): the control a rider presses.
    fn boardButton(frame: Frame, lift: ecs.Entity, position: v.Vec3) !?targets.Resolved {
        const world = frame.world;
        const name = (try world.get(lift, data.MapObject)).targetname;
        if (name.len == 0) return null;
        var best: ?targets.Resolved = null;
        var nearest: f32 = 192;
        var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Transform }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, object| {
            if (!@import("entity_classes/registry.zig").traitsOf(object.classname).button or !std.mem.eql(u8, object.target, name)) continue;
            const found = try targets.describe(frame, entity);
            const distance = v.length(v.subtract(found.point, v.add(position, .{ 0, 0, 22 })));
            if (distance >= nearest or found.slot == null) continue;
            nearest = distance;
            best = found;
        };
        return best;
    }
    fn hunt(self: *Driver, frame: Frame, running: *Running, pose: data.Transform, base: Evaluation) !Evaluation {
        const world = frame.world;
        const action = running.action;
        var result = base;
        result.intent.fight = true;
        // A route may name the weapon (the shockwave, kept out of the bot's
        // own choice, fired into a room of brutes from its doorway).
        if (action.weapon != 0) result.intent.weapon = action.weapon;
        // Track every matching hostile seen inside the search area; a kill is a
        // tracked actor that has died or been removed.
        var nearest: ?targets.Resolved = null;
        var distance: f32 = std.math.inf(f32);
        var selection_distance: f32 = std.math.inf(f32);
        var living: usize = 0;
        var let_be: usize = 0;
        var query = world.queryAccess(data.World.mask(.{ data.Actor, data.Health, data.Transform, data.MapObject }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities(), view.read(data.Actor), view.read(data.Health), view.read(data.Transform), view.read(data.MapObject)) |entity, actor, health, transform, object| {
            if (health.current <= 0) continue;
            if (action.target) |selector| {
                if (selector.id != 0 and selector.id != try world.persistentId(entity)) continue;
                if (selector.index != 0 and selector.index != (try world.persistentId(entity)) & 0xffffff) continue;
                if (!selector.name.empty() and !std.mem.eql(u8, object.targetname, selector.name.slice())) continue;
                if (!selector.class.empty() and !std.mem.eql(u8, object.classname, selector.class.slice())) continue;
                if (selector.name.empty() and selector.id == 0 and selector.index == 0 and !route.hostile(catalog.entries[actor.definition].kind)) continue;
            } else if (!route.hostile(catalog.entries[actor.definition].kind)) continue;
            if (action.limitedHunt() and v.length(v.subtract(transform.position, running.anchor)) > action.searchRadius()) continue;
            const id = try world.persistentId(entity);
            if (action.target == null and self.hunt_let_be.ignored(id, frame.now)) {
                let_be += 1;
                continue;
            }
            if (std.mem.indexOfScalar(u32, running.tracked[0..running.tracked_count], id) == null and running.tracked_count < running.tracked.len) {
                running.tracked[running.tracked_count] = id;
                running.tracked_count += 1;
            }
            living += 1;
            const span = v.length(v.subtract(transform.position, pose.position));
            // Small dodges must not alternate between two adjacent shooters:
            // each switch restarts reaction and spreads damage across both.
            // Retain a usable firing target until another is substantially
            // closer; a lost lane immediately removes this preference.
            const committed = id == running.target and self.report.enemy == id and !self.report.lane_blocked;
            const score = span * @as(f32, if (committed) 0.75 else 1);
            if (score >= selection_distance) continue;
            selection_distance = score;
            distance = span;
            nearest = try targets.describe(frame, entity);
        };
        const killed = running.tracked_count -| living;
        if (living == 0 or (action.count > 0 and killed >= action.count)) return done(running, if (let_be == 0) running.say("killed {d}", .{killed}) else running.say("killed {d}, {d} left out of reach", .{ killed, let_be }));
        var prey = nearest.?;
        running.target = prey.id;
        prey.point = try standing(frame, prey.point);
        result.intent.preferred = prey.id;
        result.goal = prey.point;
        // Close in until the prey is in sight and inside the chosen weapon's
        // reach; then hold ground and let the motor aim and fire.
        const loadout = (try world.get(frame.entity, data.Weapons)).*;
        // A route's preferred gun can empty during a long fight. Continue
        // with the admitted loadout rather than holding an empty barrel;
        // weapons with an actual empty-hand strike retain that option.
        result.intent.weapon = combat.preferred(loadout, &frame.clients.weapon_table, action.weapon);
        const weapon = result.intent.weapon orelse combat.selectFor(loadout, &frame.clients.weapon_table, distance, .{ .excluded = @import("bot_pilot.zig").damageExclusions(.{ .world = world, .entity = prey.entity.? }, frame.now) });
        const reach = combat.standOffFor(loadout, &frame.clients.weapon_table, weapon);
        // Seen behind cover a shot cannot clear is not yet a firing position.
        const firing_line = self.report.enemy == prey.id and !self.report.lane_blocked;
        // Fleeting visibility without any attack does not qualify a stand.
        // Renew it only when the motor can actually attack the named prey;
        // otherwise the existing timeout closes on a usable firing place.
        if (firing_line and self.report.fired) running.contact_ms = frame.now;
        if (running.contact_ms == null) running.contact_ms = frame.now;
        // A held fight keeps the stand the route chose until that stand proves
        // blind: prey that stays out of sight for 12 s is not shot from there,
        // and no player waits on a ledge for a target he cannot see. Then drop
        // the tether and go and find it, as a player walks to a firing place.
        // (Not below a ledge or in deep water: bolts die in water and a player
        // does not jump off the bank after one stubborn enemy.)
        const reachable_stand = prey.point[2] > pose.position[2] - 128;
        // A caller-supplied arena is a footing constraint, including when
        // the target remains blind. Do not replace it with an AAS pursuit.
        if (action.hold and action.arena == null and reachable_stand and !running.hold_closed and frame.now - running.contact_ms.? > 12_000) {
            running.hold_closed = true;
            running.progress = .{};
            self.event(frame.now, "hold", running.say(
                "no usable firing line for 12 s at {d:.0},{d:.0},{d:.0}: closing on prey {d}",
                .{ pose.position[0], pose.position[1], pose.position[2], prey.id },
            ));
        }
        const tethered = action.hold and !running.hold_closed;
        const contact_distance = if (reach < 128) v.length(v.subtract(v.closestInBounds(pose.position, prey.mins, prey.maxs), pose.position)) else distance;
        var engaged = tethered or (firing_line and contact_distance <= reach);
        var shifted = false;
        if (engaged) result.intent.leash = if (tethered) running.home else pose.position;
        result.intent.arena = action.arena;
        result.intent.look_at = prey.point;
        // Held, but the prey has stayed out of sight: shift within the tether
        // toward it to regain a firing line, then hold again.
        if (tethered and frame.now - running.contact_ms.? > 5000) {
            const toward = v.subtract(prey.point, running.home);
            const flat = v.normalize(.{ toward[0], toward[1], 0 });
            var shift = v.add(running.home, v.scale(flat, 200));
            // An arena bounds the shift too: the fight stays where the route put it.
            // (An arena narrower than a body across holds its middle.)
            if (action.arena) |box| for (0..2) |axis| {
                const low = box[0][axis] + 16;
                const high = box[1][axis] - 16;
                shift[axis] = if (low <= high) std.math.clamp(shift[axis], low, high) else (box[0][axis] + box[1][axis]) / 2;
            };
            result.intent.destination = try standing(frame, shift);
            engaged = false;
            shifted = true;
        }
        // Losing a trade of fire (a guard's magazine against rounds that do
        // not finish it): back out of its line for a moment, as a player
        // does, and come out again (it reloads, or walks into reach).
        if (running.cover) |spot| if (frame.now < running.cover_until_ms) {
            result.intent.destination = spot;
            result.intent.leash = null;
            running.progress = .{};
            return result;
        };
        if (engaged and !tethered) try self.measureTrade(frame, running, prey, pose);
        // (A held shift keeps its own point: it stays within the tether.)
        if (!engaged and !shifted) {
            var goal = prey.point;
            // A hunt that left its tether still keeps the arena the route drew
            // about the fight: what lies beyond it may be the drop the player
            // would never take in order to reach one stubborn enemy.
            if (action.hold) if (action.arena) |box| for (0..2) |axis| {
                const low = box[0][axis] + 16;
                const high = box[1][axis] - 16;
                goal[axis] = if (low <= high) std.math.clamp(goal[axis], low, high) else (box[0][axis] + box[1][axis]) / 2;
            };
            const close_on = try standing(frame, goal);
            result.intent.destination = close_on;
            if (stalled(frame, running, self.report, pose.position, close_on, frame.now)) {
                // Nothing came of the whole window, and this enemy never hurt
                // the player: it is out of reach rather than stubborn (the
                // e1m2a upper sewer's clear spent 42 s wobbling at the rim of
                // the shaft a sludgeminion waddled down). Let it be and clear
                // the rest; what hunts the player is always fought.
                if (action.target == null and self.report.enemy != prey.id and self.attacker != prey.id) {
                    self.hunt_let_be.ignore(prey.id, frame.now + 20_000);
                    running.progress = .{};
                    const spent = running.hunt_stall_ms;
                    running.hunt_stall_ms = @min(running.hunt_stall_ms, 9_000);
                    self.event(frame.now, "letbe", running.say(
                        "no way to prey {d} in {d} s at {d:.0},{d:.0},{d:.0}: leaving it, {d} s per prey after",
                        .{ prey.id, @divTrunc(spent, 1000), pose.position[0], pose.position[1], pose.position[2], @divTrunc(running.hunt_stall_ms, 1000) },
                    ));
                    return result;
                }
                return stuck(running, self.report, pose.position);
            }
        }
        if (engaged) running.progress = .{};
        return result;
    }
    fn measureTrade(self: *Driver, frame: Frame, running: *Running, prey: targets.Resolved, pose: data.Transform) !void {
        _ = self;
        const own_health = (try frame.world.get(frame.entity, data.Health)).*;
        const own = own_health.current;
        const theirs = if (prey.entity) |entity| if (frame.world.get(entity, data.Health)) |health| health.current else |_| 0 else 0;
        if (running.trade_prey != prey.id or frame.now - running.trade_ms > 2500) {
            running.trade_prey = prey.id;
            running.trade_ms = frame.now;
            running.trade_health = own;
            running.trade_prey_health = theirs;
            return;
        }
        const lost = running.trade_health - own;
        const dealt = running.trade_prey_health - theirs;
        if (lost < 20 or frame.now - running.trade_ms < 800) return;
        // Who runs out first, measured across both health pools: the prey's
        // health against the damage still landing, the player's against the
        // rounds still arriving. Shooting twice as hard as the enemy is no win
        // from one health pack against twice his armour - the player still
        // dies first, and a player steps out of that line and lets the enemy
        // come to him, where the fight is shorter. Equal pools reduce this to
        // the bare rate of damage the rule had before.
        const spent = @as(i64, theirs) * lost;
        const winning = @as(i64, own) * dealt;
        const outgunned = spent >= winning * 2;
        const hurt = own * 5 < own_health.maximum * 3;
        if (!(outgunned or (hurt and spent * 4 >= winning * 3))) return;
        running.trade_ms = frame.now;
        running.trade_health = own;
        running.trade_prey_health = theirs;
        const shooter = v.add(prey.point, .{ 0, 0, 40 });
        if (try @import("bot_evasion.zig").cover(try motor_module.pilotFrame(frame), pose.position, shooter)) |aside| {
            running.cover = v.add(pose.position, aside);
            running.cover_until_ms = frame.now + (if (hurt) @as(i64, 3500) else @as(i64, 2000));
        }
    }
};
/// Resolves the action target once, then keeps following the same entity.
fn held(frame: Frame, running: *Running, filter: targets.Filter) !?targets.Resolved {
    if (running.target != 0) {
        const entity = frame.world.find(running.target) orelse return null;
        return try targets.describe(frame, entity);
    }
    if (running.missing) return null;
    const found = try targets.resolve(frame, running.action.target orelse return null, filter) orelse {
        running.missing = true;
        return null;
    };
    running.target = found.id;
    running.signature = targets.signature(frame.world, found.id);
    return found;
}
fn absent(running: *Running, gone: []const u8) Evaluation {
    return if (running.missing) failed(running, "target not found") else done(running, gone);
}
fn done(running: *Running, detail: []const u8) Evaluation {
    _ = running;
    return .{ .result = .{ .done = detail } };
}
fn failed(running: *Running, detail: []const u8) Evaluation {
    _ = running;
    return .{ .result = .{ .failed = detail } };
}
fn stalled(frame: Frame, running: *Running, report: motor_module.Report, position: v.Vec3, goal: v.Vec3, now: i64) bool {
    // Without any navigation route the goal is unreachable from here; fail
    // well before the progress window so the route can choose another way.
    if (running.no_route_ms) |since| if (now - since > 8000) return true;
    // A closed door on the route sends the motor to the authored control that
    // opens it, often away from the goal: progress is measured toward that.
    if (report.control != running.watched) {
        running.watched = report.control;
        running.progress = .{};
    }
    // Along the route where there is one: a long way round (a crawl past
    // fans, away from the goal and back) is progress all the same.
    const target = report.control_point orelse goal;
    const left = (frame.service.travel(.{ .position = position, .destination = target, .slot = frame.index, .player = true }) catch null) orelse v.length(v.subtract(target, position));
    running.progress.update(left, now);
    return running.progress.stalled(now, running.hunt_stall_ms);
}
fn stuck(running: *Running, report: motor_module.Report, position: v.Vec3) Evaluation {
    const waypoint = report.waypoint orelse nav.Waypoint{ .point = @splat(0) };
    return .{ .result = .{ .failed = running.say("no progress for {d} s at {d:.0},{d:.0},{d:.0} waypoint={d:.0},{d:.0},{d:.0} blocked={d} no_route={d} control={d} avoided_exit={d}", .{ @divTrunc(running.hunt_stall_ms, 1000), position[0], position[1], position[2], waypoint.point[0], waypoint.point[1], waypoint.point[2], @intFromBool(report.blocked), @intFromBool(report.no_route), report.control, report.avoided_exit }) } };
}
/// Horizontally within the box (grown by `margin`) and not below its floor.
fn inside(position: v.Vec3, mins: v.Vec3, maxs: v.Vec3, margin: f32) bool {
    return position[0] >= mins[0] - margin and position[0] <= maxs[0] + margin and
        position[1] >= mins[1] - margin and position[1] <= maxs[1] + margin and position[2] >= mins[2];
}
/// The player origin standing on the floor below `point`: navigation areas are
/// on floors, while authored points and trigger centres may float above them.
fn standing(frame: Frame, point: v.Vec3) !v.Vec3 {
    const floor = try engine.collisionService().trace(.{ .start = point, .end = v.add(point, .{ 0, 0, -512 }), .mins = hull_mins, .maxs = hull_maxs, .slot = frame.index, .mask = c.MASK_PLAYERSOLID });
    if (floor.start_solid or floor.all_solid or floor.fraction == 1) return point;
    return floor.end;
}
/// A trigger volume is reached by walking into it; completion is the first hull
/// overlap, so a centre inside a wall still yields a usable heading. Where the
/// volume does have a place to stand, that place is the goal: a centre set
/// inside a wall has no floor and no area to route at, and a route cannot be
/// planned to it at all (e1m4a's keypad trigger, set into the bar's wall).
fn volumeGoal(frame: Frame, found: targets.Resolved) !v.Vec3 {
    if (try routes.touchPointFrom(found.mins, found.maxs, frame.index, .{ .position = (try frame.world.get(frame.entity, data.Transform)).position, .service = frame.service })) |point| return point;
    var centre = found.point;
    centre[2] = @min(found.maxs[2], found.mins[2] - hull_mins[2] + 8);
    return standing(frame, centre);
}
/// A shot target is finished when it breaks, dies, or an authored mover reacts.
fn destroyed(world: *data.World, entity: ecs.Entity) !bool {
    if (world.get(entity, data.Destructible) catch null) |state| if (state.broken or state.hidden) return true;
    if (world.get(entity, data.Health) catch null) |health| if (health.current <= 0) return true;
    if (world.get(entity, data.Mover) catch null) |mover| if (mover.state != .closed) return true;
    return false;
}
fn className(world: *data.World, id: u32) []const u8 {
    const entity = world.find(id) orelse return "-";
    if (world.get(entity, data.MapObject) catch null) |object| return object.classname;
    inline for (@import("../../game/server/hazard_classes.zig").classes) |Class| if (@hasDecl(Class, "diagnostic_name")) {
        if ((world.get(entity, Class.hazard) catch null) != null) return Class.diagnostic_name;
    };
    if ((world.get(entity, data.Projectile) catch null) != null) return "projectile";
    return "?";
}
fn livingHostiles(world: *data.World) !usize {
    var count: usize = 0;
    var query = world.queryAccess(data.World.mask(.{ data.Actor, data.Health }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.read(data.Actor), view.read(data.Health)) |actor, health| {
        if (health.current > 0 and route.hostile(catalog.entries[actor.definition].kind)) count += 1;
    };
    return count;
}
fn describe(buffer: []u8, action: route.Action) []const u8 {
    var target_text: [160]u8 = undefined;
    const target = if (action.target) |selector|
        (if (selector.point) |point| std.fmt.bufPrint(&target_text, "{d:.0},{d:.0},{d:.0}", .{ point[0], point[1], point[2] }) catch "?" else std.fmt.bufPrint(&target_text, "name={s} class={s} id={d} index={d}", .{ selector.name.slice(), selector.class.slice(), selector.id, selector.index }) catch "?")
    else
        "-";
    return std.fmt.bufPrint(buffer, "op={s} target={s} map={s} timeout={d}", .{ @tagName(action.op), target, action.map.slice(), @divTrunc(action.timeout_ms, 1000) }) catch buffer[0..0];
}
/// A resting path mover's stop and next corner, from the mover class owning it.
fn nextStop(world: *data.World, entity: @import("../../core/ecs/world.zig").Entity) !?struct { at: @import("../../core/domain/vector.zig").Vec3, next: @import("../../core/domain/vector.zig").Vec3 } {
    inline for (@import("../../game/server/world_system_classes.zig").motion) |Class| if (@hasDecl(Class, "nextStop")) {
        if (try Class.nextStop(world, entity)) |stop| return .{ .at = stop.at, .next = stop.next };
    };
    return null;
}

test "visible pilot excludes keyboard input without changing ordinary clients or dedicated bots" {
    var driver: Driver = .{};
    const input = @import("bot_input.zig");
    const previous = input.submitting;
    defer input.submitting = previous;
    input.submitting = null;
    try std.testing.expect(driver.acceptsInput(0));
    driver.enabled = true;
    try std.testing.expect(driver.acceptsInput(0));
    driver.rendered = true;
    try std.testing.expect(!driver.acceptsInput(0));
    try std.testing.expect(driver.acceptsInput(1));
    input.submitting = 1;
    try std.testing.expect(!driver.acceptsInput(0));
    input.submitting = 0;
    try std.testing.expect(driver.acceptsInput(0));
}
