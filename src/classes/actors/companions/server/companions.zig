// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Party spawning, orders and class-owned weapon execution. What a companion
//! wants is companion_brain's; how it moves and aims is the shared pilot's.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const Ref = @import("../../../../mechanics/domain/world_references.zig").Ref;
const access = @import("../../../../mechanics/server/region_access.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const abi = @import("../../../../engine/abi.zig");
const engine = @import("../../../../engine/server.zig");
const c = abi.c;
const v = @import("../../../../core/domain/vector.zig");
const Slots = @import("../../../../engine/slots.zig").Slots;
const policy = @import("actor_catalog").companions;
/// A party member's identity (session_classes.zig `party`).
pub const Identity = policy.Identity;
pub fn find(world: *data.World, identity: policy.Identity) ?ecs.Entity {
    var query = world.queryAccess(data.World.mask(.{data.Companion}), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.Companion)) |entity, companion| if (companion.identity == identity) return entity;
    return null;
}
/// A continuing party member can physically occupy any admitted identity neighbor.
/// Authored destination incarnations remain handled by the local find/arrive path.
pub fn member(world: *data.World, identity: policy.Identity, owner: u32) ?Ref {
    if (find(world, identity)) |entity| if ((world.get(entity, data.Companion) catch unreachable).owner == owner) return .{ .world = world, .entity = entity };
    const context = access.contextFor(world) orelse return null;
    var neighbors = access.Neighbors.init(context);
    while (neighbors.next()) |neighbor| {
        if (&neighbor.world.? == world) continue;
        const entity = find(&neighbor.world.?, identity) orelse continue;
        if ((neighbor.world.?.get(entity, data.Companion) catch unreachable).owner == owner) return .{ .world = &neighbor.world.?, .entity = entity };
    }
    return null;
}
/// Include recruited members in neighboring worlds, including a stopped or
/// carried companion. Unrecruited map actors are not members of Hiro's party.
pub fn healthyParty(world: *data.World, player: ecs.Entity) !bool {
    const eligible = @import("../../../../mechanics/domain/checkpoint.zig").Autosave.healthy;
    const health = (try world.get(player, data.Health)).*;
    if (!eligible(health.current, health.maximum)) return false;
    const owner = try world.persistentId(player);
    for ([_]policy.Identity{ .mikiko, .superfly }) |identity| {
        const follower = member(world, identity, owner) orelse continue;
        const value = (try follower.world.get(follower.entity, data.Health)).*;
        if (!eligible(value.current, value.maximum)) return false;
    }
    return true;
}
pub fn capture(world: *data.World, player: ecs.Entity, episode: u8, now: i64) !@import("../../../../mechanics/domain/travel.zig").Traveler {
    const travel = @import("../../../../mechanics/domain/travel.zig");
    var result = try travel.Traveler.capture(world, player, episode, now);
    const owner = try world.persistentId(player);
    const origin = (try world.get(player, data.Transform)).position;
    for ([_]policy.Identity{ .mikiko, .superfly }, 0..) |identity, index| {
        const follower = member(world, identity, owner) orelse continue;
        result.companions[index] = try travel.Follower.capture(follower.world, follower.entity, origin);
    }
    return result;
}
/// A sidekick starts with its aidata health (Superfly 150, Mikiko 100, skill-scaled): the reference
/// sets 100 and then applies the aidata row over it.
pub fn initialize(world: *data.World, entity: ecs.Entity, episode: u8, table: *const @import("../../../../mechanics/domain/weapons.zig").Table, health: i32, now: i64) !void {
    const classname = (try world.get(entity, data.MapObject)).classname;
    try world.put(entity, data.Companion{ .identity = if (std.mem.eql(u8, classname, "mikiko")) .mikiko else .superfly, .carrying = std.mem.eql(u8, classname, "mikikofly"), .last_ms = now, .motor = .{ .command_ms = now } });
    try world.put(entity, data.Weapons{});
    try world.put(entity, data.Character{});
    try world.put(entity, data.Keys{});
    const starting: i32 = if (health > 0) health else 100;
    (try world.get(entity, data.Health)).* = .{ .current = starting, .maximum = starting };
    if (episode == 1 and !std.mem.eql(u8, classname, "mikikofly")) {
        const weapon = @import("weapon_catalog").starting(1);
        _ = (try world.get(entity, data.Weapons)).acquire(table, weapon, table.entries[weapon].initialAmmo);
    }
}
pub fn start(actors: *@import("../../../../mechanics/server/actors.zig").Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, player: ecs.Entity, entry: []const u8, transfer_mask: ?u2, now: i64) !void {
    if (engine.integer("g_gametype") != c.GT_SINGLE_PLAYER) return;
    const origin = (try world.get(player, data.Transform)).position;
    for ([_][]const u8{ "mikiko", "superfly", "mikikofly" }) |classname| {
        const identity: policy.Identity = if (std.mem.eql(u8, classname, "mikiko")) .mikiko else .superfly;
        if (find(world, identity) != null) continue;
        var expected: [48]u8 = undefined;
        const name = try std.fmt.bufPrint(&expected, "info_{s}_start", .{classname});
        var chosen: ?data.Transform = null;
        var nearest: f32 = std.math.inf(f32);
        var query = world.queryAccess(data.World.mask(.{ data.MapObject, data.Transform }), 0, 0);
        {
            defer query.deinit();
            while (query.next()) |view| for (view.read(data.MapObject), view.read(data.Transform)) |object, pose| {
                if (!std.mem.eql(u8, object.classname, name)) continue;
                if (object.targetname.len > 0 and !std.mem.eql(u8, object.targetname, entry)) continue;
                if (object.targetname.len == 0 and (entry.len > 0 or (transfer_mask != null and transfer_mask.? & (@as(u2, 1) << @as(u1, @intCast(@intFromEnum(identity)))) == 0))) continue;
                const distance = v.length(v.subtract(pose.position, origin));
                if (distance < nearest) {
                    chosen = pose;
                    nearest = distance;
                }
            };
        }
        if (chosen) |pose| {
            const entity = try actors.spawnDynamic(world, slots, projections, classname, pose.position, pose.angles, now);
            (try world.get(entity, data.Companion)).owner = try world.persistentId(player);
        }
    }
}
/// Whether a client command belongs to the party (`command`).
pub fn handles(name: []const u8) bool {
    return std.mem.startsWith(u8, name, "sidekick") or std.mem.eql(u8, name, "companion");
}
/// A client command for the party: the window's `sidekick_<command> [who]`, a default bind's
/// `companion <word>`, or `sidekick <who> <order>`. Returns null when the command is not the party's,
/// otherwise whether any member took the order. `target` and `point` are what the owner aims at.
pub fn command(actors: *const @import("../../../../mechanics/server/actors.zig").Actors, world: *data.World, now: i64, player: ecs.Entity, name: []const u8, first: []const u8, second: []const u8, target: u32, point: v.Vec3) !?bool {
    if (std.mem.startsWith(u8, name, "sidekick_")) {
        const requested = policy.parseCommand(name["sidekick_".len..]) orelse return null;
        return try give(actors, world, now, player, if (first.len == 0) "all" else first, requested, target, point);
    }
    if (std.mem.eql(u8, name, "companion")) {
        const requested = policy.parseCommand(first) orelse return false;
        return try give(actors, world, now, player, if (second.len == 0) "all" else second, requested, target, point);
    }
    if (std.mem.eql(u8, name, "sidekick")) return try order(actors, world, now, player, first, second, target, point);
    return null;
}
pub fn order(actors: *const @import("../../../../mechanics/server/actors.zig").Actors, world: *data.World, now: i64, player: ecs.Entity, name: []const u8, command_name: []const u8, target: u32, point: v.Vec3) !bool {
    const requested = policy.parseCommand(command_name) orelse return false;
    return give(actors, world, now, player, name, requested, target, point);
}
fn give(actors: *const @import("../../../../mechanics/server/actors.zig").Actors, world: *data.World, now: i64, player: ecs.Entity, name: []const u8, requested: policy.Order, target: u32, point: v.Vec3) !bool {
    const context = access.contextFor(world) orelse return error.PartyWorldUnavailable;
    var candidates = access.Damageables.init(world, &context.slots);
    const owner_pose = (try world.get(player, data.Transform)).*;
    var changed = false;
    while (candidates.next()) |ref| {
        const companion = ref.get(data.Companion) catch continue;
        if (!std.mem.eql(u8, name, "all") and !std.mem.eql(u8, name, @tagName(companion.identity))) continue;
        if ((try ref.get(data.Health)).current <= 0 or !companion.enabled) continue;
        var chosen = requested;
        var refused = false;
        if (requested == .collect) {
            const allowed = if (ref.world.find(target)) |item| try @import("companion_items.zig").allows(ref.world, ref.entity, item, &actors.weapons, actors.episode, true, now) else false;
            refused = !allowed;
        }
        if (requested == .attack) {
            // With nothing aimed at, the reference only makes the sidekick willing to fight again.
            if (target == 0) {
                chosen = .follow;
            } else if (access.find(world, target)) |enemy| {
                const target_actor = enemy.get(data.Actor) catch null;
                const kind = if (target_actor) |actor| @import("actor_catalog").entries[actor.definition].kind else .companion;
                refused = target_actor == null or kind == .companion or kind == .civilian or @import("actor_catalog").ambient(kind) or companion.carrying or (try enemy.get(data.Health)).current <= 0;
            } else refused = true;
        }
        try acknowledge(ref, companion, owner_pose.position, requested, refused, now);
        if (engine.integer("developer") >= 1) {
            var text: [128]u8 = undefined;
            engine.print(std.fmt.bufPrintZ(&text, "dk3 companion order: {s} {s} -> {s} refused={d}\n", .{ @tagName(companion.identity), @tagName(requested), @tagName(chosen), @intFromBool(refused) }) catch "dk3 companion order\n");
        }
        if (refused) continue;
        companion.collecting = if (chosen == .collect) target else 0;
        companion.collect_forced = chosen == .collect;
        companion.collect_until_ms = now + 15000;
        companion.yielding_until_ms = 0;
        (try ref.get(data.Actor)).route = .{};
        @import("companion_pilot.zig").forget(try ref.id());
        companion.owner = try world.persistentId(player);
        companion.order = chosen;
        companion.target = if (chosen == .attack) target else if (chosen == .collect) target else 0;
        companion.stopped = false;
        companion.authored = .none;
        companion.animation_until = null;
        (try ref.get(data.Actor)).scripted_pose = null;
        if (chosen == .move) {
            companion.destination = if (access.find(world, target)) |destination| (try destination.get(data.Transform)).position else point;
        }
        // Come here: a spot 64 units in front of the owner (reference SIDEKICK_COMMAND_COMEHERE).
        if (chosen == .come) companion.destination = v.add(owner_pose.position, v.scale(v.basis(.{ 0, owner_pose.angles[1], 0 }).forward, 64));
        changed = true;
    }
    return changed;
}
/// The sidekick answers an order it hears in the owner's sight (reference SIDEKICK_CommandAcknowledge:
/// in the owner's PVS, not over another line).
fn acknowledge(ref: Ref, companion: *data.Companion, owner: v.Vec3, order_given: policy.Order, refused: bool, now: i64) !void {
    if (now < companion.talk_ready_ms) return;
    const position = (try ref.get(data.Transform)).position;
    if (!engine.inPvs(position, owner)) return;
    var buffer: [80]u8 = undefined;
    const variation: u2 = @intCast(@mod(now, 3));
    const line = if (refused and order_given != .collect)
        std.fmt.bufPrint(&buffer, "sounds/voices/{s}_no_0{d}.mp3", .{ if (companion.identity == .mikiko) "mikiko/cmd_mi" else "superfly/cmd_su", @as(u3, variation % 2) + 2 }) catch return
    else
        policy.acknowledgement(companion.identity, order_given, refused, variation, &buffer) orelse return;
    const context = access.contextFor(ref.world) orelse return;
    companion.talk_ready_ms = now + 1000;
    const distance = v.length(v.subtract(owner, position));
    try @import("../../../../mechanics/server/events.zig").configuredSound(ref.world, &context.slots, &context.projection, line, position, (try ref.get(data.Binding)).slot, c.CHAN_VOICE, now, .{ .volume = @import("companion_talk.zig").volume(distance), .nondirectional = true });
}
/// Session hook: each party member's status for the owner's HUD flaps (reference SetMikikoStats,
/// SetSflyStats and SIDEKICK_UpdateWeaponStatus), in the player-state stats the policy reserves.
pub fn status(world: *data.World, player: ecs.Entity, state: *c.playerState_t, table: *const @import("../../../../mechanics/domain/weapons.zig").Table) !void {
    const owner = try world.persistentId(player);
    const eye = v.add((try world.get(player, data.Transform)).position, .{ 0, 0, 22 });
    for ([_]policy.Identity{ .mikiko, .superfly }) |identity| {
        var value: policy.Status = .{};
        const found: ?Ref = member(world, identity, owner) orelse if (find(world, identity)) |entity| (if ((try world.get(entity, data.Companion)).owner == 0) Ref{ .world = world, .entity = entity } else null) else null;
        if (found) |ref| {
            const health = (try ref.get(data.Health)).*;
            const loadout = (try ref.get(data.Weapons)).*;
            const position = (try ref.get(data.Transform)).position;
            value.exists = true;
            value.visible = ref.world == world and engine.inPvs(eye, v.add(position, .{ 0, 0, 22 }));
            value.health_pct = @intCast(std.math.clamp(@divTrunc(@max(health.current, 0) * 100, @max(health.maximum, 1)), 0, 100));
            value.armor_pct = @intCast(std.math.clamp(@divTrunc(health.armor * 100, @import("../../../../game/domain/item_classes.zig").armorCapacity(health.armor, health.absorption)), 0, 100));
            if (@import("weapon_catalog").find(@intCast(std.math.clamp(loadout.weapon, 0, 31)))) |entry| {
                const tuning = table.entries[entry.id];
                value.ammo = policy.ammoLevel(identity, loadout.weapon > 0, tuning.ammoCost > 0, (entry.spec.bot_range orelse tuning.range) > 128, loadout.ammo[entry.id], tuning.ammoMax);
            }
        }
        const words = value.pack();
        state.stats[policy.statIndex(identity)] = words[0];
        state.stats[policy.statIndex(identity) + 1] = words[1];
    }
}
pub fn combat(actors: *const @import("../../../../mechanics/server/actors.zig").Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, table: *const @import("../../../../mechanics/domain/weapons.zig").Table, now: i64, elapsed: u32) !void {
    const occupants = slots.occupants;
    for (occupants) |occupant| {
        const entity = occupant orelse continue;
        const companion = world.get(entity, data.Companion) catch continue;
        const health = (try world.get(entity, data.Health)).current;
        if (health <= 0) {
            if (!companion.death_reported) {
                if (access.find(world, companion.owner)) |owner| if ((try owner.get(data.Health)).current > 0) {
                    const actor = (try world.get(entity, data.Actor)).*;
                    const player = try owner.get(data.Player);
                    player.mode = .frozen;
                    if (now >= actor.changed_ms + actors.table.definitions[actor.definition].death.duration()) {
                        player.mode = .dead;
                        companion.death_reported = true;
                        engine.send(0, "cp \"A companion has died. Load a saved game to continue.\"");
                    }
                    if (access.contextFor(owner.world)) |context| {
                        const scope = try context.select();
                        defer scope.deinit();
                        try @import("../../../../mechanics/server/weapon_actions.zig").cancel(owner.world, &context.slots, &context.projection, owner.entity);
                    } else try @import("../../../../mechanics/server/weapon_actions.zig").cancel(owner.world, slots, projections, owner.entity);
                };
            }
            continue;
        }
        const pose = (try world.get(entity, data.Transform)).*;
        const slot = (try world.get(entity, data.Binding)).slot;
        const loadout = try world.get(entity, data.Weapons);
        // The pilot chose the weapon and whether to pull the trigger this
        // frame; the companion's own weapon step raises, fires and reloads.
        const decided = @import("companion_pilot.zig").output(try world.persistentId(entity), now);
        if (decided) |choice| companion.selected_weapon = if (companion.carrying or loadout.dk3Inventory & (@as(i32, 1) << choice.weapon) == 0) 0 else choice.weapon;
        if (loadout.weapon == 0 and companion.selected_weapon == 0) continue;
        var events: @import("../../../../mechanics/domain/weapons.zig").Events = .{};
        var context: @import("../../../../mechanics/domain/weapons.zig").Context = .{ .ps = loadout, .table = table, .events = &events, .service = engine.collisionService(), .slot = slot, .shot_mask = c.MASK_SHOT, .single_player = true };
        var player = companion.motor;
        var motion: @import("../../../../core/domain/slide.zig").State = .{ .position = pose.position, .velocity = @splat(0) };
        const hook = context.hook();
        const target = access.find(world, (try world.get(entity, data.Actor)).threat);
        // The weapon's own leader-safety lane stays the last word.
        const wants_fire = companion.enabled and !companion.stopped and !companion.carrying and companion.selected_weapon != 0 and (if (decided) |choice| choice.fire else false) and !@import("../../../../mechanics/server/held.zig").held(world, entity) and (if (target) |enemy| try @import("companion_weapons.zig").clear(world, entity, enemy, companion.selected_weapon, table) else false);
        try hook.run_fn(hook.context, &player, &motion, .{ .time_ms = now, .angles = pose.angles, .weapon = if (companion.selected_weapon > 0) companion.selected_weapon else @intCast(loadout.weapon), .attack = wants_fire }, @min(elapsed, 200));
        for (events.values[0..events.count]) |event| switch (event) {
            .fired => |shot| try @import("../../../../mechanics/server/combat.zig").fire(world, slots, projections, entity, shot, table, now),
            .no_ammo => {},
        };
    }
}

pub fn camera(world: *data.World, player: ecs.Entity, state: *c.playerState_t) !void {
    if ((try world.get(player, data.Player)).mode == .normal) return;
    const owner = try world.persistentId(player);
    var query = world.queryAccess(data.World.mask(.{data.Companion}), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.Companion)) |entity, companion| {
        if (companion.owner != owner or (try world.get(entity, data.Health)).current > 0) continue;
        const pose = (try world.get(entity, data.Transform)).*;
        const focus = v.add(pose.position, .{ 0, 0, 12 });
        const desired = v.add(focus, v.add(v.scale(v.basis(pose.angles).forward, -96), .{ 0, 0, 48 }));
        const hit = try engine.collisionService().trace(.{ .start = focus, .end = desired, .mins = .{ -4, -4, -4 }, .maxs = .{ 4, 4, 4 }, .slot = (try world.get(entity, data.Binding)).slot, .mask = c.MASK_SOLID });
        const delta = v.subtract(focus, hit.end);
        state.dk3CameraActive = 3;
        state.dk3CameraOrigin = hit.end;
        state.dk3CameraAngles = .{ -std.math.atan2(delta[2], @sqrt(delta[0] * delta[0] + delta[1] * delta[1])) * 180 / std.math.pi, std.math.atan2(delta[1], delta[0]) * 180 / std.math.pi, 0 };
        state.dk3CameraFov = 90;
        return;
    };
}
pub fn required(world: *data.World, player: ecs.Entity, flags: u32) !bool {
    const origin = (try world.get(player, data.Transform)).position;
    for ([_]policy.Identity{ .mikiko, .superfly }, [_]u32{ 4, 2 }) |identity, bit| {
        if (flags & bit == 0) continue;
        const entity = member(world, identity, try world.persistentId(player)) orelse return false;
        if ((try entity.get(data.Health)).current <= 0) return false;
        const pose = (try entity.get(data.Transform)).position;
        if (v.length(v.subtract(pose, origin)) >= 150) return false;
    }
    return true;
}

pub fn arrive(actors: *@import("../../../../mechanics/server/actors.zig").Actors, world: *data.World, slots: *Slots, projections: []abi.EntityProjection, player: ecs.Entity, traveler: @import("../../../../mechanics/domain/travel.zig").Traveler, journey: @import("../../../../mechanics/domain/travel.zig").Journey, now: i64) !void {
    for (traveler.companions) |maybe| if (maybe) |follower| {
        var found = find(world, follower.state.identity);
        if (found == null and journey.kind == .submap and journey.companions & (@as(u2, 1) << @as(u1, @intCast(@intFromEnum(follower.state.identity)))) != 0) {
            const origin = v.add((try world.get(player, data.Transform)).position, follower.offset);
            found = try actors.spawnDynamic(world, slots, projections, follower.classname, origin, follower.angles, now);
        }
        const entity = found orelse continue;
        (try world.get(entity, data.Health)).* = follower.health;
        (try world.get(entity, data.Weapons)).* = follower.weapons;
        (try world.get(entity, data.Character)).* = follower.character;
        (try world.get(entity, data.Keys)).* = follower.keys;
        (try world.get(entity, data.Ailments)).* = follower.ailments;
        var state = follower.state;
        state.carrying = (try world.get(entity, data.Companion)).carrying;
        state.owner = try world.persistentId(player);
        (try world.get(entity, data.Companion)).* = state;
        (try world.get(entity, data.Actor)).threat = 0;
        (try world.get(entity, data.Actor)).mode = .idle;
        (try world.get(entity, data.Actor)).route = .{};
        (try world.get(entity, data.Velocity)).linear = @splat(0);
        try actors.publish(world, entity, projections, now);
    };
}

test "autosaves require healthy recruited companions even when stopped or carried" {
    var world = data.World.init(std.testing.allocator, 8);
    defer world.deinit();
    const player = try world.create(1, .{data.Health{ .current = 91 }});
    const mikiko = try world.create(2, .{ data.Health{ .current = 180, .maximum = 200 }, data.Companion{ .identity = .mikiko, .owner = 1, .carrying = true } });
    const superfly = try world.create(3, .{ data.Health{ .current = 100 }, data.Companion{ .identity = .superfly, .owner = 1, .stopped = true } });
    try std.testing.expect(!try healthyParty(&world, player));
    (try world.get(mikiko, data.Health)).current = 181;
    try std.testing.expect(try healthyParty(&world, player));
    (try world.get(superfly, data.Health)).current = 0;
    try std.testing.expect(!try healthyParty(&world, player));
    (try world.get(superfly, data.Companion)).owner = 0;
    try std.testing.expect(try healthyParty(&world, player));
    (try world.get(player, data.Health)).current = 90;
    try std.testing.expect(!try healthyParty(&world, player));
}
/// World-system hook (world_system_classes.zig): the party fights.
pub fn worldStep(frame: *const @import("../../../../mechanics/server/system_context.zig").Step) !void {
    try combat(frame.actors, frame.world, frame.slots, frame.projections, frame.table, frame.now, frame.elapsed);
}
/// Whether a party member may collect this pickup now (session_classes.zig `party`).
pub const allowsPickup = @import("companion_items.zig").allows;
/// Whether an entity is a party member (session_classes.zig `party`).
pub fn isMember(world: *data.World, entity: ecs.Entity) bool {
    return (world.get(entity, data.Companion) catch null) != null;
}
/// A member's eye height, for exposure checks; null for non-members.
pub fn viewHeight(world: *data.World, entity: ecs.Entity) ?f32 {
    return if (world.get(entity, data.Companion) catch null) |party_member| party_member.motor.view_height else null;
}
/// A member that changed worlds lands with no ground under it yet.
pub fn afterTransfer(world: *data.World, entity: ecs.Entity) void {
    if (world.get(entity, data.Companion) catch null) |party_member| party_member.motor.ground_entity = c.ENTITYNUM_NONE;
}
/// Whether a member collects this pickup now; null when the collector is not a member.
pub fn collects(world: *data.World, collector: ecs.Entity, pickup: ecs.Entity, table: *const @import("../../../../mechanics/domain/weapons.zig").Table, episode: u8, now: i64) !?bool {
    const party_member = (world.get(collector, data.Companion) catch return null).*;
    if (party_member.collecting != try world.persistentId(pickup) or party_member.stopped) return false;
    return try allowsPickup(world, collector, pickup, table, episode, party_member.collect_forced, now);
}
/// The farthest living member an exit with these spawnflags waits for (bit 2 Superfly, bit 4
/// Mikiko), or null.
pub fn farthestRequired(world: *data.World, here: v.Vec3, flags: u32) ?v.Vec3 {
    var farthest: ?v.Vec3 = null;
    var distance: f32 = 0;
    var members = world.queryAccess(data.World.mask(.{ data.Companion, data.Health, data.Transform }), 0, 0);
    defer members.deinit();
    while (members.next()) |view| for (view.read(data.Companion), view.read(data.Health), view.read(data.Transform)) |party_member, vitality, place| {
        const bit: u32 = if (party_member.identity == .mikiko) 4 else 2;
        if (flags & bit == 0 or vitality.current <= 0) continue;
        const span = v.length(v.subtract(place.position, here));
        if (span <= distance) continue;
        distance = span;
        farthest = place.position;
    };
    return farthest;
}
/// `identity:health@distance:order,` per member, for bot diagnostics.
pub fn summary(world: *data.World, here: v.Vec3, buffer: []u8) []const u8 {
    var used: usize = 0;
    var members = world.queryAccess(data.World.mask(.{ data.Companion, data.Health, data.Transform }), 0, 0);
    defer members.deinit();
    while (members.next()) |view| for (view.read(data.Companion), view.read(data.Health), view.read(data.Transform)) |party_member, vitality, place| {
        const piece = std.fmt.bufPrint(buffer[used..], "{s}:{d}@{d:.0}:{s},", .{ @tagName(party_member.identity), vitality.current, v.length(v.subtract(place.position, here)), @tagName(party_member.order) }) catch break;
        used += piece.len;
    };
    return buffer[0..used];
}
/// The player a member follows, or null for non-members.
pub fn leader(world: *data.World, entity: ecs.Entity) ?u32 {
    return if (world.get(entity, data.Companion) catch null) |party_member| party_member.owner else null;
}
