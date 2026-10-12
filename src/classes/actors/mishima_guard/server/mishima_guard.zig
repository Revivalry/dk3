// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: mishima_guard. Server adapter: target intake, the eight-round pistol cycle, pain,
//! fighting from cover, side-steps, wandering and the do-not-move flag, and what the guard shows
//! meanwhile. Reference: mishimaguard.cpp (docs/class-porting/mishima_guard.md); the pure cycle
//! lives in src/actors/mishima_guard.zig, cover and wander are shared mechanisms.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const access = @import("../../../../mechanics/server/region_access.zig");
const Ref = @import("../../../../mechanics/domain/world_references.zig").Ref;
const rules = @import("../../../../mechanics/domain/actors.zig");
const animation = @import("../../../../core/domain/animation.zig");
const abi = @import("../../../../engine/abi.zig");
const engine = @import("../../../../engine/server.zig");
const v = @import("../../../../core/domain/vector.zig");
const context = @import("../../../../mechanics/server/actor_classes/frame.zig");
const common = @import("../../../../mechanics/server/actor_classes/common.zig");
const catalog = @import("actor_catalog");
const spawnflags = catalog.spawnflags;
const c = abi.c;
pub const policy = catalog.mishima;
pub const attacks: []const []const u8 = &policy.attacks;
/// Hide nodes and wander legs come from the ground node graph.
pub const routes: context.Routes = .{ .ground = true };

pub fn loadAnimations(load: context.Load) !void {
    load.definition.reload = try animation.find(load.metadata, policy.reload_animation) orelse return error.MissingActorReload;
    load.definition.walk = try animation.find(load.metadata, policy.walk_animation) orelse return error.MissingActorWalk;
}
/// The living guard's pistol is drawn by its client render class.
pub fn decorate(decoration: *context.Decoration) !void {
    if (decoration.view.actor.mode != .dead) decoration.state.time2 = policy.render_tag;
}
pub fn spawn(spawning: *context.Spawn) !void {
    // Each guard's spread and pose rolls are its own sequence.
    (try spawning.actor()).guard.random = try spawning.world.persistentId(spawning.entity);
}
/// Firing and reloading play the cycle's clip from its start; between bursts the last attack clip
/// holds, as in the reference.
pub fn playback(view: context.View) !?animation.Playback {
    const actor = view.actor;
    if (actor.mode == .dead or actor.reaction != null or actor.scripted_pose != null) return null;
    return switch (actor.mode) {
        .attack => .{ .sequence = view.definition.attacks[actor.guard.pose], .started = actor.guard.started_ms, .looping = false },
        .reload => .{ .sequence = view.definition.reload, .started = actor.guard.started_ms, .looping = false },
        .chase => if (actor.roam.destination != null) view.moded(view.definition.walk, view.modeStarted()) else null,
        else => null,
    };
}
pub fn diagnose(view: context.View, writer: *std.Io.Writer) !void {
    const actor = view.actor;
    try writer.print(" guard_phase={s} rounds={d}", .{ @tagName(actor.guard.phase), actor.guard.rounds });
    if (actor.roam.destination) |point| try writer.print(" roam={d:.0},{d:.0},{d:.0}", .{ point[0], point[1], point[2] });
    if (actor.evasion.until_ms) |until| try writer.print(" sidestep_until={d}", .{until});
}
/// Wander legs walk; cover runs and looks run to their own point, not the enemy's last position.
pub fn move(frame: *context.Frame) !void {
    const actor = frame.actor;
    if (actor.mode != .chase or actor.evasion.until_ms != null) return common.move(frame);
    const point, const speed = if (actor.roam.destination) |point| .{ point, frame.definition.walk_speed } else if (@import("../../../../mechanics/server/actor_cover.zig").destination(frame)) |point| .{ point, frame.definition.speed } else return common.move(frame);
    try common.moveTo(frame, point, speed);
}
/// Cycle durations from the model's attack and reload clips.
fn timing(definition: *const rules.Definition) policy.Timing {
    var result: policy.Timing = undefined;
    for (definition.attacks[0..3], definition.strikes[0..3], 0..) |sequence, strike, i| {
        result.attack_ms[i] = @divTrunc(@as(i64, sequence.last - sequence.first + 1) * 1000, sequence.fps);
        result.strike_ms[i] = @divTrunc(@as(i64, strike) * 1000, sequence.fps);
    }
    result.reload_ms = @divTrunc(@as(i64, definition.reload.last - definition.reload.first + 1) * 1000, definition.reload.fps);
    result.reload_sound_ms = @divTrunc(@as(i64, policy.reload_sound_frame) * 1000, definition.reload.fps);
    return result;
}

fn alivePlayer(entity: Ref) bool {
    if (entity.get(data.Player) catch null) |player| {
        if (player.mode != .normal) return false;
    } else if ((entity.get(data.Companion) catch null) == null) return false;
    return if (entity.get(data.Health)) |health| health.current > 0 else |_| false;
}
fn trace(start: v.Vec3, end: v.Vec3, slot: u16, mask: u32) !@import("../../../../core/domain/collision.zig").Trace {
    return @import("../../../../mechanics/server/region_collision.zig").trace(.{ .start = start, .end = end, .mins = @splat(0), .maxs = @splat(0), .slot = slot, .mask = mask });
}
pub fn think(frame: *context.Frame) !void {
    const world = frame.world;
    const slots = frame.slots;
    const projections = frame.projections;
    const entity = frame.entity;
    const actor = frame.actor;
    const pose = frame.pose;
    const definition = frame.definition;
    const now = frame.now;
    const owner_id = try world.persistentId(entity);
    const slot = (try world.get(entity, data.Binding)).slot;
    const eye = v.add(pose.position, .{ 0, 0, 24 });
    const receipt = (try world.get(entity, data.Hurt)).*;
    const injured = receipt.revision != actor.receipt;
    if (injured) {
        actor.receipt = receipt.revision;
        if (access.find(world, receipt.source)) |attacker| if (alivePlayer(attacker)) {
            actor.threat = receipt.source;
            actor.threat_position = (try attacker.get(data.Transform)).position;
            actor.threat_seen_ms = now;
        };
    }
    const pain = @import("../../../../mechanics/server/actor_pain.zig");
    if (pain.reacting(actor, now)) return;
    if (injured and receipt.amount >= policy.pain_limit and try pain.direct(world, entity, actor, definition.*, receipt.amount, policy.pain_chance, now)) return;
    if (access.find(world, actor.threat)) |enemy| {
        if (!alivePlayer(enemy)) actor.threat = 0;
    } else actor.threat = 0;
    if (actor.threat == 0) {
        var nearest = definition.sight_range;
        var candidates = access.Damageables.init(world, slots);
        while (candidates.next()) |candidate| {
            if (!alivePlayer(candidate)) continue;
            if (candidate.get(data.Character)) |character| {
                if (character.invisible_until > now) continue;
            } else |_| {}
            const position = (try candidate.get(data.Transform)).position;
            const delta = v.add(position, v.scale(pose.position, -1));
            const distance = v.length(delta);
            if (distance > nearest) continue;
            const direction = v.normalize(.{ delta[0], delta[1], 0 });
            if (v.dot(direction, v.basis(pose.angles).forward) < @cos(definition.fov * std.math.pi / 360.0)) continue;
            const sight = try trace(eye, v.add(position, .{ 0, 0, 16 }), slot, c.MASK_SOLID);
            if (!@import("../../../../mechanics/server/region_collision.zig").reaches(world, sight, candidate)) continue;
            actor.threat = try candidate.id();
            actor.threat_position = position;
            actor.threat_seen_ms = now;
            nearest = distance;
        }
    }
    const flags = (try world.get(entity, data.MapObject)).flags;
    const mobile = spawnflags.moves(flags);
    // A side-step runs to its end before the guard fights on.
    if (@import("../../../../mechanics/server/actor_evasion.zig").update(actor, pose.*, now)) {
        actor.cover.reset();
        return;
    }
    // Spawnflag 512: once it has an enemy the guard fights from cover and never chases.
    const covering = flags & spawnflags.take_cover != 0 and actor.threat != 0;
    var clear = false;
    var start = eye;
    var aim = eye;
    var in_sight = false;
    var complete = false;
    if (access.find(world, actor.threat)) |enemy| {
        const target = (try enemy.get(data.Transform)).position;
        const delta = v.add(target, v.scale(pose.position, -1));
        const sight = try trace(eye, v.add(target, .{ 0, 0, 16 }), slot, c.MASK_SOLID);
        in_sight = @import("../../../../mechanics/server/region_collision.zig").reaches(world, sight, enemy);
        if (in_sight) {
            actor.threat_position = target;
            actor.threat_seen_ms = now;
        }
        if (covering) complete = try @import("../../../../mechanics/server/actor_cover.zig").completelyVisible(world, pose.*, frame.body.*, slot, enemy);
        const remembered = v.subtract(actor.threat_position, pose.position);
        if (remembered[0] != 0 or remembered[1] != 0) pose.angles[1] = std.math.atan2(remembered[1], remembered[0]) * (180.0 / std.math.pi);
        const axes = v.basis(pose.angles);
        start = v.add(pose.position, v.add(v.scale(axes.right, definition.offset[0]), v.add(v.scale(axes.forward, definition.offset[1]), .{ 0, 0, definition.offset[2] })));
        start = (try trace(eye, start, slot, c.MASK_SHOT)).end;
        aim = v.add(target, .{ 0, 0, 8 });
        const hit = try trace(start, aim, slot, c.MASK_SHOT);
        const visible = @import("../../../../mechanics/server/region_collision.zig").reaches(world, hit, enemy);
        if (visible) {
            actor.threat_position = target;
            actor.threat_seen_ms = now;
        } else if (now - actor.threat_seen_ms >= 10000) actor.threat = 0;
        clear = visible and v.length(delta) <= definition.range;
    }
    const sounds = @import("../../../../mechanics/server/actor_attack_sounds.zig");
    // Consume the outgoing pose before tick can complete it. Its last frame can
    // be crossed on the same update that returns the guard to ready.
    if (actor.guard.phase == .firing) try sounds.at(world, slots, projections, entity, actor, definition.*, @intCast(actor.guard.pose), actor.guard.started_ms, now, 3);
    // From cover it shoots only while the enemy is completely visible.
    const event = actor.guard.tick(now, if (covering) clear and complete else clear, timing(definition), if (covering) .cover else .cycle);
    if (event.blocked and try @import("../../../../mechanics/server/actor_evasion.zig").sidestep(world, entity, actor, pose.*, now)) {
        actor.cover.reset();
        actor.changed_ms = now;
        return;
    }
    var mode: rules.Mode = switch (actor.guard.phase) {
        .firing => .attack,
        .reloading => .reload,
        .ready, .recovering => if (actor.threat == 0) .idle else if (covering) .idle
        // Between bursts the guard only faces its enemy: the last attack clip holds instead of
        // dropping into an idle ambient.
        else if (!clear and @import("../../../../core/domain/navigation.zig").horizontalDistance(pose.position, actor.threat_position) > 20) (if (mobile) .chase else if (in_sight) .attack else .idle) else .attack,
    };
    if (actor.threat != 0) actor.roam.destination = null;
    if (actor.threat == 0 or actor.guard.phase == .firing) actor.cover.reset();
    if (mode == .idle and actor.threat == 0 and mobile and spawnflags.wanders(flags)) {
        if (try common.roam(frame)) mode = .chase;
    } else if (mode == .idle and covering and mobile) {
        if (try @import("../../../../mechanics/server/actor_cover.zig").between(frame, in_sight, &actor.guard)) mode = .chase;
    }
    if (mode != actor.mode) actor.changed_ms = now;
    actor.mode = mode;
    if (event.fire) {
        const axes = v.basis(pose.angles);
        var target = v.add(aim, v.scale(axes.right, (actor.guard.fraction() * 2 - 1) * definition.spread[0]));
        target[2] += (actor.guard.fraction() * 2 - 1) * definition.spread[1];
        const direction = v.normalize(v.add(target, v.scale(start, -1)));
        const hit = try trace(start, v.add(start, v.scale(direction, definition.range)), slot, c.MASK_SHOT);
        const admitted = catalog.weapon.damageAdmitted(@intCast(std.math.clamp(engine.integer("g_spSkill"), 1, 5)), actor.guard.fraction());
        if (access.victim(world, slots, hit)) |victim| if (admitted) {
            const amount = definition.damage + actor.guard.fraction() * definition.random_damage;
            _ = try @import("../../../../mechanics/server/damage.zig").apply(victim.world, victim.entity, @intFromFloat(@ceil(amount)), now, .{ .source = owner_id });
        };

        if (engine.integer("developer") != 0) {
            var buffer: [160]u8 = undefined;
            engine.print(try std.fmt.bufPrintZ(&buffer, "dk3 zig guard: id={d} fired rounds={d} enemy={d} now={d}\n", .{ owner_id, actor.guard.rounds, actor.threat, now }));
        }
    }
    if (actor.guard.phase == .firing) try sounds.at(world, slots, projections, entity, actor, definition.*, @intCast(actor.guard.pose), actor.guard.started_ms, now, 3);
    if (event.reload_sound) {
        try @import("../../../../mechanics/server/events.zig").sound(world, slots, projections, policy.reload_sound, pose.position, slot, c.CHAN_AUTO, now);
        var buffer: [128]u8 = undefined;
        engine.print(try std.fmt.bufPrintZ(&buffer, "dk3 zig guard: id={d} reload sound dispatched\n", .{owner_id}));
    }
}

test "firing and reloading show the cycle's clip, and other states fall back to the shared mapping" {
    var definition: rules.Definition = .{};
    definition.attacks[2] = .{ .first = 30, .last = 39 };
    definition.reload = .{ .first = 50, .last = 69 };
    var actor: data.Actor = .{ .definition = @import("actor_catalog").find("monster_mishimaguard").?, .mode = .attack };
    actor.guard.pose = 2;
    actor.guard.started_ms = 1234;
    const view: context.View = .{ .kind = .mishima_guard, .actor = &actor, .definition = &definition, .now = 0 };
    try std.testing.expectEqual(@as(u16, 30), (try playback(view)).?.sequence.first);
    try std.testing.expectEqual(@as(i64, 1234), (try playback(view)).?.started);
    try std.testing.expect(!(try playback(view)).?.looping);
    actor.mode = .reload;
    try std.testing.expectEqual(@as(u16, 50), (try playback(view)).?.sequence.first);
    actor.mode = .chase;
    try std.testing.expect(try playback(view) == null);
    actor.mode = .attack;
    actor.reaction = definition.idle;
    try std.testing.expect(try playback(view) == null);
}
