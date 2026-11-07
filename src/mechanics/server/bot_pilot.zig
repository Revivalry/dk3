// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Body-agnostic bot locomotion and combat shared by the co-op player bot and
//! the companions. Converts one frame of intent into a movement command (view,
//! world-space heading, buttons): AAS routing, authored route controls, lifts,
//! teleporter passages, hazard avoidance and hostile engagement. Nothing here
//! moves entities or changes inventory; the caller's sink runs the shared
//! player motor (a user command for a client, `player_move.run` for a body
//! that has its own motor state).
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const engine = @import("../../engine/server.zig");
const c = abi.c;
const v = @import("../../core/domain/vector.zig");
const nav = @import("../../core/domain/navigation.zig");
const steering = @import("../../core/domain/navigation_input.zig");
const skill = @import("../domain/bot_skill.zig");
const combat = @import("../domain/bot_combat.zig");
const route = @import("../domain/coop_route.zig");
const routes = @import("bot_routes.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const catalog = @import("actor_catalog");
const evasion = @import("bot_evasion.zig");
const collision_module = @import("../../core/domain/collision.zig");
const weapons = @import("../domain/weapons.zig");
const Ref = @import("../domain/world_references.zig").Ref;
const access = @import("region_access.zig");

/// A target this weak is finished even by a body told to hold its fire.
pub const finish_health: i32 = 15;
pub const Hull = struct {
    mins: v.Vec3 = .{ -15, -15, -24 },
    maxs: v.Vec3 = .{ 15, 15, 32 },
};
/// What the body may do beyond walking and fighting. A player bot does it
/// all; a companion never presses controls, never takes teleporter detours
/// on its own, and has no campaign exits to keep out of.
pub const Capabilities = struct {
    /// Authored route controls (buttons, touch plates, shootable switches)
    /// detoured to and operated when a closed gate holds the way.
    controls: bool = true,
    /// Send or call a lift with its control; otherwise only ride it.
    operate_lifts: bool = true,
    /// Teleporter passages taken when the area graph stalls.
    passages: bool = true,
    /// Campaign exit volumes other than the intended one are avoided.
    /// Lethal hazards and harmful liquids are avoided regardless.
    exits: bool = true,
    use: bool = true,
    /// A civilian blocking a narrow passage for seconds may be shot.
    nuisance: bool = true,
    /// Ambient wildlife is no enemy.
    ignore_ambient: bool = false,
    /// Being hit turns the view toward the shooter's bearing (with the
    /// ladder's error) when nothing else holds it.
    alert: bool = false,
    /// With nothing to fight or operate, look around (the ladder's scan
    /// headings) while walking the route.
    sweep: bool = false,
    /// Keep the last rounds of a ranged weapon for a kill order or an
    /// authored target (the campaign's scarce ammunition).
    conserve_ammo: bool = true,
    /// Step aside for an allied player blocking the way.
    yield_to_allies: bool = false,
    /// Duck while standing to shoot (a shooter's rounds aimed at the chest
    /// mostly pass over a crouched player), and put blast weapons away when
    /// badly hurt while another weapon reaches.
    duck_to_shoot: bool = true,
    /// Careful footing for a body nothing authored leads (a party member):
    /// the lethal-liquid guard covers straight steering as well, looks as far
    /// ahead as the body would slide before stopping (further on slick
    /// floor), counter-steers a slide toward lethal liquid, never hops to
    /// land in it, and climbs straight out of any it ends up in.
    careful_footing: bool = false,
    /// A body that breathes like a player and is not following a dive keeps
    /// its head above water: idle or under way, it rises to the surface
    /// instead of sinking (an idle swimmer otherwise sinks).
    tread_water: bool = false,
};
/// Who this body fights: hostile actors (campaign), or the enemy players of
/// a match (by team alliance).
pub const Targets = union(enum) {
    actors,
    players: struct { entities: []const ?ecs.Entity, session: data.Session },
    /// A controller explicitly chooses this body, independently of ordinary
    /// hostility/team discovery. Other allies still retain fire protection.
    specified: Ref,
};
/// Team play: a control an ally is already fetching is left to it; the body
/// waits at the gate it opens instead.
pub const Coordination = struct {
    context: *const anyopaque,
    claimed: *const fn (context: *const anyopaque, route_obstacle: u32) bool,
};
/// Weapons this body must not choose against an enemy here (bit per id).
pub const Exclusion = struct {
    context: *const anyopaque,
    mask: *const fn (context: *const anyopaque, frame: Frame, enemy: ?v.Vec3) anyerror!i32,
};
pub const Frame = struct {
    world: *data.World,
    slots: *Slots,
    projections: []abi.EntityProjection,
    service: nav.Service,
    /// Trace/contents for every probe (the engine's for a client, the
    /// region-aware probe for a companion that may stand across a seam).
    collision: collision_module.Collision,
    table: *const weapons.Table,
    /// Engine slot of the body; its traces skip it.
    slot: u16,
    entity: ecs.Entity,
    /// Movement state of the body (the client's player, a companion's motor).
    state: data.Player,
    hull: Hull = .{},
    /// Supplied by the motor owner, so local prediction uses its real tuning.
    motor: ?@import("../domain/player_move.zig").Parameters = null,
    now: i64,
    /// Live navigation gates of this world, for planning past closed ones.
    gates: ?*@import("navigation_gates.zig").State = null,
    /// Enemies may stand in neighbouring resident worlds.
    region: bool = false,
    capabilities: Capabilities = .{},
    targets: Targets = .actors,
    coordination: ?Coordination = null,
    /// Diagnostic view-cone override in degrees (the ladder's otherwise).
    field_of_view: ?f32 = null,
    /// Owner-supplied view speed cap, independent of perception/aim skill.
    turn_rate_limit: ?f32 = null,
    exclusion: ?Exclusion = null,
    /// Least damage of an enabled hazard volume the body keeps out of.
    hazard_damage: i32 = 25,
    liquid_mask: u32 = lethal_liquids,
    /// Clearance kept from a lethal volume (laser barrier, crusher) against
    /// knockback; steps inside it may run alongside but not close in.
    lethal_margin: f32 = 48,
    /// Developer log prefix ("dk3 <label>:").
    label: []const u8 = "coop",
    /// Planning and the authoritative motor must collide with the same clips.
    pub fn motionMask(self: Frame) u32 {
        return (self.world.get(self.entity, data.Body) catch return c.MASK_PLAYERSOLID).collision_mask;
    }
};
pub const Intent = struct {
    destination: ?v.Vec3 = null,
    /// Steer straight at the destination when routing has no answer near it
    /// (thin exit brushes, trigger volumes and authored ground-node segments
    /// can lie outside every connected AAS area).
    direct_radius: f32 = 600,
    /// Steer straight at the destination, ignoring navigation.
    direct: bool = false,
    /// An authored transfer leaves the current mover before its route stops.
    leave_mover: bool = false,
    /// Hold crouch.
    crouch: bool = false,
    /// An authored submerged segment can hold a precise plane through a
    /// low opening; ordinary swimming still follows its navigation waypoint.
    swim_depth: ?f32 = null,
    /// Slow down approaching a precise goal (off for run-ups).
    brake: bool = false,
    /// Fraction of full movement input (a short hop onto a narrow ledge).
    pace: f32 = 1,
    /// The only campaign exit this step may touch; every other exit volume is
    /// avoided so a detour can never travel to an unintended map.
    exit: u32 = 0,
    /// Point the view must face for use/shoot; suppresses automatic engagement aim.
    face: ?v.Vec3 = null,
    /// Absolute view for `look`.
    view: ?[2]f32 = null,
    /// Press use once the view is centred on this engine slot within reach.
    use_slot: ?u16 = null,
    /// Fire at `face` once the shot trace reaches this engine slot.
    shoot_slot: ?u16 = null,
    fight: bool = true,
    /// Persistent id of the actor a kill action pursues; preferred when visible.
    preferred: u32 = 0,
    weapon: ?u5 = null,
    jump: bool = false,
    /// Respawn/death-checkpoint request while dead.
    attack_when_dead: bool = false,
    /// "Press a key to continue" after a campaign ending's intermission.
    press_to_continue: bool = false,
    /// Pull the trigger now (a shotcycler jump), whatever is in view.
    trigger: bool = false,
    /// Fighting from a held position: keep strafing on a short tether here.
    leash: ?v.Vec3 = null,
    /// Horizontal box that evasion and strafing must not leave.
    arena: ?[2][2]f32 = null,
    /// Where the hunted target is believed to be; the view turns there when
    /// nothing is in sight, like a player watching where the boss flew off.
    look_at: ?v.Vec3 = null,
    /// Trigger discipline: hold keeps aiming without firing; finish_only
    /// fires only at a target with almost no health left.
    fire: enum { free, hold, finish_only } = .free,
    /// Meet an enemy head on with a close-quarters weapon, and back off a
    /// brawler while holding a fight. Off: keep the distance there is.
    close_in: bool = true,
    /// Persistent id of a body this one guards: hostiles hunting it are
    /// engaged at any sighted range, as those hunting this body are.
    guard: u32 = 0,
    /// Unprovoked hostiles further than this are let be.
    engage_range: f32 = 450,
};
pub const Report = struct {
    waypoint: ?nav.Waypoint = null,
    blocked: bool = false,
    enemy: u32 = 0,
    enemy_distance: f32 = 0,
    fired: bool = false,
    used: bool = false,
    /// The prey is seen but a shot at it would meet cover first.
    lane_blocked: bool = false,
    /// What the use pressed (a control on the way, or the action's own target).
    used_slot: u16 = c.ENTITYNUM_NONE,
    control: u32 = 0,
    /// Where the bot stands to operate that control.
    control_point: ?v.Vec3 = null,
    passage: u32 = 0,
    no_route: bool = false,
    /// Steering straight at a near goal because the area graph has no way
    /// there (or no area under the body).
    routeless: bool = false,
    /// An unintended exit or a lethal hazard volume stopped this step.
    avoided_exit: u32 = 0,
    /// Survival movement replaced the route step this frame.
    dodging: bool = false,
    enemy_health: i32 = 0,
    /// Three seconds of fire at this target have not hurt it (a ledge or the
    /// water takes the shots): hold fire and find another line.
    futile: bool = false,
    /// Engine slot the forward probe hit (ENTITYNUM_NONE when clear), and
    /// whether local avoidance turned the step around it.
    obstacle: u16 = c.ENTITYNUM_NONE,
    /// Persistent id of what the forward probe hit (0: geometry or nothing).
    obstacle_id: u32 = 0,
    /// Team play: the destination is out of reach for now (nobody opened the
    /// gate in time, or nothing opens it); pursue other goals this long.
    give_up_ms: i64 = 0,
    sidestepped: bool = false,
    /// Standing in lava, slime or nitrogen (careful footing): heading for the
    /// nearest safe floor, or with none found.
    escaping: bool = false,
    escape_failed: bool = false,
    /// Held still on purpose (waiting for a gate to open). A body that drowns
    /// while holding a spot looks, from the outside, exactly like one stuck
    /// against a wall, so the state is reported rather than guessed at.
    holding: bool = false,
    /// Under water how long, and what the breath budget decided: 1 rise to the
    /// air above, 2 swim to open water (or back to the last breath), 3 neither
    /// found, 4 backing out of the corner it was pressed into (a swimmer has no
    /// floor to sidestep against). Authoring evidence for a lost swimmer.
    submerged_ms: i64 = 0,
    breathing: u8 = 0,
    /// The inputs the frame produced (forward, right, up): a body that sits
    /// still because it was told to and one pressed against geometry look the
    /// same in the world, and differ completely in the log.
    input: [3]i8 = .{ 0, 0, 0 },
};
/// One frame of movement input, before any sink encodes it.
pub const Command = struct {
    /// View after the turn-rate limit (pitch, yaw, 0).
    angles: v.Vec3,
    /// Forward and right resolved against `angles` yaw; up is jump/crouch,
    /// ladder climb and swim stroke.
    forward: i8 = 0,
    right: i8 = 0,
    up: i8 = 0,
    attack: bool = false,
    /// A client holding any key (an ending's "press to continue").
    any: bool = false,
    use: bool = false,
    weapon: u5 = 0,
};
pub const Steering = struct { report: Report, command: Command };
/// Look-around headings relative to travel: the sides are swept, never behind.
pub const sweep_headings = [_]f32{ 0, 40, -40, 80, -80, 0 };
/// How long after last being blocked by a civilian the bot stops treating him as
/// in its way (long enough to walk past a worker in a corridor).
const nuisance_forget_ms: i64 = 6000;
pub const Pilot = struct {
    route: nav.State = .{},
    /// Shots at `futile_target` since its health last fell (see Report.futile).
    futile_target: u32 = 0,
    futile_health: i32 = 0,
    futile_ms: i64 = 0,
    futile_shots: u32 = 0,
    /// A weapon whose shots did not hurt `futile_target` (rockets corkscrewing
    /// into a narrow ramp's walls): set aside for it until then.
    spent_weapon: i32 = 0,
    spent_until: i64 = 0,
    hold_fire_until: i64 = 0,
    jump_until: i64 = 0,
    jump_ready: i64 = 0,
    use_ready: i64 = 0,
    control: ?routes.Control = null,
    control_until: i64 = 0,
    seek_ms: i64 = 0,
    unblock_ms: i64 = 0,
    /// Holding still while a gate on the way opens.
    hold_until: i64 = 0,
    /// Routing round lifts until then: one stood away that this body
    /// may not call, with a way on foot.
    lifts_off_until: i64 = 0,
    avoided: u32 = 0,
    avoid_until: i64 = 0,
    passage: ?struct { route: routes.Passage, teleport_bit: bool, until_ms: i64 } = null,
    target: u32 = 0,
    seen_ms: i64 = 0,
    reaction_ready: i64 = 0,
    shot_ready: i64 = 0,
    locked_ms: i64 = 0,
    wobble_ready: i64 = 0,
    noise_yaw: f32 = 0,
    noise_pitch: f32 = 0,
    seed: u32 = 0x5eed,
    step_ms: i64 = 0,
    unstick_until: i64 = 0,
    /// Last stall of a hop refused for the ground beyond the lip (told once a second).
    hop_told_ms: i64 = 0,
    /// When the next climb diagnostic may speak (route authoring).
    climb_told_ms: i64 = 0,
    /// Not before when the next shake loose may be armed. Under water only the
    /// route's own progress can be measured and a dive makes none to count, so
    /// without this the shake is re-armed the moment it ends and never hands
    /// the stroke back to the route at all.
    unstick_ready_ms: i64 = 0,
    unstick_side: f32 = 1,
    strafe_until: i64 = 0,
    strafe_side: f32 = 1,
    detour_side: f32 = 1,
    /// Recently dodged: the strafe tether must not pull back into the blast area.
    dodge_until: i64 = 0,
    dodge_log_ms: i64 = 0,
    scan_until: i64 = 0,
    scan_yaw: f32 = 0,
    submerged_ms: i64 = 0,
    /// Where it last had its head out of the water, and the open water it
    /// heads for when trapped under a ceiling.
    breath_point: ?v.Vec3 = null,
    air_target: ?v.Vec3 = null,
    air_search_ms: i64 = 0,
    /// Whether `air_target` is open water with air above, or the last breath.
    breath_found: bool = false,
    /// Safe floor it climbs out to from lethal liquid (careful footing).
    escape_target: ?v.Vec3 = null,
    escape_search_ms: i64 = 0,
    direct_mark: v.Vec3 = @splat(0),
    direct_ms: i64 = 0,
    /// Ground the area graph had a way from, two seconds behind the body, and
    /// when it was noted. Pressed against a closed control a body has no route
    /// from and cannot operate either: its use line starts inside the thing it
    /// presses. A stride back is the way a player reads the same situation, so
    /// the last ground that was worth standing on is kept to step back to.
    routable_point: v.Vec3 = @splat(0),
    routable_ms: i64 = 0,
    /// Not before when standing off from an unroutable spot may be tried again.
    retreat_until: i64 = 0,
    /// Route step the body is walked to and the last time it was touched: a
    /// step behind the goal must be dropped, not aimed back at.
    waypoint_point: v.Vec3 = @splat(0),
    waypoint_reached_ms: i64 = 0,
    /// A civilian in the way since `blocker_ms`; one that stayed there long
    /// enough becomes the `nuisance` the bot is allowed to shoot.
    blocker: u32 = 0,
    blocker_ms: i64 = 0,
    /// Last time the blocker was met (a hop off it loses touch a moment).
    blocker_seen_ms: i64 = 0,
    nuisance: u32 = 0,
    /// Closest the player came to the current step target, and when.
    approach_point: v.Vec3 = @splat(0),
    approach_best: f32 = 0,
    approach_ms: i64 = 0,
    /// The route's point the player keeps circling (overshooting it each
    /// way against a closed door) and since when.
    hover_point: v.Vec3 = @splat(0),
    hover_ms: i64 = 0,
    direct_fallback_until: i64 = 0,
    /// A goal the area graph cannot reach (a step-up lip into a console's
    /// alcove it has no link for), and the nearest point near it it can.
    near_goal: v.Vec3 = @splat(0),
    near_point: ?v.Vec3 = null,
    near_ms: i64 = 0,
    direct_retry_ms: i64 = 0,
    /// The place the stride now being measured was asked to reach. A straight
    /// line's stall belongs to that line: the measure starts with the stride,
    /// so a body that stood a while at the last goal — firing, waiting for a
    /// lift, held there by the script — is not handed to the area graph on the
    /// first frame of the next one.
    stride_goal: ?v.Vec3 = null,
    committed: ?nav.Waypoint = null,
    committed_until: i64 = 0,
    /// The waypoint chosen before the current one: a route flipping back to
    /// it is two adjacent areas each routing through the other's entrance.
    previous_point: ?v.Vec3 = null,
    level: i32 = 10,
    attempt: u32 = 0,
    /// Hurt revision last seen, and the shooter bearing it turned toward.
    receipt: ?u32 = null,
    alert_yaw: ?f32 = null,
    alert_until: i64 = 0,
    /// Look-around: the heading held and until when.
    sweep_index: usize = 0,
    sweep_until: i64 = 0,
    /// Waiting at a gate an ally opens: where, until when, since when.
    gate_point: ?v.Vec3 = null,
    gate_until: i64 = 0,
    gate_since: i64 = 0,
    /// Stepping aside for an ally: where and until when.
    yield_point: ?v.Vec3 = null,
    yield_until: i64 = 0,
    crush_revision: u32 = 0,
    crush_until: i64 = 0,
    body_step: ?v.Vec3 = null,
    body_step_until: i64 = 0,
    body_step_jump_until: i64 = 0,
    body_step_crouch: bool = false,

    /// Per-attempt variation of the bot's own choices (strafe/detour sides,
    /// dodge ordering, aim noise); deterministic for a given attempt number.
    pub fn vary(self: *Pilot, attempt: u32) void {
        self.seed = 0x5eed +% attempt *% 0x9e3779b9;
        if (self.seed == 0) self.seed = 1;
        self.attempt = attempt;
        const odd = attempt % 2 == 1;
        self.strafe_side = if (odd) -1 else 1;
        self.detour_side = if (odd) -1 else 1;
    }
    /// Forget routing state when the scripted goal or the world changes.
    pub fn reset(self: *Pilot) void {
        self.* = .{ .seed = self.seed, .level = self.level, .step_ms = self.step_ms, .attempt = self.attempt, .strafe_side = self.strafe_side, .detour_side = self.detour_side };
    }

    pub fn steer(self: *Pilot, frame: Frame, intent: Intent) !Steering {
        var outcome = try self.plan(frame, intent);
        if (outcome.report.enemy != 0) if (self.find(frame, outcome.report.enemy)) |seen| {
            if (seen.get(data.Health) catch null) |health| outcome.report.enemy_health = health.current;
        };
        return outcome;
    }
    fn find(_: *const Pilot, frame: Frame, id: u32) ?Ref {
        if (frame.region) return access.find(frame.world, id);
        return .{ .world = frame.world, .entity = frame.world.find(id) orelse return null };
    }
    fn plan(self: *Pilot, frame: Frame, requested: Intent) !Steering {
        var intent = requested;
        const world = frame.world;
        const entity = frame.entity;
        var report: Report = .{};
        const player = frame.state;
        const on_mover = player.ground_entity < frame.slots.occupants.len and if (frame.slots.occupants[player.ground_entity]) |ground| (world.get(ground, data.Mover) catch null) != null or @import("platforms.zig").pathPhase(world, ground) != null else false;
        const pose = (try world.get(entity, data.Transform)).*;
        const loadout = (try world.get(entity, data.Weapons)).*;
        var command: Command = .{ .angles = .{ pose.angles[0], pose.angles[1], 0 }, .weapon = @intCast(loadout.weapon) };
        const recovery_health = world.get(entity, data.Health) catch null;
        if (@import("../domain/checkpoint.zig").requiresRestart(player.mode, if (recovery_health) |value| value.current else 1)) {
            // A dead player requests the authored death checkpoint with attack.
            if (intent.attack_when_dead and @mod(@divTrunc(frame.now, 250), 2) == 0) command.attack = true;
            self.reset();
            return .{ .report = report, .command = command };
        }
        if (player.mode != .normal) {
            // Frozen by a cinematic: hold still and keep the view, like an idle player.
            // A client sets BUTTON_ANY for any key held; the ending waits on that.
            if (intent.press_to_continue and @mod(@divTrunc(frame.now, 250), 2) == 0) {
                command.attack = true;
                command.any = true;
            }
            self.step_ms = frame.now;
            return .{ .report = report, .command = command };
        }
        var policy = skill.profile(self.level);
        if (frame.field_of_view) |cone| policy.field_of_view = cone;
        const eye = v.add(pose.position, .{ 0, 0, player.view_height });
        const facing = v.basis(pose.angles).forward;
        // Being hit is a cue rather than sight: face the shooter's bearing,
        // more accurately the higher the skill.
        if (frame.capabilities.alert) if (world.get(entity, data.Hurt) catch null) |hurt| {
            if (self.receipt) |seen| if (hurt.revision != seen and hurt.source != 0) if (world.find(hurt.source)) |shooter| if (shooter.index != entity.index) {
                const point = (try world.get(shooter, data.Transform)).position;
                self.alert_yaw = skill.yaw(v.subtract(point, eye)) + skill.noise(&self.seed) * policy.alert_error;
                self.alert_until = frame.now + policy.alert_ms;
            };
            self.receipt = hurt.revision;
        };
        if (self.passage) |passage| if (player.teleport_bit != passage.teleport_bit or frame.now >= passage.until_ms) {
            self.passage = null;
            self.route = .{};
        };

        // Engagement: hostile actors inside the view cone (or close enough to
        // sense) with a clear shot line. A scripted kill target wins ties.
        var scan: Scan = .{ .frame = frame, .intent = intent, .policy = policy, .facing = facing, .eye = eye, .self_id = try world.persistentId(entity), .target = self.target, .nuisance = if (frame.capabilities.nuisance) self.nuisance else 0 };
        if (intent.fight and intent.face == null) switch (frame.targets) {
            .specified => |target| try scan.considerBody(target),
            .players => |match| for (match.entities) |maybe| {
                const candidate = maybe orelse continue;
                if (candidate.index == entity.index) continue;
                try scan.considerPlayer(.{ .world = world, .entity = candidate }, match.session);
            },
            .actors => if (frame.region) {
                var candidates = access.Damageables.init(world, frame.slots);
                while (candidates.next()) |candidate| {
                    if (candidate.world == world and candidate.entity.index == entity.index) continue;
                    try scan.consider(candidate);
                }
            } else {
                var query = world.queryAccess(data.World.mask(.{ data.Actor, data.Health, data.Transform, data.Binding, data.Body }), 0, 0);
                defer query.deinit();
                while (query.next()) |view| for (view.entities()) |candidate| try scan.consider(.{ .world = world, .entity = candidate });
            },
        };
        const enemy = scan.enemy;
        var enemy_point = scan.point;
        if (enemy) |seen| {
            const identity = try seen.id();
            if (identity != self.target) {
                self.target = identity;
                self.reaction_ready = frame.now + policy.reaction_ms;
                self.locked_ms = frame.now;
                self.spent_until = 0;
                self.hold_fire_until = 0;
            }
            self.seen_ms = frame.now;
            report.enemy = identity;
            report.enemy_distance = v.length(v.subtract(enemy_point, eye));
        } else if (frame.now - self.seen_ms > policy.memory_ms) self.target = 0;
        // Choose for what will be shot: the visible enemy, else a shoot target.
        // With nothing in view, keep ready a weapon for the close encounters
        // corridors bring (not a splash weapon such as C4, which would have to
        // be swapped out the moment something rounds a corner).
        const range: f32 = if (enemy != null) report.enemy_distance else if (intent.shoot_slot != null and intent.face != null) v.length(v.subtract(intent.face.?, eye)) else 150;
        // An ion bolt discharges where it meets water, hurting everything
        // within 64 units: not from the water, nor into water close by.
        const wet = try waterNear(frame, eye, pose.position, if (enemy != null) enemy_point else intent.face);
        // Weapons the body must not use here (a companion's splash weapons
        // with its leader beside the target).
        var preference = if (intent.weapon) |wanted| combat.preferred(loadout, frame.table, wanted) else null;
        var excluded: i32 = if (frame.exclusion) |rule| try rule.mask(rule.context, frame, if (enemy != null) enemy_point else null) else 0;
        const damage_excluded = if (enemy) |seen| damageExclusions(seen, frame.now) else 0;
        excluded |= damage_excluded;
        if (enemy != null and self.target == self.futile_target and frame.now < self.spent_until) excluded |= @as(i32, 1) << @intCast(self.spent_weapon);
        // Badly hurt, a blast weapon's own splash (a round meeting a door
        // that shuts in front of it, an enemy stepping into the lane) is
        // the last hit: another weapon that reaches comes first.
        const hurt = if (world.get(entity, data.Health)) |health| health.current * 2 < health.maximum else |_| false;
        // Nor at a target inside twice a round's blast radius: a dodge, a
        // near wall or the floor at its feet brings the splash back.
        // Nor with one of the party within the blast of where it lands.
        var close_blasts: i32 = 0;
        if (enemy != null) for (@import("weapon_catalog").entries) |entry| if (entry.spec.splash_hazard and (report.enemy_distance < @max(entry.spec.projectile.splash_radius * 2, 320) or try allyNear(frame, eye, enemy_point, entry.spec.projectile.splash_radius * 1.25))) {
            close_blasts |= @as(i32, 1) << entry.id;
        };
        // Weapons whose blasts linger come back on the party in the halls and
        // rooms fights happen in: fired only when a route names them.
        if (preference == null) excluded |= @import("weapon_classes/registry.zig").lingeringMask();
        if (close_blasts != 0) {
            var others = loadout;
            others.dk3Inventory &= ~close_blasts;
            if (combat.rangedFor(others, frame.table, .{ .advancing = true, .excluded = excluded })) excluded |= close_blasts;
        }
        // Deliberate object shots qualify their real muzzle lane and blast
        // clearance below. Injury alone must not reject a safe ranged shot
        // and replace it with a gun that demands entering a closed obstacle.
        if (frame.capabilities.duck_to_shoot and hurt and intent.shoot_slot == null) {
            var blasts: i32 = 0;
            for (@import("weapon_catalog").entries) |entry| if (entry.spec.splash_hazard) {
                blasts |= @as(i32, 1) << entry.id;
            };
            var others = loadout;
            others.dk3Inventory &= ~blasts;
            if (combat.rangedFor(others, frame.table, .{ .advancing = true, .excluded = excluded })) excluded |= blasts;
        }
        // Blowing up an object (a grate, a crate) with one of the party in
        // the way or beside it: not with a blast weapon while another reaches.
        if (enemy == null and intent.shoot_slot != null and intent.face != null and try allyNear(frame, eye, intent.face.?, 192)) {
            var blasts: i32 = 0;
            for (@import("weapon_catalog").entries) |entry| if (entry.spec.splash_hazard) {
                blasts |= @as(i32, 1) << entry.id;
            };
            var others = loadout;
            others.dk3Inventory &= ~blasts;
            if (combat.rangedFor(others, frame.table, .{ .advancing = true, .excluded = excluded })) excluded |= blasts;
        }
        if (preference) |wanted| {
            // Deliberately named lingering attacks have their own authored
            // retreat. Ordinary gun preferences still obey close-blast,
            // party and injury safety; none can override damage immunity.
            const authored = @import("weapon_classes/registry.zig").lingeringMask() & (@as(i32, 1) << wanted);
            preference = combat.permittedPreference(loadout, frame.table, wanted, (excluded & ~authored) | damage_excluded);
            if (preference == null) excluded |= @import("weapon_classes/registry.zig").lingeringMask();
        }
        var selected = if (preference) |wanted| wanted else combat.selectFor(loadout, frame.table, range, .{ .wet = wet, .advancing = true, .ranged_first = true, .excluded = excluded });
        const discharge = wet and combat.dischargesInWater(selected);
        // Ammunition reserve: with the last rounds left and no kill ordered,
        // fight only up close with a melee weapon; authored targets that only a
        // shot can trigger (turret controls) need what remains.
        var reserved = false;
        if (frame.capabilities.conserve_ammo and preference == null and intent.shoot_slot == null and enemy != null and weaponReach(frame, selected) >= 160 and lowAmmoReserve(loadout, frame.table, selected)) {
            // Another ranged weapon with rounds to spare comes first.
            var others = loadout;
            others.dk3Inventory &= ~(@as(i32, 1) << selected);
            const other = combat.selectFor(others, frame.table, range, .{ .wet = wet, .advancing = true, .ranged_first = true, .excluded = excluded });
            if (other != selected and others.dk3Inventory & (@as(i32, 1) << other) != 0 and weaponReach(frame, other) >= 160 and !lowAmmoReserve(others, frame.table, other)) selected = other;
        }
        // (Not while being worn down: rounds kept back then are never spent.)
        const pressed = if (world.get(entity, data.Health)) |health| health.current * 10 < health.maximum * 8 else |_| false;
        if (frame.capabilities.conserve_ammo and preference == null and intent.shoot_slot == null and enemy != null and !pressed) {
            const ranged = weaponReach(frame, selected) >= 160;
            if (ranged and lowAmmoReserve(loadout, frame.table, selected)) {
                // A kill order may still spend rounds at range; anything else waits.
                reserved = intent.preferred == 0;
                if (melee(loadout, frame, excluded)) |glove| if (report.enemy_distance < 220) {
                    selected = glove;
                    reserved = false;
                };
            }
        }
        // Nothing allowed to choose leaves the weapon in hand; if that one is
        // excluded too, it stays raised but silent.
        if (preference == null and excluded & (@as(i32, 1) << selected) != 0) reserved = true;
        command.weapon = selected;
        var aim_origin = eye;
        var body_aim = false;
        var fallback_melee = false;
        if (@import("weapon_catalog").find(selected)) |entry| {
            if (entry.spec.bot_aim_from_body) {
                aim_origin = pose.position;
                body_aim = true;
            } else if (entry.spec.bot_contact_melee_range != null and (loadout.ammo[selected] < frame.table.entries[selected].ammoCost or (enemy != null and report.enemy_distance <= entry.spec.bot_contact_melee_range.?))) {
                const strike_plan = try @import("weapon_catalog").meleePlan(selected, 128, loadout.dk3SwordExperience);
                aim_origin = v.add(pose.position, if (strike_plan.world_muzzle) frame.table.entries[selected].muzzle else @as(v.Vec3, @splat(0)));
                aim_origin[2] += if (player.ducked) strike_plan.crouching_height else strike_plan.height;
                body_aim = true;
                fallback_melee = true;
            }
        }
        // Close attacks reach a body at its near surface. Measuring a wide
        // actor's centre can demand walking inside its collision hull.
        if (weaponReach(frame, selected) <= 128) if (enemy) |seen| if (seen.get(data.Body) catch null) |body| {
            const origin = (try seen.get(data.Transform)).position;
            enemy_point = v.closestInBounds(aim_origin, v.add(origin, v.add(body.mins, @splat(1))), v.add(origin, v.subtract(body.maxs, @splat(1))));
            report.enemy_distance = v.length(v.subtract(enemy_point, aim_origin));
        };

        // Locomotion toward the scripted destination, with the same authored
        // control, passage and lift handling as multiplayer bots.
        var destination = intent.destination;
        if (!intent.direct and !intent.jump and !intent.crouch) if (destination) |goal| {
            destination = try evasion.safeArrival(frame, pose.position, goal);
        };
        var control_aim: ?v.Vec3 = null;
        if (self.control) |previous| {
            self.control_until = @max(self.control_until, self.route.progress_ms + 15000);
            if (routes.completed(world, previous) or frame.now >= self.control_until) {
                if (!routes.completed(world, previous)) {
                    self.avoided = previous.id;
                    self.avoid_until = frame.now + 10000;
                }
                self.control = null;
                self.route = .{};
            } else {
                var control = previous;
                control_aim = try routes.aim(world, control);
                if (control_aim == null) if (try routes.advance(world, frame.slots, frame.projections, entity, control, frame.service, frame.now)) |next| {
                    control = next;
                    self.control = next;
                    self.route = .{};
                    control_aim = try routes.aim(world, next);
                };
                destination = if (control_aim == null) pose.position else control.point;
                if (control.action == .touch and nav.horizontalDistance(pose.position, control.point) < 24 and control_aim != null) destination = control_aim;
                report.control = control.id;
                report.control_point = control.point;
            }
        }
        // A moving solid is a physical threat even when nobody is attacking.
        // Preserve the escape briefly so following a nearby ally cannot pull
        // the body straight back into the closing sweep on its next command.
        if (world.get(entity, data.Hurt) catch null) |crush_hit| if (crush_hit.revision != self.crush_revision and crush_hit.source != 0 and frame.now >= crush_hit.at_ms and frame.now - crush_hit.at_ms < 500) {
            self.crush_revision = crush_hit.revision;
            if (try routes.crushEscape(world, entity, crush_hit.source, frame.collision)) |point| {
                self.yield_point = point;
                self.yield_until = frame.now + 1200;
                self.crush_until = self.yield_until;
                self.control = null;
                control_aim = null;
                self.route = .{};
                if (engine.integer("developer") > 0) {
                    var message: [192]u8 = undefined;
                    engine.print(std.fmt.bufPrintZ(&message, "dk3 {s}: t={d} event=crush_escape source={d} point={d:.0},{d:.0},{d:.0}\n", .{ frame.label, frame.now, crush_hit.source, point[0], point[1], point[2] }) catch "");
                }
            }
        };
        // Stepping aside for an ally, or waiting at a gate an ally opens.
        if (frame.now < self.yield_until) {
            destination = self.yield_point;
        } else self.yield_point = null;
        if (frame.now < self.gate_until and self.control == null) {
            if (destination != null) destination = self.gate_point;
        } else self.gate_point = null;
        if (!intent.leave_mover and self.control == null and self.passage == null) if (destination) |goal| {
            if (try routes.ridePoint(world, frame.slots, entity, player.ground_entity, goal)) |point| destination = point;
        };
        const escaping_crush = frame.now < self.crush_until and self.yield_point != null;
        if (escaping_crush) {
            destination = self.yield_point;
            intent.direct = true;
            intent.leash = null;
            intent.arena = null;
            self.direct_fallback_until = 0;
            self.direct_ms = frame.now;
        }
        var movement: v.Vec3 = @splat(0);
        var crouch = false;
        var ladder = false;
        var climb_normal: ?v.Vec3 = null;
        // Steering straight at a near goal because navigation has no way there.
        var routeless = false;
        // Nothing under the feet: the graph's steps are places to stand, so a
        // body in mid-air has none of them ahead of it. Steering at one bends
        // the flight — the hop asked for straight across e1m7a's gap curved a
        // hundred units off its line and came down in the hall below. While the
        // air holds, the step's own goal is the only thing worth facing.
        const in_the_air = player.ground_entity == c.ENTITYNUM_NONE and player.water_level < 2;
        // A stride's stall is measured from the stride, not from the last time
        // the body was told to walk somewhere: a goal more than a step from the
        // one just held begins the measure anew, and the graph fallback armed
        // against the line just left is cleared with it. Standing a while at
        // the last goal is no evidence that the next line is blocked. (e1m7a's
        // ledge: a body that killed standing still at its east end had the
        // stride west off the plank judged stalled before its first frame, and
        // the graph — which marks none of that plank's ground — led it back
        // east across the gap it had just jumped, off the end and into the hall
        // below.) Measured only while a line is being held: the same clocks
        // also carry the general reading that the body is not moving, which
        // answers with a hop or an unstick whatever the stride was asked for,
        // and restarting that at every idle gap hides a stall from those
        // answers — set loose over the party's walking, it had a companion
        // reach a pickup seconds early, which pulled the leader east off its
        // route onto a floor the graph has no way off (n48a, reverted).
        if (intent.destination) |stride| {
            const retargeted = if (self.stride_goal) |held| nav.horizontalDistance(stride, held) > 32 else true;
            if (retargeted) {
                self.direct_ms = frame.now;
                self.direct_mark = pose.position;
                self.direct_fallback_until = 0;
                self.direct_retry_ms = 0;
            }
            self.stride_goal = stride;
        } else self.stride_goal = null;
        if (destination) |goal| {
            // Holding a spot (riding at a lift's centre) is not a stall.
            if (intent.direct and !on_mover and !in_the_air and frame.now - self.direct_ms > 1500 and frame.now >= self.direct_retry_ms and nav.horizontalDistance(pose.position, goal) > 32) {
                // Straight steering stalled even after a hop: the player was
                // displaced off the authored line. Route back over navigation.
                self.direct_fallback_until = frame.now + 2500;
                self.direct_retry_ms = frame.now + 4000;
                self.direct_mark = pose.position;
                self.direct_ms = frame.now;
            }
            if (intent.direct and (in_the_air or frame.now >= self.direct_fallback_until)) {
                movement = v.subtract(goal, pose.position);
            } else if (self.passage) |passage| {
                movement = v.subtract(passage.route.point, pose.position);
                report.passage = passage.route.id;
            } else if (try self.follow(frame, pose.position, goal, intent.direct_radius)) |waypoint| {
                report.waypoint = waypoint;
                if (frame.now >= self.gate_until) self.gate_since = 0;
                // A route step the body has already touched is behind it. While
                // the graph keeps offering that same step, steering at it again
                // walks a limit cycle: six steps back to the step, six toward
                // the goal, forever (the pit of e1m2b held a bot there for a
                // whole action). Plain steps only: a jump take-off, a crouch
                // under a beam or a ladder is a step the body must stand on.
                if (v.length(v.subtract(waypoint.point, self.waypoint_point)) > 8) {
                    self.waypoint_point = waypoint.point;
                    self.waypoint_reached_ms = 0;
                } else if (nav.horizontalDistance(waypoint.point, pose.position) <= 8) {
                    self.waypoint_reached_ms = frame.now + 3000;
                }
                const dropped = frame.now < self.waypoint_reached_ms and !waypoint.jump and !waypoint.crouch and !waypoint.ladder;
                movement = if (dropped) v.subtract(goal, pose.position) else v.subtract(waypoint.point, pose.position);
                // The route takes a lift: board it, call it or send it, and ride.
                // Also on the way to a control (a button the lift carries the
                // player up to): the lift's own control comes first, and the
                // planner names the other again once the route is clear.
                // Aboard a lift whose route goes on far above or below within
                // its shaft (the area graph has the shaft empty): send it.
                var lift_entrance: ?v.Vec3 = if (waypoint.elevator) waypoint.entrance else null;
                if (lift_entrance == null and @abs(waypoint.point[2] - pose.position[2]) > 64 and player.ground_entity < frame.slots.occupants.len) if (frame.slots.occupants[player.ground_entity]) |ground| {
                    const lift = @import("platforms.zig").pathPhase(world, ground) != null or (world.get(ground, data.Mover) catch null) != null;
                    const box = frame.projections[player.ground_entity].shared;
                    if (lift and waypoint.point[0] > box.absmin[0] - 32 and waypoint.point[0] < box.absmax[0] + 32 and waypoint.point[1] > box.absmin[1] - 32 and waypoint.point[1] < box.absmax[1] + 32) lift_entrance = pose.position;
                };
                if (engine.integer("developer") >= 2) if (lift_entrance) |entrance| {
                    var text: [192]u8 = undefined;
                    engine.print(std.fmt.bufPrintZ(&text, "dk3 {s}: t={d} event=lift entrance={d:.0},{d:.0},{d:.0} elevator={d} ground={d}\n", .{ frame.label, frame.now, entrance[0], entrance[1], entrance[2], @intFromBool(waypoint.elevator), player.ground_entity }) catch "");
                };
                if (lift_entrance) |entrance| if (try routes.liftStep(world, frame.slots, frame.projections, entity, .{ .ground = player.ground_entity, .view_height = player.view_height, .collision = frame.collision, .operate = frame.capabilities.operate_lifts }, entrance, frame.service, frame.now)) |step| switch (step) {
                    .board => |point| movement = v.subtract(point, pose.position),
                    .hold => |point| movement = if (nav.horizontalDistance(point, pose.position) > 8) v.subtract(point, pose.position) else @splat(0),
                    .operate => |found| if (self.control == null or self.control.?.id != found.id) {
                        self.control = found;
                        self.control_until = frame.now + 15000;
                        self.route = .{};
                        movement = @splat(0);
                    },
                    .wait => movement = @splat(0),
                    .away => {
                        movement = @splat(0);
                        const round = try frame.service.next(.{ .position = pose.position, .destination = goal, .slot = frame.slot, .player = true, .allow_slime_escape = true, .lifts = false });
                        if (engine.integer("developer") >= 2) {
                            var text: [160]u8 = undefined;
                            const point: v.Vec3 = if (round) |w| w.point else @splat(0);
                            engine.print(std.fmt.bufPrintZ(&text, "dk3 {s}: t={d} event=lift-away round={d:.0},{d:.0},{d:.0}\n", .{ frame.label, frame.now, point[0], point[1], point[2] }) catch "");
                        }
                        if (round != null) {
                            self.lifts_off_until = frame.now + 10000;
                            self.route = .{};
                            self.committed = null;
                        }
                    },
                };
                // Kept two seconds in arrears, so stepping back to it is a
                // stride rather than a step on one's own toes.
                if (frame.now >= self.routable_ms + 2000 and nav.horizontalDistance(pose.position, self.routable_point) > 8) {
                    self.routable_point = pose.position;
                    self.routable_ms = frame.now;
                }
                ladder = waypoint.ladder;
                const hull = (try world.get(entity, data.Body)).*;
                crouch = waypoint.crouch or try steering.crouch(frame.collision, pose.position, waypoint.point, hull.mins, .{ hull.maxs[0], hull.maxs[1], frame.hull.maxs[2] }, frame.slot, hull.collision_mask & ~@as(u32, c.CONTENTS_BODY));
                // A jump link is jumped from its takeoff (a hop on the way
                // there lands short of it; the stride after walks off the
                // edge instead: e1m6b's leap from the walkway to the platform
                // in the nitrogen).
                const at_takeoff = v.length(waypoint.entrance) == 0 or nav.horizontalDistance(pose.position, waypoint.entrance) < 32;
                if (waypoint.jump and at_takeoff and player.ground_entity != c.ENTITYNUM_NONE and frame.now >= self.jump_ready) {
                    self.jump_until = frame.now + 200;
                    self.jump_ready = frame.now + 800;
                }
            } else if (nav.horizontalDistance(pose.position, goal) < intent.direct_radius) {
                movement = v.subtract(goal, pose.position);
                routeless = !intent.direct;
            } else report.no_route = true;
            // Straight steering (an authored line, a near goal the area graph
            // has no way to) ducks under a low ceiling as a routed stride does.
            if (!crouch and v.length(.{ movement[0], movement[1], 0 }) > 1) {
                const hull = (try world.get(entity, data.Body)).*;
                crouch = try steering.crouch(frame.collision, pose.position, v.add(pose.position, movement), hull.mins, .{ hull.maxs[0], hull.maxs[1], frame.hull.maxs[2] }, frame.slot, hull.collision_mask & ~@as(u32, c.CONTENTS_BODY));
            }
            // No route while a closed navigation gate (a door, toggled wall,
            // damaging volume, retracted floor or breakable) holds the way:
            // detour to whatever authored control opens it.
            if ((report.no_route or routeless) and frame.capabilities.controls and self.control == null and self.passage == null and frame.now >= self.unblock_ms) if (frame.gates) |state| {
                self.unblock_ms = frame.now + 1000;
                var waiting = false;
                var fetching = false;
                if (try routes.unblockWaiting(world, frame.slots, frame.projections, state, entity, goal, frame.service, frame.now, if (frame.now < self.avoid_until) self.avoided else 0, &waiting)) |found| {
                    // An ally already fetching this control keeps it; this
                    // body stays available to cross the gate meanwhile.
                    if (!claimed(frame, found.route_obstacle)) {
                        self.control = found;
                        self.control_until = frame.now + 15000;
                        self.route = .{};
                        fetching = true;
                    }
                }
                if (frame.coordination == null) {
                    // A door in the way is opening: hold here until it is open.
                    if (!fetching and waiting) self.hold_until = frame.now + 1000;
                } else if (fetching) self.gate_since = 0 else {
                    if (self.gate_since == 0) self.gate_since = frame.now;
                    if (frame.now - self.gate_since > 20000) {
                        // Nobody opened it: other goals meanwhile, then again.
                        report.give_up_ms = 10000;
                        self.gate_since = 0;
                    } else if (try routes.gateFront(world, state, entity, goal)) |point| {
                        self.gate_point = point;
                        self.gate_until = frame.now + 1000;
                    } else if (!waiting) report.give_up_ms = 3000;
                }
            };
            if ((report.no_route or routeless) and frame.now < self.hold_until) {
                report.holding = true;
                movement = @splat(0);
            }
            report.blocked = self.route.blocked;
            report.routeless = routeless;
            // No route, nothing to operate, no ground under the route: walk
            // back to where the graph last knew where it was. Pressing on from
            // a spot no area contains produces no input at all — the body just
            // stands in the doorway that shoved it there (e1m5b's freezer,
            // whose closing leaf left it wedged for the rest of the run).
            if (report.no_route and !report.holding and self.control == null and self.passage == null and
                player.water_level < 2 and frame.now - self.direct_ms >= 1500 and frame.now >= self.retreat_until)
            {
                const back = nav.horizontalDistance(pose.position, self.routable_point);
                if (self.routable_ms != 0 and frame.now - self.routable_ms <= 20000 and back > 40 and back < 400) {
                    self.retreat_until = frame.now + 2000;
                    movement = v.subtract(self.routable_point, pose.position);
                    if (engine.integer("developer") >= 2) {
                        var text: [192]u8 = undefined;
                        engine.print(std.fmt.bufPrintZ(&text, "dk3 {s}: t={d} event=retreat pos={d:.0},{d:.0},{d:.0} to={d:.0},{d:.0},{d:.0}\n", .{ frame.label, frame.now, pose.position[0], pose.position[1], pose.position[2], self.routable_point[0], self.routable_point[1], self.routable_point[2] }) catch "");
                    }
                }
            }
            // A stride that stalls with input held means a lip or step the
            // route did not mark: hop it, the way a player would.
            // Horizontal only: bobbing at a surface or hopping in place is no progress.
            if (nav.horizontalDistance(pose.position, self.direct_mark) > 8) {
                self.direct_mark = pose.position;
                self.direct_ms = frame.now;
            }
            // Sliding along an obstruction moves the player without bringing
            // the step target any closer: that is a stall too.
            const aim_point = v.add(pose.position, movement);
            const aim_distance = nav.horizontalDistance(pose.position, aim_point);
            if (nav.horizontalDistance(aim_point, self.approach_point) > 16 or aim_distance < self.approach_best - 8) {
                self.approach_point = aim_point;
                self.approach_best = aim_distance;
                self.approach_ms = frame.now;
            }
            const sliding = aim_distance > 24 and frame.now - self.approach_ms > 1500;
            // Standing on a mover (riding a lift to its centre) is carried,
            // not stuck: a hop there only lands beside it.
            if ((frame.now - self.direct_ms > 700 or sliding) and !(on_mover and intent.direct) and player.ground_entity != c.ENTITYNUM_NONE and player.water_level < 2 and frame.now >= self.jump_ready and v.length(.{ movement[0], movement[1], 0 }) > 4) {
                // The hop is for the lip in the way, not for the edge behind
                // it: a stalled stride by a long drop or a lethal gas keeps
                // its feet on the floor and looks for another way instead.
                report.blocked = true;
                const heading = v.normalize(.{ movement[0], movement[1], 0 });
                // A route that means to come down (a step or a goal well below
                // the feet) may take its own drop; a stalled stride by an edge
                // it never asked for may not. The fall the route accepts is how
                // far down the hop looks for ground.
                const hop_drop: f32 = if (movement[2] < -56 or if (self.route.waypoint) |waypoint| waypoint.drop else false) -movement[2] else 0;
                if (try evasion.hopSafe(frame, pose.position, heading, hop_drop)) {
                    self.jump_until = frame.now + 200;
                    self.jump_ready = frame.now + 900;
                } else {
                    self.jump_ready = frame.now + 400;
                    if (engine.integer("developer") >= 2 and frame.now >= self.hop_told_ms) {
                        self.hop_told_ms = frame.now + 1000;
                        var text: [192]u8 = undefined;
                        engine.print(std.fmt.bufPrintZ(&text, "dk3 {s}: t={d} event=hop-refused pos={d:.0},{d:.0},{d:.0} toward={d:.0},{d:.0},{d:.0}\n", .{ frame.label, frame.now, pose.position[0], pose.position[1], pose.position[2], pose.position[0] + heading[0] * 40, pose.position[1] + heading[1] * 40, pose.position[2] }) catch "");
                    }
                }
            }
            const changing_floor = self.control == null and player.ground_entity != c.ENTITYNUM_NONE and @abs(movement[2]) > 18;
            // Circling the same route point without the route moving on
            // (the next step lies through a door the hull is pressed to).
            // (Not while steering straight or standing on a mover: a rider
            // holds its spot on purpose.)
            var hovering = false;
            if (!intent.direct and !on_mover) if (report.waypoint) |waypoint| {
                if (v.length(v.subtract(waypoint.point, self.hover_point)) > 16 or nav.horizontalDistance(waypoint.point, pose.position) > 24) {
                    self.hover_point = waypoint.point;
                    self.hover_ms = frame.now;
                } else hovering = frame.now - self.hover_ms > 2500;
            };
            const stalled = frame.now - self.direct_ms > 1500 or sliding or hovering;
            if (self.passage == null and (self.route.blocked or stalled or changing_floor) and frame.now >= self.seek_ms) {
                self.seek_ms = frame.now + 500;
                // A waypoint at the player's feet gives no heading: use the goal.
                // (A door the hull already touches leaves the waypoint just
                // beyond it, a few units away: that still gives the heading.)
                const toward = if (self.route.waypoint) |waypoint| (if (nav.horizontalDistance(waypoint.point, pose.position) > 6 and frame.now >= self.waypoint_reached_ms) waypoint.point else goal) else goal;
                if (engine.integer("developer") >= 2) {
                    var text: [192]u8 = undefined;
                    engine.print(std.fmt.bufPrintZ(&text, "dk3 {s}: t={d} event=seek pos={d:.0},{d:.0},{d:.0} toward={d:.0},{d:.0},{d:.0} blocked={d} stalled={d}\n", .{ frame.label, frame.now, pose.position[0], pose.position[1], pose.position[2], toward[0], toward[1], toward[2], @intFromBool(self.route.blocked), @intFromBool(stalled) }) catch "");
                    if (frame.capabilities.controls) try routes.diagnose(world, frame.slots, frame.projections, entity, toward, frame.service, frame.now);
                }
                const passage = if (self.control == null and frame.capabilities.passages) try routes.teleportPassage(world, frame.projections, entity, toward, goal, frame.service, frame.now) else null;
                if (passage) |found| {
                    self.passage = .{ .route = found, .teleport_bit = player.teleport_bit, .until_ms = frame.now + 5000 };
                    self.route = .{};
                    movement = v.subtract(found.point, pose.position);
                } else if (if (frame.capabilities.yield_to_allies) try routes.yieldPoint(world, frame.slots, entity, toward) else null) |point| {
                    self.yield_point = point;
                    self.yield_until = frame.now + 1000;
                    self.route = .{};
                } else if (if (frame.capabilities.controls) try routes.seek(world, frame.slots, frame.projections, entity, toward, frame.service, frame.now, if (frame.now < self.avoid_until) self.avoided else 0) else null) |found| {
                    if (self.control == null and claimed(frame, found.route_obstacle)) {
                        // An ally fetches the remote control while this body
                        // stays to cross the door.
                        movement = @splat(0);
                    } else if (self.control == null or found.id != self.control.?.id) {
                        var next = found;
                        if (self.control) |parent| next.route_obstacle = parent.route_obstacle;
                        self.control = next;
                        self.control_until = frame.now + 15000;
                        self.route = .{};
                    }
                } else if (!(on_mover and intent.direct) and (self.route.blocked or stalled or report.no_route) and frame.now - @min(self.route.progress_ms, self.direct_ms) >= 1500 and frame.now >= self.unstick_until and (player.water_level < 2 or frame.now >= self.unstick_ready_ms)) {
                    // Nothing authored explains the obstruction: sidestep and hop
                    // briefly, the way a player shakes loose from a ledge or prop.
                    // A swimmer has nothing to hop off and no floor to lean on,
                    // and shakes loose with two shorter strokes instead. Either
                    // window stays well inside the wait for the next one: given
                    // its full length, the body spends its whole air budget
                    // swimming away from where it was going.
                    self.unstick_until = frame.now + (if (player.water_level >= 2) @as(i64, 450) else 600);
                    self.unstick_ready_ms = self.unstick_until + (if (player.water_level >= 2) @as(i64, 1050) else 0);
                    self.unstick_side = -self.unstick_side;
                    if (player.ground_entity != c.ENTITYNUM_NONE and frame.now >= self.jump_ready) {
                        self.jump_until = frame.now + 200;
                        self.jump_ready = frame.now + 800;
                    }
                }
            }
        }

        // Standing on an actor (a worker who stopped on the goal, a corpse
        // mid-fall) or a player (a companion settled on the leader's head,
        // pinning him under a ramp's ceiling) is no footing: step off it,
        // away from its centre.
        var dismount: ?v.Vec3 = null;
        var dismount_crouch = false;
        if (self.body_step) |landing| {
            if (frame.now < self.body_step_until and nav.horizontalDistance(pose.position, landing) > 12) {
                const stride = v.subtract(landing, pose.position);
                dismount = .{ stride[0], stride[1], 0 };
                dismount_crouch = self.body_step_crouch;
            } else self.body_step = null;
        }
        if (dismount == null and player.ground_entity < frame.slots.occupants.len) if (frame.slots.occupants[player.ground_entity]) |under| {
            if ((world.get(under, data.Actor) catch null) != null or (world.get(under, data.Player) catch null) != null) {
                var away = v.subtract(pose.position, (try world.get(under, data.Transform)).position);
                away[2] = 0;
                if (v.length(away) < 4) away = .{ @cos(self.detour_side), @sin(self.detour_side), 0 };
                // A route's heading is preferable to a sideways fall off a
                // narrow walkway. Every alternative must have safe footing.
                const preferred = if (destination) |goal| v.subtract(goal, pose.position) else away;
                const heading = std.math.atan2(preferred[1], preferred[0]);
                movement = @splat(0);
                const lifted = v.add(pose.position, .{ 0, 0, 2 });
                const support = frame.projections[player.ground_entity].shared;
                dismount_search: for ([_]f32{ 64, 96, 128, 160 }) |distance| for ([_]f32{ 0, 0.7853982, -0.7853982, 1.5707964, -1.5707964, 3.1415927 }) |offset| {
                    const stride: v.Vec3 = .{ @cos(heading + offset) * distance, @sin(heading + offset) * distance, 0 };
                    const landing = v.add(lifted, stride);
                    const outside = landing[0] + frame.hull.mins[0] > support.absmax[0] or landing[0] + frame.hull.maxs[0] < support.absmin[0] or landing[1] + frame.hull.mins[1] > support.absmax[1] or landing[1] + frame.hull.maxs[1] < support.absmin[1];
                    if (!outside) continue;
                    if (engine.integer("developer") >= 2 and @mod(frame.now, 500) == 0 and offset == 0) {
                        const lane = try frame.collision.trace(.{ .start = lifted, .end = landing, .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
                        const floor = try frame.collision.trace(.{ .start = landing, .end = v.add(landing, .{ 0, 0, -82 }), .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
                        var detail: [384]u8 = undefined;
                        engine.print(std.fmt.bufPrintZ(&detail, "dk3 {s}: t={d} event=body_step from={d:.1},{d:.1},{d:.1} to={d:.1},{d:.1} lane={d:.2} solid={d} floor={d:.1} normal={d:.1} support_top={d:.1}\n", .{ frame.label, frame.now, lifted[0], lifted[1], lifted[2], landing[0], landing[1], lane.fraction, @intFromBool(lane.start_solid), floor.end[2], floor.normal[2], support.absmax[2] }) catch "");
                    }
                    const standing = try evasion.supportedDrop(frame, lifted, landing, frame.hull.maxs[2], 82);
                    const ducking = !standing and try evasion.supportedDrop(frame, lifted, landing, 4, 82);
                    if (standing or ducking) {
                        movement = stride;
                        dismount = stride;
                        dismount_crouch = ducking;
                        self.body_step = landing;
                        self.body_step_until = frame.now + 1200;
                        self.body_step_crouch = ducking;
                        if (!ducking) {
                            const above = try frame.collision.trace(.{ .start = lifted, .end = v.add(lifted, .{ 0, 0, 48 }), .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
                            if (!above.start_solid and above.fraction == 1) self.body_step_jump_until = frame.now + 150;
                        }
                        break :dismount_search;
                    }
                };
            }
        };

        // Riding a lift while it moves (a vertical mover underfoot): keep to
        // its middle until it stops. A stride for the landing mid-ride walks
        // to its edge and into the landing's lip (e1m6b's plat up to the
        // walkway to the exit crushes a rider caught there).
        if (!intent.leave_mover and player.ground_entity < frame.slots.occupants.len) if (frame.slots.occupants[player.ground_entity]) |under| {
            if (world.get(under, data.Mover) catch null) |mover| if (mover.moving() and !mover.angular and @abs(mover.opened[2] - mover.closed[2]) > @max(@abs(mover.opened[0] - mover.closed[0]), @abs(mover.opened[1] - mover.closed[1]))) {
                const box = frame.projections[player.ground_entity].shared;
                movement = .{ (box.absmin[0] + box.absmax[0]) / 2 - pose.position[0], (box.absmin[1] + box.absmax[1]) / 2 - pose.position[1], 0 };
                if (v.length(movement) < 6) movement = @splat(0);
            };
        };

        // A climbable face the body already touches, whether the area graph
        // named the step or the route steers at it itself (rungs that slide
        // out of a wall are not in the graph): keep the rise and take the
        // stride into the face out. Rungs stand out of the wall as solid
        // brushes as deep as the ladder's whole place (e1m7a's hall ladder:
        // rungs 8 deep every 28 units, so the gaps between them are 20 tall
        // against a body 56 tall) and a body pressed into them is buried
        // between two rungs, coming no higher than the second. The way up a
        // ladder is against its face, in front of the rungs, which is exactly
        // where the area graph puts a ladder step's spot; walking into the
        // wall already brings the body there, so nothing presses it further.
        if (@abs(movement[2]) > 8 and player.water_level < 2) if (try climbable(frame, pose.position)) |normal| {
            movement = steering.climbHeading(movement, normal);
            ladder = true;
            climb_normal = normal;
        };
        // Approach a nearby ladder face before asking the physical motor to
        // attach. Ordinary obstacle sidesteps otherwise keep the body outside
        // its three-unit contact probe indefinitely.
        const climbing_approach = !ladder and movement[2] > 8 and player.water_level < 2 and blk: {
            const normal = try climbableWithin(frame, pose.position, 32) orelse break :blk false;
            break :blk v.dot(v.normalize(.{ movement[0], movement[1], 0 }), normal) < -0.25;
        };
        if (climbing_approach) {
            self.unstick_until = 0;
            self.jump_until = 0;
        }

        // Navigation areas do not model actors or static props; steer around a
        // body in the way like a player would. Closed doors stay obstacles so
        // the authored-control search above can open them.
        // Straight-steered segments are precise (pipes, ledges): no deviations.
        const precise_path = intent.direct;
        // A body standing on a precise segment (a worker on a walkway) is
        // stepped around too; geometry there stays the route's decision.
        if ((!precise_path or try detourAhead(frame, pose.position, movement)) and !ladder and !climbing_approach and player.water_level < 2 and v.length(.{ movement[0], movement[1], 0 }) > 0.01) {
            if (try self.sidestep(frame, pose.position, movement, &report, &crouch)) |turned| {
                movement = turned;
                report.sidestepped = true;
            }
        }

        // A contact swing changes this shot's aim, not the loaded weapon's
        // tactical reach. It must still back away from a surrounding crowd
        // and resume ranged fire. Only an actually empty weapon uses its
        // class-declared melee reach for movement.
        const movement_reach = weaponReach(frame, selected);
        if (!precise_path and !ladder and enemy != null and intent.close_in and intent.leash == null and movement_reach < 160 and report.enemy_distance > movement_reach * 0.8 and report.enemy_distance < 320 and self.control == null) {
            const charge = v.subtract(enemy_point, pose.position);
            const stride = v.scale(v.normalize(.{ charge[0], charge[1], 0 }), 64);
            if (player.water_level < 2 and try evasion.supported(frame, pose.position, v.add(pose.position, stride))) movement = charge;
        }

        // Survival movement: step away from incoming shots and forecast spray
        // impacts; when holding a fight, keep moving on a short tether. Not
        // from a ladder or in mid-air, where the step only steers the player
        // off the rungs or past a narrow landing into whatever lies below.
        const airborne = player.ground_entity == c.ENTITYNUM_NONE and player.water_level < 2;
        var threats = if (ladder or airborne or !policy.evasion) evasion.Threats{} else try evasion.gather(frame, pose.position);
        // A precise corridor can wait or step clear of an active damage field;
        // incoming rounds do not authorize deviating from its narrow footing.
        if (precise_path) threats.keepFields();
        if (frame.now < self.route.physical_until_ms and try evasion.corridorClearsFields(frame, pose.position, self.route.physical_point, &threats)) threats.removeFields();
        if (threats.len > 0) {
            self.dodge_until = frame.now + 1500;
            const velocity = (try world.get(entity, data.Velocity)).linear;
            const chosen = try evasion.escape(frame, pose.position, velocity, threats.slice(), intent.leash, intent.arena, self.attempt, blocked);
            if (chosen) |step| {
                movement = step;
                report.dodging = true;
            } else if (evasion.fieldBlocksAtSpeed(pose.position, movement, threats.slice(), if (frame.motor) |parameters| parameters.speed else run_speed)) {
                movement = @splat(0);
                report.dodging = true;
            }
            if (engine.integer("developer") > 0 and frame.now >= self.dodge_log_ms) {
                self.dodge_log_ms = frame.now + 250;
                var text: [512]u8 = undefined;
                var cursor = (try std.fmt.bufPrint(&text, "dk3 {s}: t={d} event=threats pos={d:.0},{d:.0} step={d:.0},{d:.0}", .{ frame.label, frame.now, pose.position[0], pose.position[1], if (chosen) |step| step[0] else 0, if (chosen) |step| step[1] else 0 })).len;
                for (threats.slice()) |threat| cursor += (std.fmt.bufPrint(text[cursor .. text.len - 2], " {d:.0},{d:.0}@{d:.2}", .{ threat.point[0], threat.point[1], threat.eta }) catch break).len;
                text[cursor] = '\n';
                text[cursor + 1] = 0;
                engine.print(text[0 .. cursor + 1 :0]);
            }
        }
        // Nearby fields can be harmless at this height or on this side of a
        // wall. Merely listing one must not suppress ordinary combat retreat.
        if (!report.dodging) if (intent.leash) |anchor| if (policy.evasion and movement_reach >= 160 and enemy != null and intent.destination == null and self.control == null) {
            if (frame.now >= self.strafe_until) {
                self.strafe_until = frame.now + 1200;
                self.strafe_side = -self.strafe_side;
            }
            if (try evasion.strafe(frame, pose.position, enemy_point, anchor, self.strafe_side, frame.now >= self.dodge_until, intent.arena, blocked)) |step| movement = step;
        };

        // Track a civilian standing in the way (not a companion).
        var in_the_way: u32 = 0;
        if (report.obstacle_id != 0) if (self.find(frame, report.obstacle_id)) |blocker| {
            if (blocker.get(data.Actor) catch null) |actor| if (catalog.traitsOf(catalog.entries[actor.definition].kind).bystander) {
                in_the_way = report.obstacle_id;
            };
        };
        // (A hop to shake loose leaves it a moment: touch lost that briefly
        // still counts as the same standoff.)
        if (in_the_way != 0) {
            if (in_the_way != self.blocker) {
                self.blocker = in_the_way;
                self.blocker_ms = frame.now;
            } else if (frame.now - self.blocker_ms > 3000) self.nuisance = in_the_way;
            self.blocker_seen_ms = frame.now;
        } else if (frame.now - self.blocker_seen_ms > 1500) self.blocker = 0;
        // Standing in the way is what earns the notice, so it is what keeps it:
        // once the body is clear of him the leave-passing permission lapses, or a
        // civilian who stood in a doorway once is hunted for the rest of the level.
        if (self.nuisance != 0 and frame.now - self.blocker_seen_ms > nuisance_forget_ms) self.nuisance = 0;

        // The physical escape has priority over combat and route recovery.
        if (escaping_crush) {
            movement = v.subtract(self.yield_point.?, pose.position);
            self.unstick_until = 0;
            self.jump_until = 0;
        }

        // View: use/shoot/look targets first, then a visible enemy, else travel.
        var aim = movement;
        var precise = false;
        var fighting = false;
        if (intent.face) |point| {
            aim = v.subtract(point, eye);
            precise = true;
        } else if (control_aim) |point| {
            const delta = v.subtract(point, eye);
            if (self.control.?.action == .shoot or v.length(delta) < 144) {
                aim = delta;
                precise = self.control.?.action != .touch;
            }
        }
        if (!precise) if (enemy) |seen| {
            // Lead a moving target by the selected weapon's projectile flight.
            var lead = enemy_point;
            const speed = frame.table.entries[selected].speed;
            if (speed > 0) if (seen.get(data.Velocity) catch null) |velocity| {
                lead = v.add(enemy_point, v.scale(velocity.linear, policy.lead * @min(@as(f32, 1), report.enemy_distance / speed)));
            };
            aim = v.subtract(lead, aim_origin);
            fighting = true;
        };
        var sweep_offset: f32 = 0;
        var alert_view: ?f32 = null;
        if (!fighting and !precise and intent.view == null) {
            if (frame.capabilities.alert and frame.now < self.alert_until and self.alert_yaw != null) {
                alert_view = self.alert_yaw;
            } else if (intent.look_at) |point| {
                aim = v.subtract(point, eye);
            } else if (frame.capabilities.sweep) {
                // Nothing to look at directly: look around while walking, so an
                // enemy becomes visible instead of staying behind.
                if (frame.now >= self.sweep_until) {
                    self.sweep_until = frame.now + policy.scan_period_ms;
                    self.sweep_index = (self.sweep_index + 1) % sweep_headings.len;
                }
                sweep_offset = sweep_headings[self.sweep_index];
            } else if (intent.leash != null) {
                // Holding ground with nothing in view: sweep the surroundings.
                if (frame.now >= self.scan_until) {
                    self.scan_until = frame.now + 700;
                    self.scan_yaw = skill.wrap(pose.angles[1] + 75);
                }
                const radians = self.scan_yaw * std.math.pi / 180;
                aim = .{ @cos(radians), @sin(radians), 0 };
            }
        }
        if (v.length(aim) < 0.01) aim = facing;
        const limit = skill.turnLimit(policy, frame.turn_rate_limit, frame.now - self.step_ms);
        self.step_ms = frame.now;
        var wanted_yaw = skill.yaw(aim) + sweep_offset;
        var wanted_pitch = if (fighting or precise or intent.look_at != null) skill.pitch(aim) else 0;
        if (alert_view) |yaw| wanted_yaw = yaw;
        if (intent.view) |view| {
            wanted_yaw = view[0];
            wanted_pitch = view[1];
        }
        if (!fighting and !precise and intent.view == null) if (climb_normal) |normal| {
            wanted_yaw = skill.yaw(v.scale(normal, -1));
            wanted_pitch = 0;
        };
        if (fighting) {
            if (frame.now >= self.wobble_ready) {
                self.wobble_ready = frame.now + policy.wobble_ms;
                self.noise_yaw = skill.noise(&self.seed);
                self.noise_pitch = skill.noise(&self.seed);
            }
            const settle = @min(@as(f32, 1), @as(f32, @floatFromInt(frame.now - self.locked_ms)) / @as(f32, @floatFromInt(policy.settle_ms)));
            wanted_yaw += self.noise_yaw * policy.aim_error * (1 - settle);
            wanted_pitch += self.noise_pitch * policy.aim_error * (1 - settle);
        }
        const look_away = try evasion.lookAway(frame);
        if (look_away) |point| {
            wanted_yaw = skill.yaw(v.subtract(pose.position, point));
            wanted_pitch = 80;
        }
        const angles: v.Vec3 = .{ skill.pitchTurn(pose.angles[0], wanted_pitch, limit), skill.turn(pose.angles[1], wanted_yaw, limit), 0 };
        command.angles = angles;
        const view_forward = v.basis(angles).forward;
        const centred = v.dot(view_forward, v.normalize(aim)) > 0.99;

        // Fire discipline: only once the view has settled on the lead point, so
        // ammunition is not spent while the view is still swinging round.
        var on_target = v.dot(view_forward, v.normalize(aim)) > policy.discipline;
        // Moving swimmers use the same lead, view discipline and shot-lane
        // checks as other targets. Waiting for their speed to fall below a
        // fixed threshold can suppress every attack during an entire chase.
        // A shot meeting something else right in front (a station, a pillar
        // beside the prey) comes back: bolts bounce and blasts splash. And a
        // bolt is a box: an edge a sight line just clears stops every shot.
        // Body-origin swings are selected when the attack starts. An eye ray
        // or one nominal swing cannot qualify all of their different arcs;
        // facing and reach qualify input, and the delayed strike resolves it.
        if (fighting and fallback_melee) if (enemy) |seen| {
            if (!try @import("melee.zig").canReach(world, entity, selected, 128, frame.table, angles, seen)) {
                on_target = false;
                report.lane_blocked = true;
            }
        };
        if (fighting and !body_aim) if (enemy) |seen| if (seen.get(data.Binding) catch null) |binding| {
            const lane = try frame.collision.trace(.{ .start = eye, .end = v.add(eye, v.scale(view_forward, @min(@as(f32, 96), report.enemy_distance))), .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_SHOT });
            if (on_target and !lineReaches(frame, lane, seen, binding.slot)) on_target = false;
            const line = try frame.collision.trace(.{ .start = eye, .end = enemy_point, .mins = @splat(-3), .maxs = @splat(3), .slot = frame.slot, .mask = @as(u32, c.MASK_SHOT) & ~@as(u32, c.CONTENTS_BODY) });
            if (!lineReaches(frame, line, seen, binding.slot)) {
                on_target = false;
                report.lane_blocked = true;
                if (engine.integer("developer") >= 3 and @mod(frame.now, 1000) == 0) {
                    var message: [256]u8 = undefined;
                    engine.print(std.fmt.bufPrintZ(&message, "dk3 {s} lane: t={d} eye={d:.0},{d:.0},{d:.0} aim={d:.0},{d:.0},{d:.0} end={d:.0},{d:.0},{d:.0} fraction={d:.3} solid={d}\n", .{ frame.label, frame.now, eye[0], eye[1], eye[2], enemy_point[0], enemy_point[1], enemy_point[2], line.end[0], line.end[1], line.end[2], line.fraction, @intFromBool(line.start_solid) }) catch "");
                }
            }
            // Qualify the round's own collision bounds: a frame or corner
            // that clips it can explode it beside the shooter. Point rounds
            // must not acquire an imaginary box that blocks valid shots.
            // It leaves from the muzzle, below the eye: up a slope the
            // floor rising between meets it (e1m4b's ramp), not the sight line.
            if (@import("weapon_catalog").find(@intCast(loadout.weapon))) |entry| if (entry.spec.splash_hazard) {
                const launch = @import("weapon_catalog").flightLaunch(@intCast(loadout.weapon), frame.table.entries[@intCast(loadout.weapon)], 0, 0);
                const muzzle = @import("../domain/combat.zig").muzzle(eye, angles, launch.muzzle);
                // Bodies count: another enemy stepping into the lane close by
                // takes the round as surely as a wall.
                const blast = try frame.collision.trace(.{ .start = muzzle, .end = enemy_point, .mins = entry.spec.projectile.mins, .maxs = entry.spec.projectile.maxs, .slot = frame.slot, .mask = c.MASK_SHOT });
                const near_self = v.length(v.subtract(blast.end, muzzle)) < entry.spec.projectile.splash_radius * 1.25;
                if (blast.start_solid or (blast.fraction < 1 and !lineReaches(frame, blast, seen, binding.slot) and (near_self or v.length(v.subtract(blast.end, enemy_point)) > 48))) {
                    on_target = false;
                    report.lane_blocked = true;
                }
            };
        };
        // Nobody of the party in the line of fire: the sight lane above sees
        // through bodies past arm's length, and a spread of pellets fans out.
        if (fighting) if (enemy != null) if (try allyInFire(frame, eye, enemy_point)) {
            on_target = false;
            report.lane_blocked = true;
            if (engine.integer("developer") >= 3 and @mod(frame.now, 1000) == 0) {
                var message: [96]u8 = undefined;
                engine.print(std.fmt.bufPrintZ(&message, "dk3 {s} lane: t={d} ally blocks fire\n", .{ frame.label, frame.now }) catch "");
            }
        };
        if (intent.trigger and selected == loadout.weapon and loadout.weaponstate != 1 and loadout.weaponstate != 2) {
            command.attack = true;
            report.fired = true;
        }
        // Trigger discipline the caller asked for (a hurt companion falling
        // back still finishes what is nearly dead).
        const allowed = switch (intent.fire) {
            .free => true,
            .hold => false,
            .finish_only => if (enemy) |seen| if (seen.get(data.Health) catch null) |health| health.current <= finish_health else false else false,
        };
        if (fighting and engine.integer("developer") >= 3) {
            var text: [200]u8 = undefined;
            engine.print(std.fmt.bufPrintZ(&text, "dk3 {s} fire: t={d} target={d} distance={d:.0} on_target={d} lane_blocked={d} allowed={d} reserved={d} discharge={d} hold={d} selected={d} weapon={d} reaction={d} attack={d} ducked={d} hp={d}\n", .{ frame.label, frame.now, self.target, report.enemy_distance, @intFromBool(on_target), @intFromBool(report.lane_blocked), @intFromBool(allowed), @intFromBool(reserved), @intFromBool(discharge), @intFromBool(frame.now < self.hold_fire_until), selected, loadout.weapon, @intFromBool(frame.now >= self.reaction_ready), @intFromBool(combat.attack(loadout, frame.table, report.enemy_distance)), @intFromBool(player.ducked), if (world.get(entity, data.Health)) |health| health.current else |_| 0 }) catch "");
        }
        const keep_trigger = if (@import("weapon_catalog").find(selected)) |entry| entry.spec.bot_hold_trigger and loadout.dk3AttackHeld != 0 else false;
        const maintaining_charge = selected == loadout.weapon and combat.maintainCharge(loadout);
        if (fighting and allowed and (on_target or maintaining_charge) and !reserved and !discharge and frame.now >= self.hold_fire_until and !player.respawned and selected == loadout.weapon and frame.now >= self.reaction_ready and (frame.now >= self.shot_ready or keep_trigger or maintaining_charge) and (maintaining_charge or combat.attack(loadout, frame.table, report.enemy_distance))) {
            command.attack = true;
            if (frame.now >= self.shot_ready) {
                self.shot_ready = frame.now + policy.burst_ms;
                report.fired = true;
            }
        }
        // Fire that does not hurt the target is ammunition thrown away.
        if (enemy) |seen| if (seen.get(data.Health) catch null) |health| {
            if (self.target != self.futile_target or health.current < self.futile_health) {
                self.futile_target = self.target;
                self.futile_health = health.current;
                self.futile_ms = frame.now;
                self.futile_shots = 0;
            }
            if (report.fired and !maintaining_charge) self.futile_shots += 1;
            // A blast weapon's burst lands within a second: two rounds that
            // did not hurt it (bursting on a stair's edge short of it) tell.
            const blast = if (@import("weapon_catalog").find(@intCast(loadout.weapon))) |entry| entry.spec.splash_hazard else false;
            const futile_after: u32 = if (blast) 2 else 5;
            const futile_window: i64 = if (blast) 1500 else 3000;
            if (self.futile_shots >= futile_after and frame.now - self.futile_ms > futile_window) {
                // Another weapon that can reach it is tried first; only with
                // none is the target futile.
                // A fallback must also be able to harm this target. An
                // immune target must not silence its only admitted weapon
                // merely because another gun still has ammunition.
                if (self.spent_until <= frame.now and combat.rangedAlternative(loadout, frame.table, .{ .advancing = true, .excluded = excluded })) {
                    self.spent_weapon = loadout.weapon;
                    self.spent_until = frame.now + 15000;
                    self.futile_ms = frame.now;
                    self.futile_shots = 0;
                } else {
                    report.futile = true;
                    self.hold_fire_until = frame.now + 2500;
                    self.futile_ms = frame.now;
                    self.futile_shots = 0;
                }
            }
        };
        var use_slot = intent.use_slot;
        var shoot_slot = intent.shoot_slot;
        if (self.control) |control| if (control_aim != null and precise) if (world.find(control.id)) |target| {
            const slot = (try world.get(target, data.Binding)).slot;
            if (control.action == .use) use_slot = slot;
            if (control.action == .shoot) shoot_slot = slot;
        };
        if (centred and (use_slot != null or shoot_slot != null)) {
            const reach: f32 = if (use_slot != null) 96 else @max(96, v.length(aim) + 8);
            // As the game's own use and shots trace: through trigger volumes
            // (a music trigger across a doorway, e1m4c).
            const hit = try frame.collision.trace(.{ .start = eye, .end = v.add(eye, v.scale(view_forward, reach)), .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_SHOT });
            if (use_slot) |slot| if (frame.capabilities.use and hit.entity == slot and frame.now >= self.use_ready) {
                self.use_ready = frame.now + 1000;
                report.used = true;
                report.used_slot = slot;
            };
            if (shoot_slot) |slot| if (hit.entity == slot and !discharge and !player.respawned and selected == loadout.weapon and combat.attack(loadout, frame.table, v.length(aim)) and try objectBlastSafe(frame, eye, angles, loadout.weapon, slot, v.add(eye, aim))) {
                command.attack = true;
                report.fired = true;
            };
        }

        // A control that will not take a press needs to be seen whole: where
        // the step is standing, what it aims at, and what the game's own use
        // trace answers down that line.
        if (engine.integer("developer") >= 3) if (intent.use_slot) |want| if (intent.face) |face_point| {
            var aim_text: [240]u8 = undefined;
            const sight = try frame.collision.trace(.{ .start = eye, .end = v.add(eye, v.scale(view_forward, 96)), .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_SHOT });
            const held_goal = intent.destination orelse face_point;
            engine.print(std.fmt.bufPrintZ(&aim_text, "dk3 {s} aim: t={d} pos={d:.0},{d:.0},{d:.0} face={d:.0},{d:.0},{d:.0} dest={d:.0},{d:.0},{d:.0} use={d} centred={d} hit={d} fraction={d:.2}\n", .{ frame.label, frame.now, pose.position[0], pose.position[1], pose.position[2], face_point[0], face_point[1], face_point[2], held_goal[0], held_goal[1], held_goal[2], want, @intFromBool(centred), sight.entity, sight.fraction }) catch "");
        };
        // The same for a shot ordered at an object: what the view answers to,
        // and which of the pilot's own checks withholds the trigger (a weapon
        // not yet settled in the hand, a blast that would catch the shooter).
        if (engine.integer("developer") >= 3) if (intent.use_slot == null) if (intent.shoot_slot) |want| if (intent.face) |face_point| {
            var aim_text: [288]u8 = undefined;
            const sight = try frame.collision.trace(.{ .start = eye, .end = v.add(eye, v.scale(view_forward, @max(96, v.length(aim) + 8))), .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_SHOT });
            const held_goal = intent.destination orelse face_point;
            engine.print(std.fmt.bufPrintZ(&aim_text, "dk3 {s} aim: t={d} pos={d:.0},{d:.0},{d:.0} face={d:.0},{d:.0},{d:.0} dest={d:.0},{d:.0},{d:.0} shoot={d} centred={d} hit={d} fraction={d:.2} selected={d} weapon={d} attack={d} discharge={d} safe={d}\n", .{ frame.label, frame.now, pose.position[0], pose.position[1], pose.position[2], face_point[0], face_point[1], face_point[2], held_goal[0], held_goal[1], held_goal[2], want, @intFromBool(centred), sight.entity, sight.fraction, selected, loadout.weapon, @intFromBool(combat.attack(loadout, frame.table, v.length(aim))), @intFromBool(discharge), @intFromBool(try objectBlastSafe(frame, eye, angles, loadout.weapon, want, v.add(eye, aim))) }) catch "");
        };
        // Locomotion follows the route heading, independent of where the view
        // points: player movement is applied relative to the view the command
        // carries, so the heading is resolved against that view (the yaw sent
        // this frame, still turning toward a look-at point or the travel way).
        const travel_yaw = angles[1];
        const axes = v.basis(.{ 0, travel_yaw, 0 });
        var direction = v.normalize(.{ movement[0], movement[1], 0 });
        // What the stride was built from, before any hazard or exit bends it:
        // the place the step aims at and the vector it chose. A heading that
        // does not point at the action's goal is decided above, here — a
        // stride kept off its own line is otherwise invisible in the log.
        if (engine.integer("developer") >= 3) {
            var trace_text: [352]u8 = undefined;
            const stride_from = destination orelse @as(v.Vec3, @splat(0));
            engine.print(std.fmt.bufPrintZ(&trace_text, "dk3 {s} stride: t={d} pos={d:.0},{d:.0},{d:.0} dest={d:.0},{d:.0},{d:.0} want={d:.0},{d:.0},{d:.0} raw={d:.0},{d:.0} direct={d} air={d} under={d} ctl={d} wp={d:.0},{d:.0},{d:.0} back={d:.0},{d:.0},{d:.0} px={d:.0},{d:.0},{d:.0} fb={d}\n", .{ frame.label, frame.now, pose.position[0], pose.position[1], pose.position[2], stride_from[0], stride_from[1], stride_from[2], (destination orelse pose.position)[0] - pose.position[0], (destination orelse pose.position)[1] - pose.position[1], (destination orelse pose.position)[2] - pose.position[2], movement[0], movement[1], @intFromBool(intent.direct), @intFromBool(in_the_air), player.ground_entity, if (self.control) |control| control.id else 0, (if (report.waypoint) |waypoint| waypoint.point else @as(v.Vec3, @splat(0)))[0], (if (report.waypoint) |waypoint| waypoint.point else @as(v.Vec3, @splat(0)))[1], (if (report.waypoint) |waypoint| waypoint.point else @as(v.Vec3, @splat(0)))[2], self.routable_point[0], self.routable_point[1], self.routable_point[2], (if (self.passage) |passage| passage.route.point else @as(v.Vec3, @splat(0)))[0], (if (self.passage) |passage| passage.route.point else @as(v.Vec3, @splat(0)))[1], (if (self.passage) |passage| passage.route.point else @as(v.Vec3, @splat(0)))[2], self.direct_fallback_until }) catch "");
        }
        if (frame.now < self.unstick_until) {
            if (player.water_level >= 2) {
                // The sidestep a walker shakes loose with asks for floor under
                // it; a swimmer presses against the water itself instead, so it
                // uses the two strokes a player uses in a corner in turn — back
                // out of the corner the current set the body into, then around
                // the obstruction (e1m2a's canal: pressed under the sunken slab,
                // holding a stroke that moved nothing drowned the bot there
                // through eleven restorations).
                report.breathing = 4;
                const along = if (v.length(direction) > 0.01) direction else axes.forward;
                direction = if (self.unstick_side > 0)
                    v.scale(along, -1)
                else
                    v.normalize(v.add(along, v.scale(axes.right, self.unstick_side)));
            } else {
                const shaken = v.normalize(v.add(direction, v.scale(axes.right, self.unstick_side)));
                if (try evasion.supported(frame, pose.position, v.add(pose.position, v.scale(shaken, 40)))) direction = shaken else self.unstick_until = 0;
            }
        }
        // Hazards overhead count against the hull the player moves with: a
        // crouch passes under a fan's guard a standing player would touch.
        const head: f32 = if (crouch or intent.crouch) 4 else frame.hull.maxs[2];
        // Under a lift that is moving close overhead (a raised platform
        // called down): step out of its shaft before it arrives.
        if (try crushOverhead(frame, pose.position)) |away| direction = away;
        // A lingering blast close (one fired down the way the route goes
        // on): back out of its reach and wait there.
        if (try lingeringNear(frame, pose.position)) |blast| {
            const center = blast.center;
            var out = v.subtract(pose.position, center);
            out[2] = 0;
            out = if (v.length(out) > 1) v.normalize(out) else v.scale(axes.forward, -1);
            if (nav.horizontalDistance(pose.position, center) < blast.lingering.clear) {
                direction = if (try evasion.supported(frame, pose.position, v.add(pose.position, v.scale(out, 40)))) out else @splat(0);
            } else if (v.dot(direction, out) < 0) direction = @splat(0);
        }
        // A qualified step off a moving body has priority over holding a
        // firing stand or a shorter-footing check around a nearby blast.
        if (dismount) |stride| {
            direction = v.normalize(stride);
            self.unstick_until = 0;
            self.jump_until = self.body_step_jump_until;
            crouch = dismount_crouch;
            intent.crouch = dismount_crouch;
        }
        // A current (a targetless push: a draught, a water flow) beside a drop
        // shoves whoever touches it over the edge: lean away from it while
        // going on, as a player keeps off it. A heading that runs with the
        // current is riding it where the route means to go (e1m2b's sluice
        // carries a body over the lip into the tank), so straight steering is
        // guarded too, but only against a cross-current.
        if (player.ground_entity != c.ENTITYNUM_NONE and v.length(direction) > 0.01) direction = try leanFromCurrents(frame, pose.position, direction, intent.direct);
        // Walking along a lethal volume (a floor fan's blades at the edge of
        // the way): keep a hand's breadth off it, as a player does.
        if (player.ground_entity != c.ENTITYNUM_NONE and v.length(direction) > 0.01) direction = try leanFromHazards(frame, pose.position, direction, head, nav.horizontalDistance(movement, @splat(0)));
        // A ledge whose lip over lethal liquid closes on the way: the area graph
        // walks an area's centre, and on a catwalk cut by a diagonal edge the
        // centre runs within a couple of units of the drop (e1m6c's west
        // ring). A hull that keeps only part of its width on the plank is
        // supported until it keeps none, so the run holds the edge right up
        // to the fall. Give the edge a wide berth, as a player does.
        if (player.ground_entity != c.ENTITYNUM_NONE and player.water_level < 2 and v.length(direction) > 0.01 and !intent.direct) direction = try leanFromLiquidEdge(frame, pose.position, direction, head);
        // The wide berth by lethal hazards is against knockback: in a fight.
        // Out of one, the route's own line along the edge (beside e1m4b's
        // floor fans) is walked.
        if (v.length(direction) > 0.01) report.avoided_exit = try avoidExits(frame, pose.position, direction, intent.exit, head, fighting, nav.horizontalDistance(movement, @splat(0)));
        // A stride into a wall slides along it: the way the player actually
        // goes must not run into an exit either (e1m3b's arrival ledge slides
        // along its wall into the way back to e1m3a).
        if (report.avoided_exit == 0) {
            const velocity = (try world.get(entity, data.Velocity)).linear;
            if (nav.horizontalDistance(velocity, @splat(0)) > 60) report.avoided_exit = try avoidExits(frame, pose.position, velocity, intent.exit, head, fighting, 40);
        }
        if (engine.integer("developer") >= 3) {
            var trace_text: [200]u8 = undefined;
            const velocity = (try world.get(entity, data.Velocity)).linear;
            engine.print(std.fmt.bufPrintZ(&trace_text, "dk3 {s} motor: t={d} pos={d:.0},{d:.0},{d:.0} direction={d:.2},{d:.2} vel={d:.0},{d:.0} avoided={d} yaw={d:.0} travel={d:.0} view={d:.0} fighting={d} crouch={d}\n", .{ frame.label, frame.now, pose.position[0], pose.position[1], pose.position[2], direction[0], direction[1], velocity[0], velocity[1], report.avoided_exit, pose.angles[1], travel_yaw, angles[1], @intFromBool(fighting), @intFromBool(crouch or intent.crouch) }) catch "");
        }
        if (report.avoided_exit != 0) {
            const velocity = (try world.get(entity, data.Velocity)).linear;
            direction = if (nav.horizontalDistance(velocity, @splat(0)) > 40)
                v.scale(v.normalize(.{ velocity[0], velocity[1], 0 }), -1)
            else
                @splat(0);
            self.unstick_until = 0;
            self.jump_until = 0;
        }
        // Never a stride into a lethal liquid (the nitrogen e1m6c's rooms
        // stand in, under a ring of catwalks): whatever steers that way,
        // straight at a prey the area graph has no way to, stops at the edge.
        // (Authored straight segments keep their line: a running drop over
        // the nitrogen onto e1m6b's platform is meant.)
        // Careful footing looks as far as the body would slide before it
        // stopped, and guards straight steering too (nothing authored leads
        // it across).
        // A hunt chooses its own footing, just as a companion does. Its prey
        // may stand on a pedestal across a poisonous pool; chasing it must
        // not inherit the permission an authored direct swim has to enter it.
        const careful = frame.capabilities.careful_footing or (!intent.direct and intent.preferred != 0);
        const velocity_now = (try world.get(entity, data.Velocity)).linear;
        const slick = careful and player.ground_entity != c.ENTITYNUM_NONE and try slickUnder(frame, pose.position);
        if ((careful or !intent.direct) and player.ground_entity != c.ENTITYNUM_NONE and player.water_level < 2 and v.length(direction) > 0.01) {
            // (No further than the step's own target: a turn short of the
            // liquid is the route's, and the slide check below brakes it.)
            const reach: f32 = if (careful) @min(stoppingReach(nav.horizontalDistance(velocity_now, @splat(0)), slick), @max(24, nav.horizontalDistance(movement, @splat(0)) + 16)) else 24;
            // (No hop to shake loose there either: it lands in the liquid.)
            if (try lethalAlong(frame, pose.position, direction, reach)) {
                direction = @splat(0);
                self.unstick_until = 0;
                self.jump_until = 0;
                report.blocked = true;
            }
        }
        // Carried toward lethal liquid faster than it could stop (ice
        // underfoot, a shove, a turn taken at a run): steer against the slide.
        if (careful and player.ground_entity != c.ENTITYNUM_NONE and player.water_level < 2) {
            const speed = nav.horizontalDistance(velocity_now, @splat(0));
            if (speed > 40) {
                const sliding: v.Vec3 = v.normalize(.{ velocity_now[0], velocity_now[1], 0 });
                if (v.dot(direction, sliding) > -0.5 and try lethalAlong(frame, pose.position, sliding, stoppingReach(speed, slick))) {
                    const braked = v.subtract(direction, v.scale(sliding, 1.5));
                    direction = v.normalize(.{ braked[0], braked[1], 0 });
                    self.jump_until = 0;
                }
            }
        }
        // Precise straight steering brakes into its goal instead of overrunning it.
        var magnitude: f32 = 127 * intent.pace;
        if (intent.direct and intent.brake) if (intent.destination) |goal| {
            magnitude *= std.math.clamp(nav.horizontalDistance(pose.position, goal) / 96, 0.15, 1);
        };
        // Walking off a ledge onto a landing (beside a pit, say): step off
        // slowly, so the fall ends on the landing rather than past it.
        if (!intent.direct and player.ground_entity != c.ENTITYNUM_NONE) if (self.route.waypoint) |waypoint| if (waypoint.drop and nav.horizontalDistance(waypoint.point, pose.position) < 112) {
            magnitude *= 0.35;
        };
        // Narrow footing (a beam over a pit): where the floor a stride ahead
        // falls away while the way stays level, walk instead of running so a
        // turn does not carry the player off the edge. Precise segments keep
        // the route's own pace (their braking, a door's timed window).
        // (Not running up to a jump: it needs the speed.)
        const jumping = if (self.route.waypoint) |waypoint| waypoint.jump else false;
        if (!intent.direct and !jumping and player.ground_entity != c.ENTITYNUM_NONE and player.water_level < 2 and movement[2] > -18 and v.length(direction) > 0.01) {
            const stride = v.add(pose.position, v.scale(v.normalize(.{ direction[0], direction[1], 0 }), 24));
            const below = try frame.collision.trace(.{ .start = stride, .end = v.add(stride, .{ 0, 0, -64 }), .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = frame.motionMask() });
            if (below.fraction == 1) magnitude *= 0.4;
        }
        // Walking on a flowing floor (a fan's conveyor top, a water race):
        // the brush underfoot shoves the body the whole time it stands there,
        // so a line walked straight drifts off its plank into the pit below.
        // Two answers, the ones a player gives: keep the stroke full, because
        // a slow careful step has no authority against a current and simply
        // travels with it; and aim upstream, so the track still runs where the
        // way goes. Riding with a current (the route's own errand down a
        // sluice) costs nothing: the flow has no sideways part to cancel.
        const flow = if (player.ground_entity != c.ENTITYNUM_NONE and player.water_level < 2 and v.length(direction) > 0.01) try currentUnder(frame, pose.position) else @as(v.Vec3, @splat(0));
        if (v.length(flow) >= 60) {
            magnitude = @max(magnitude, if (intent.brake) @as(f32, 76) else @as(f32, 121));
            // Braking into a goal that stands past the water is the same trap
            // as a careful step: half a stroke against a whole flow spends the
            // crossing sliding east off the shelf (e1m2b's race shoves at 200
            // against a wading walk of 266, so anything under three quarters of
            // the command is a body in the pit). Where the flow outranks the
            // stroke the run has, the stroke becomes the whole stroke.
            if (v.length(flow) > groundSpeed(player, magnitude) * 0.92) magnitude = 127 * intent.pace;
            // A crouched stroke (a quarter of the run) has no authority at all
            // against a current that outranks it: standing tall is the only way
            // back out, the way a player rises to wade out of a race.
            if (v.length(flow) > magnitude * run_speed / 127 * 0.5) crouch = false;
        }
        if (v.length(flow) >= 1) direction = aimAgainstCurrent(frame, pose.position, direction, flow, groundSpeed(player, magnitude));
        // The engine pays a walk by its dominant hand (`commandScale`: the
        // stroke's speed is run_speed * max(|forward|,|right|) / 127), so a lean
        // of nearly fifty degrees of side-stroke walks at three quarters of the
        // pace and hands the rest to the current. Against a flow both hands go
        // out along the same heading until the leading one is fully held: the
        // heading is untouched, and the whole walk is paid for -- the authority
        // a key that is only ever fully held gives a player.
        var stroke: [2]f32 = .{ v.dot(direction, axes.forward) * magnitude, v.dot(direction, axes.right) * magnitude };
        if (v.length(flow) >= 60) {
            const leading = @max(@abs(stroke[0]), @abs(stroke[1]));
            if (leading > 1) stroke = .{ stroke[0] * magnitude / leading, stroke[1] * magnitude / leading };
        }
        command.forward = @intFromFloat(std.math.clamp(stroke[0], -127, 127));
        command.right = @intFromFloat(std.math.clamp(stroke[1], -127, 127));
        // A ladder's horizontal movement is strafing along its face. Tiny
        // approach corrections must not become forward input facing away
        // from the rungs, which makes the ordinary player motor detach.
        if (climb_normal != null) command.forward = 0;
        if (crouch or intent.crouch) command.up = -127;
        // Standing to shoot, a player ducks where the target stays in sight
        // from down there.
        // Tactical crouching changes the muzzle after the firing lane was
        // qualified. Keep a blast weapon's stance stable through its burst;
        // authored crawl input remains available independently.
        const tactical_duck = if (@import("weapon_catalog").find(@intCast(loadout.weapon))) |entry| !entry.spec.splash_hazard else true;
        if (tactical_duck and frame.capabilities.duck_to_shoot and fighting and enemy != null and report.enemy_distance > 256 and !precise and player.ground_entity != c.ENTITYNUM_NONE and player.water_level < 2 and v.length(.{ direction[0], direction[1], 0 }) * magnitude < 64) {
            const low = v.add(pose.position, .{ 0, 0, -2 });
            // Use the same clearance as fire discipline. A point ray can
            // clear a raised floor while every round clips its edge, leaving
            // the shooter crouched indefinitely without a usable shot.
            const sight = try frame.collision.trace(.{ .start = low, .end = enemy_point, .mins = @splat(-3), .maxs = @splat(3), .slot = frame.slot, .mask = @as(u32, c.MASK_SHOT) & ~@as(u32, c.CONTENTS_BODY) });
            if (sight.fraction == 1) command.up = -127;
        }
        // A recovery hop cannot cancel the crawl that clears this passage,
        // or turn a deliberate gate wait into repeated jumps in place.
        if (intent.jump or (frame.now < self.jump_until and !intent.crouch and !report.holding)) {
            // A hop (a lip, shaking loose) that would come down in lethal
            // liquid is not taken. Navigation jumps also need this live
            // check: a compiled edge can lead across a hazardous opening.
            // Explicit scripted jumps retain their authored trajectory.
            const hop = careful and !intent.jump and player.ground_entity != c.ENTITYNUM_NONE and player.water_level < 2;
            if (hop and try hopLandsLethal(frame, pose.position, velocity_now, direction)) {
                self.jump_until = 0;
                self.unstick_until = 0;
            } else command.up = 127;
        }
        if (ladder and @abs(movement[2]) > 8) command.up = if (movement[2] > 0) 127 else -127;
        // Swimming: rise toward a higher goal, dive toward a deeper one (also
        // a waypoint more below than beside, such as the gap under a submerged
        // barrier), and otherwise keep the full stroke horizontal (vertical
        // input splits the swim speed, and a current then wins).
        if (player.water_level >= 2 and !ladder) {
            const across = nav.horizontalDistance(movement, @splat(0));
            if (movement[2] > 8) command.up = 127 else if (movement[2] < -48 or (movement[2] < -12 and across < -movement[2] * 2)) command.up = -127;
            // A ceiling edge ahead (the low gap of a flooded passage): where the
            // stroke is blocked at this depth but clear a little lower, dive.
            if (command.up >= 0 and across > 0.01 and frame.now >= self.unstick_until) {
                const flat = v.normalize(.{ movement[0], movement[1], 0 });
                const hull_mins = frame.hull.mins;
                const hull_maxs = frame.hull.maxs;
                const level = try frame.collision.trace(.{ .start = pose.position, .end = v.add(pose.position, v.scale(flat, 24)), .mins = hull_mins, .maxs = hull_maxs, .slot = frame.slot, .mask = frame.motionMask() });
                if (level.fraction < 1 and !level.start_solid) {
                    const lower = v.add(pose.position, .{ 0, 0, -16 });
                    const under = try frame.collision.trace(.{ .start = lower, .end = v.add(lower, v.scale(flat, 24)), .mins = hull_mins, .maxs = hull_maxs, .slot = frame.slot, .mask = frame.motionMask() });
                    if (!under.start_solid and under.fraction == 1) command.up = -127;
                }
            }
            if (intent.swim_depth) |depth| {
                const vertical = (depth - pose.position[2]) * 8 - velocity_now[2];
                command.up = @intFromFloat(std.math.clamp(vertical, -127, 127));
            }
        }
        // Under water the route's own depth is followed (tunnels and passages
        // under barriers). A player-like body has twelve seconds of air: it
        // rises straight up in time to reach the air measured above it, at a
        // cautious stroke. Under a ceiling (a pier, a grate, a flooded hall),
        // once a third of its air is gone it swims to the nearest open water
        // with air above, else back to where it last breathed (the reference
        // sends a drowning sidekick to its nearest ground node).
        const exposure = try @import("environment.zig").measure(frame.collision, pose.position, (try world.get(entity, data.Body)).*, player.view_height, frame.slot);
        if (!exposure.needsAir()) {
            self.submerged_ms = frame.now;
            self.breath_point = pose.position;
            self.air_target = null;
        } else {
            const under = frame.now - self.submerged_ms;
            report.submerged_ms = under;
            if (intent.direct and intent.swim_depth != null) {
                // An explicit dive owns its corridor and depth, including the
                // next corner and air pocket. Turning toward a previous breath
                // partway through it abandons the passage and can drown a body
                // whose way forward is shorter. Normal drowning still applies;
                // the route must reach air with ordinary movement.
                self.air_target = null;
            } else if (try airDistance(frame, pose.position, player.view_height)) |distance| {
                if (under + surfacing_margin_ms + @as(i64, @intFromFloat(distance / surfacing_speed * 1000)) >= air_ms) {
                    report.breathing = 1;
                    command.up = 127;
                    command.forward = 0;
                    command.right = 0;
                }
            } else if (under >= air_ms / 3) {
                if (frame.now >= self.air_search_ms) {
                    self.air_search_ms = frame.now + 500;
                    const open = try nearestAir(frame, pose.position, player.view_height, intent.destination);
                    self.breath_found = open != null;
                    // Turning back to the last breath is the longer swim in
                    // most cases, and it is the one stroke that gives the route
                    // up: only once most of the air is gone is it worth more
                    // than the way forward (e1m2a's canal: with no open water
                    // anywhere under the sunken slab, a bot that turns for the
                    // breath it had two thirds of the leg ago drowns having
                    // abandoned the passage through).
                    self.air_target = open;
                    if (self.air_target == null and under >= air_ms * 3 / 4) {
                        // Where the route itself is going has air above it and
                        // the rest of the swim fits the air that is left, the
                        // way forward *is* the way to air: swim the leg out
                        // instead of turning for a surface behind.
                        const left: f32 = @floatFromInt(air_ms - under);
                        const onward = if (intent.destination) |point| blk: {
                            if (v.length(.{ point[0] - pose.position[0], point[1] - pose.position[1], 0 }) > left / 1000 * air_swim_speed - 96) break :blk null;
                            break :blk if (try airDistance(frame, point, player.view_height) != null) point else null;
                        } else null;
                        self.air_target = onward orelse self.breath_point;
                    }
                }
                // Shaking loose comes first: while the body is reversing out of
                // the corner, the headless stroke toward the last breath is
                // what pressed it in.
                if (self.air_target) |point| {
                    if (frame.now >= self.unstick_until) {
                        report.breathing = if (self.breath_found) @as(u8, 2) else @as(u8, 3);
                        const toward = v.subtract(point, pose.position);
                        const across = nav.horizontalDistance(toward, @splat(0));
                        if (across > 8) {
                            const yaw = command.angles[1] * std.math.pi / 180;
                            const flat: v.Vec3 = .{ toward[0] / across, toward[1] / across, 0 };
                            command.forward = @intFromFloat(std.math.clamp((flat[0] * @cos(yaw) + flat[1] * @sin(yaw)) * 127, -127, 127));
                            command.right = @intFromFloat(std.math.clamp((flat[0] * @sin(yaw) - flat[1] * @cos(yaw)) * 127, -127, 127));
                        }
                        command.up = if (toward[2] > 8) 127 else 0;
                    }
                }
            }
        }
        if (frame.capabilities.tread_water and !ladder and player.water_level >= 2 and command.up == 0 and !intent.crouch and movement[2] >= -12) {
            if (player.water_level == 3) {
                // Head under with nothing calling for depth: up to the air
                // straight above (none under a ceiling: the air budget above
                // finds it).
                if (try airDistance(frame, pose.position, player.view_height) != null) command.up = 127;
            } else if (command.forward == 0 and command.right == 0 and player.ground_entity == c.ENTITYNUM_NONE) {
                // At the surface with nothing pressed a swimmer sinks: tread water
                // (one standing waist-deep on the bottom stays put).
                command.up = 24;
            }
        }
        // The swim stroke follows the view's pitch: aiming down at an enemy,
        // a forward stroke would dive. Cancel the pitch's share of it.
        if (player.water_level >= 2 and !ladder and command.up == 0 and command.forward != 0) {
            const sink = @sin(command.angles[0] * std.math.pi / 180) * @as(f32, @floatFromInt(command.forward));
            command.up = @intFromFloat(std.math.clamp(sink, -127, 127));
        }
        // In lava, slime or nitrogen (knocked in, a slide, a missed landing):
        // nothing else matters, straight for the nearest safe floor, jumping
        // for its rim.
        if (careful and player.mode == .normal) {
            const feet = try frame.collision.contents(v.add(pose.position, .{ 0, 0, frame.hull.mins[2] + 1 }), frame.slot);
            if (feet & frame.liquid_mask != 0) {
                if (self.escape_target == null or frame.now >= self.escape_search_ms) {
                    self.escape_search_ms = frame.now + 400;
                    self.escape_target = try safeFloorNear(frame, pose.position);
                }
                if (self.escape_target) |point| {
                    report.escaping = true;
                    const toward = v.subtract(point, pose.position);
                    const across = nav.horizontalDistance(toward, @splat(0));
                    if (across > 4) {
                        const yaw = command.angles[1] * std.math.pi / 180;
                        const flat: v.Vec3 = .{ toward[0] / across, toward[1] / across, 0 };
                        command.forward = @intFromFloat(std.math.clamp((flat[0] * @cos(yaw) + flat[1] * @sin(yaw)) * 127, -127, 127));
                        command.right = @intFromFloat(std.math.clamp((flat[0] * @sin(yaw) - flat[1] * @cos(yaw)) * 127, -127, 127));
                    }
                    command.up = if (toward[2] > -8 or player.water_level >= 2) 127 else 0;
                } else report.escape_failed = true;
            } else self.escape_target = null;
        }
        // A body told to rise well above itself, off the floor: what the climb
        // sees, in the evidence (route authoring; a ladder's attach is a hull
        // trace, and nothing else in the log says why a rise comes to nothing).
        if (engine.integer("developer") >= 2 and movement[2] > 24 and player.water_level < 2 and frame.now >= self.climb_told_ms) {
            self.climb_told_ms = frame.now + 400;
            const face = try climbable(frame, pose.position);
            const normal = face orelse v.Vec3{ 0, 0, 0 };
            var text: [256]u8 = undefined;
            engine.print(std.fmt.bufPrintZ(&text, "dk3 {s}: t={d} event=climb pos={d:.0},{d:.0},{d:.0} move={d:.0},{d:.0},{d:.0} ladder={d} face={d:.1},{d:.1},{d:.1} up={d} forward={d} right={d} view={d:.0},{d:.0} ground={d}\n", .{ frame.label, frame.now, pose.position[0], pose.position[1], pose.position[2], movement[0], movement[1], movement[2], @intFromBool(ladder), normal[0], normal[1], normal[2], command.up, command.forward, command.right, command.angles[1], command.angles[0], player.ground_entity }) catch "");
        }
        command.use = report.used;
        // A physically qualified local corridor has its own feedback stroke.
        // Apply the same stroke that prediction checked: stale AAS jump/drop
        // flags or an unstick turn must not replace it after qualification.
        // Combat, body detours, moving supports and live hazard/exit
        // refusals retain control. A cached corridor does not predict a
        // body stepping into it after qualification.
        if (!fighting and !report.dodging and !report.sidestepped and !intent.direct and !intent.crouch and !intent.jump and intent.pace == 1 and !on_mover and !ladder and player.mode == .normal and self.control == null and self.passage == null and report.avoided_exit == 0 and frame.now < self.route.physical_until_ms and v.length(movement) > 1) if (destination) |goal| {
            if (v.length(v.subtract(goal, self.route.physical_goal)) < 8) {
                const forecast = @import("../domain/motion_forecast.zig");
                var local_walk = if (frame.motor) |parameters| try forecast.walkInput(pose.position, self.route.physical_point, frame.now, parameters, frame.collision) else forecast.walkCommand(pose.position, self.route.physical_point, frame.now, run_speed);
                if (frame.turn_rate_limit != null) local_walk = forecast.walkFacing(local_walk, angles);
                command.angles = local_walk.angles;
                command.forward = local_walk.forward;
                command.right = local_walk.right;
                command.up = local_walk.up;
            }
        };
        if (look_away != null) {
            command.attack = false;
            report.fired = false;
        }
        return .{ .report = report, .command = command };
    }
    /// Route step with commitment: a chosen waypoint is followed until reached,
    /// blocked or 2.5 s old. Adjacent AAS areas can each route through the
    /// other's entrance; re-planning on every boundary crossing then oscillates.
    fn reachableNear(self: *Pilot, frame: Frame, position: v.Vec3, goal: v.Vec3, direct_radius: f32) !v.Vec3 {
        return reachableNearImpl(self, frame, position, goal, direct_radius);
    }
    fn follow(self: *Pilot, frame: Frame, position: v.Vec3, requested: v.Vec3, direct_radius: f32) !?nav.Waypoint {
        const lifts = frame.now >= self.lifts_off_until;
        const physical = frame.now < self.route.physical_until_ms and v.length(v.subtract(requested, self.route.physical_goal)) < 8 and nav.horizontalDistance(position, self.route.physical_point) > 2;
        const physical_point = if (physical) self.route.physical_point else try motorRoute(frame, position, requested);
        const walking = physical_point != null;
        // Test the actual body-space goal before an AAS endpoint substitute.
        // A hull can walk to a point outside the player-sized area graph;
        // replacing it first can manufacture a detour away from that point.
        const goal = if (walking) requested else try self.reachableNear(frame, position, requested, direct_radius);
        const fresh = try self.route.update(frame.service, .{ .position = position, .destination = goal, .slot = frame.slot, .player = true, .allow_slime_escape = true, .lifts = lifts }, frame.now);
        if (walking) {
            if (!physical) {
                self.route.physical_until_ms = frame.now + 500;
                self.route.physical_goal = goal;
            }
            self.route.physical_point = physical_point.?;
            self.route.waypoint = .{ .point = physical_point.? };
            self.route.refresh_ms = self.route.physical_until_ms;
            self.committed = null;
            self.committed_until = 0;
            self.unstick_until = 0;
            if (frame.state.ground_entity != c.ENTITYNUM_NONE) self.jump_until = 0;
            return .{ .point = physical_point.? };
        }
        // The area graph offers a step away from a goal the hull could be
        // walked to in a straight line: the walk is taken instead. Navigation
        // splits a narrow ledge into thin areas whose entrances lie behind the
        // traveller, and a hull straddling such an entrance is then routed out
        // over the ledge's end (e1m2b's shelf above the pit walked a bot into
        // the pit on its way to the valve wheel eight steps away).
        if (try walksStraight(frame, position, goal, fresh)) {
            self.committed = null;
            self.committed_until = 0;
            return nav.Waypoint{ .point = goal };
        }
        if (self.committed) |held| {
            const reached = v.length(v.subtract(position, held.point)) < 24;
            if (!reached and !self.route.blocked and frame.now < self.committed_until and v.length(v.subtract(held.point, goal)) <= v.length(v.subtract(position, goal)) + 256) return held;
        }
        var chosen = fresh;
        if (fresh) |waypoint| if (!waypoint.jump and !waypoint.crouch and !waypoint.ladder) {
            if (try lookAhead(frame, position, goal)) |far| chosen.?.point = far;
        };
        // Flipping back to the waypoint before last: aim at a point further
        // along the predicted route instead, beyond both entrances.
        if (chosen) |waypoint| if (self.previous_point) |before| if (self.committed) |current| {
            if (v.length(v.subtract(waypoint.point, before)) < 8 and v.length(v.subtract(current.point, waypoint.point)) > 8) {
                var points: [6]v.Vec3 = undefined;
                const count = try frame.service.predict(.{ .position = position, .destination = goal, .slot = frame.slot, .player = true, .allow_slime_escape = true, .lifts = lifts }, &points);
                var index = count;
                while (index > 0) {
                    index -= 1;
                    const point = points[index];
                    if (nav.horizontalDistance(point, position) < 40 or nav.horizontalDistance(point, position) > 256) continue;
                    if (v.length(v.subtract(point, waypoint.point)) < 8 or v.length(v.subtract(point, current.point)) < 8) continue;
                    if (@abs(point[2] - position[2]) > 20 or !try walkable(frame, position, point)) continue;
                    chosen.?.point = point;
                    break;
                }
            }
        };
        if (self.committed) |current| self.previous_point = current.point;
        self.committed = chosen;
        self.committed_until = frame.now + 2500;
        return chosen;
    }
    fn sidestep(self: *Pilot, frame: Frame, position: v.Vec3, movement: v.Vec3, report: *Report, crouch: *bool) !?v.Vec3 {
        const collision = frame.collision;
        const hull_mins = frame.hull.mins;
        const hull_maxs = frame.hull.maxs;
        const direction = v.normalize(.{ movement[0], movement[1], 0 });
        const ahead = try collision.trace(.{ .start = position, .end = v.add(position, v.scale(direction, 40)), .mins = hull_mins, .maxs = hull_maxs, .slot = frame.slot, .mask = frame.motionMask() });
        if (ahead.fraction == 1 or ahead.start_solid or ahead.normal[2] >= 0.7) return null;
        report.obstacle = ahead.entity;
        const blocker = occupant(frame, ahead) orelse return null;
        report.obstacle_id = try blocker.id();
        // A closed or moving door is opened or waited for; one standing open
        // with a part still in the way (a sliding door's lip in the
        // doorway) is walked round once pressing on along it has stalled or
        // keeps circling the route's point by it (hops there are not
        // progress); a doorway the route threads exactly is slid through.
        if (blocker.get(data.Mover) catch null) |mover| {
            if (engine.integer("developer") >= 3) {
                var text: [160]u8 = undefined;
                engine.print(std.fmt.bufPrintZ(&text, "dk3 {s} sidestep mover: t={d} state={s} moving={d} blocked={d} hover_ms={d}\n", .{ frame.label, frame.now, @tagName(mover.state), @intFromBool(mover.moving()), @intFromBool(self.route.blocked), frame.now - self.hover_ms }) catch "");
            }
            if (mover.state != .open or mover.moving() or !(self.route.blocked or frame.now - self.hover_ms > 1500 or frame.now - self.direct_ms > 1500)) return null;
        }
        // The walls of a cart the player stands in are not walked around.
        if (ahead.world == 0 and ahead.entity == frame.state.ground_entity) return null;
        // A hovering body can block standing clearance above a narrow walk.
        // Check the same forty-unit horizon with the real crouched hull
        // before choosing a lateral detour. Bodies still cannot be footing.
        const destination = v.add(position, v.scale(direction, 40));
        if (try steering.crouchReach(collision, position, destination, hull_mins, hull_maxs, frame.slot, frame.motionMask(), 40) and
            try evasion.supportedUnder(frame, position, destination, 4))
        {
            crouch.* = true;
            self.unstick_until = 0;
            self.jump_until = 0;
            return null;
        }
        // A ledge the player can step onto is not an obstruction.
        const raised = v.add(position, .{ 0, 0, 18 });
        if ((try collision.trace(.{ .start = raised, .end = v.add(raised, v.scale(direction, 40)), .mins = hull_mins, .maxs = hull_maxs, .slot = frame.slot, .mask = frame.motionMask() })).fraction == 1) return null;
        for ([_]f32{ 35, 70, 100 }) |degrees| for ([_]f32{ self.detour_side, -self.detour_side }) |side| {
            const angle = std.math.atan2(direction[1], direction[0]) + side * degrees * std.math.pi / 180;
            const turned: v.Vec3 = .{ @cos(angle), @sin(angle), 0 };
            const clear = try collision.trace(.{ .start = position, .end = v.add(position, v.scale(turned, 40)), .mins = hull_mins, .maxs = hull_maxs, .slot = frame.slot, .mask = frame.motionMask() });
            if (clear.fraction < 1 or clear.start_solid) continue;
            if (!try evasion.supported(frame, position, v.add(position, v.scale(turned, 40)))) continue;
            self.detour_side = side;
            return v.scale(turned, v.length(.{ movement[0], movement[1], 0 }));
        };
        return null;
    }
};
/// Engagement choice: hostile actors inside the view cone (or close enough to
/// sense) with a clear shot line. A scripted kill target wins ties.
const Scan = struct {
    frame: Frame,
    intent: Intent,
    policy: skill.Profile,
    facing: v.Vec3,
    eye: v.Vec3,
    self_id: u32,
    target: u32,
    nuisance: u32,
    enemy: ?Ref = null,
    point: v.Vec3 = @splat(0),
    nearest: f32 = std.math.inf(f32),
    fn consider(self: *Scan, candidate: Ref) !void {
        const frame = self.frame;
        const intent = self.intent;
        const actor = (candidate.get(data.Actor) catch return).*;
        const health = (candidate.get(data.Health) catch return).*;
        const transform = (candidate.get(data.Transform) catch return).*;
        const binding = (candidate.get(data.Binding) catch return).*;
        const body = (candidate.get(data.Body) catch return).*;
        if (health.current <= 0) return;
        const kind = catalog.entries[actor.definition].kind;
        if (frame.capabilities.ignore_ambient and catalog.ambient(kind)) return;
        const identity = try candidate.id();
        // A civilian who has blocked a narrow passage for seconds is
        // dealt with as a player would; otherwise only hostiles.
        if (!route.hostile(kind) and (self.nuisance == 0 or identity != self.nuisance)) return;
        var point = v.add(transform.position, .{ 0, 0, (body.mins[2] + body.maxs[2]) * 0.5 });
        // Partly submerged bodies (wading Crox) are hit above the surface;
        // a shot at the centre only strikes the water.
        if (try frame.collision.contents(point, frame.slot) & c.MASK_WATER != 0) point[2] = transform.position[2] + body.maxs[2] - 2;
        var distance = v.length(v.subtract(point, self.eye));
        // Ammunition is finite: shoot what hunts this body (or the one it
        // guards), what is close, or what the route asked to kill; let the
        // rest be.
        const provoked = actor.threat == self.self_id or (intent.guard != 0 and actor.threat == intent.guard);
        if (distance > intent.engage_range and !provoked and identity != intent.preferred) return;
        if (!skill.sees(self.policy, self.facing, self.eye, point)) return;
        var trace = try frame.collision.trace(.{ .start = self.eye, .end = point, .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_SHOT });
        // Behind low cover (a worker at a console, a guard behind a
        // crate) the head may still be in the open: aim there.
        if (!lineReaches(frame, trace, candidate, binding.slot)) {
            point[2] = transform.position[2] + body.maxs[2] - 6;
            trace = try frame.collision.trace(.{ .start = self.eye, .end = point, .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_SHOT });
        }
        if (!lineReaches(frame, trace, candidate, binding.slot)) return;
        if (intent.preferred != 0 and identity == intent.preferred) distance *= 0.25;
        // Keep the current target unless another is clearly nearer:
        // switching on near ties swaps weapons instead of firing.
        if (identity == self.target) distance *= 0.6;
        if (distance >= self.nearest) return;
        self.nearest = distance;
        self.enemy = candidate;
        self.point = point;
    }
    fn considerPlayer(self: *Scan, candidate: Ref, session: data.Session) !void {
        return considerPlayerImpl(self, candidate, session);
    }
    fn considerBody(self: *Scan, candidate: Ref) !void {
        const frame = self.frame;
        if ((candidate.get(data.Health) catch return).current <= 0) return;
        const point = v.add((try candidate.get(data.Transform)).position, .{ 0, 0, 12 });
        const distance = v.length(v.subtract(point, self.eye));
        if (distance >= self.nearest or !skill.sees(self.policy, self.facing, self.eye, point)) return;
        const binding = (candidate.get(data.Binding) catch return).*;
        const trace = try frame.collision.trace(.{ .start = self.eye, .end = point, .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_SHOT });
        if (!lineReaches(frame, trace, candidate, binding.slot)) return;
        self.nearest = distance;
        self.enemy = candidate;
        self.point = point;
    }
};
/// A match's enemy players: any living, non-spectating, non-allied client in
/// the cone and in sight, aimed at the chest. No unprovoked-range limit: the
/// ladder's sight range is the limit.
fn considerPlayerImpl(self: *Scan, candidate: Ref, session: data.Session) !void {
    if ((candidate.get(data.Health) catch return).current <= 0) return;
    const member = (candidate.get(data.Session) catch return).*;
    if (member.team == .spectator or @import("../domain/multiplayer.zig").allied(session, member)) return;
    return self.considerBody(candidate);
}
/// Whether a line trace ended at `target` (or ran clear). A trace that crossed
/// into a neighbouring world names the slot there; a local one the slot here.
/// Whether a shot line runs clear from `eye` to the middle of `target`.
pub fn inSight(frame: Frame, eye: v.Vec3, target: Ref) !bool {
    const transform = (target.get(data.Transform) catch return false).*;
    const body = (target.get(data.Body) catch return false).*;
    const binding = (target.get(data.Binding) catch return false).*;
    const point = v.add(transform.position, .{ 0, 0, (body.mins[2] + body.maxs[2]) * 0.5 });
    const trace = try frame.collision.trace(.{ .start = eye, .end = point, .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_SHOT });
    return lineReaches(frame, trace, target, binding.slot);
}
/// A blast round fired at an object: its lane from the muzzle reaches the
/// object, and none of the party stands within its splash where it lands
/// (a bolt has no splash; a shot through a companion is caught by the
/// sight line).
fn objectBlastSafe(frame: Frame, eye: v.Vec3, angles: v.Vec3, weapon: i32, slot: u16, point: v.Vec3) !bool {
    const entry = @import("weapon_catalog").find(@intCast(weapon)) orelse return true;
    if (!entry.spec.splash_hazard) return true;
    const launch = @import("weapon_catalog").flightLaunch(@intCast(weapon), frame.table.entries[@intCast(weapon)], 0, 0);
    const muzzle = @import("../domain/combat.zig").muzzle(eye, angles, launch.muzzle);
    const blast = try frame.collision.trace(.{ .start = muzzle, .end = point, .mins = @splat(-6), .maxs = @splat(6), .slot = frame.slot, .mask = c.MASK_SHOT });
    if (blast.start_solid or (blast.fraction < 1 and blast.entity != slot and v.length(v.subtract(blast.end, point)) > 48)) return false;
    if (v.length(v.subtract(blast.end, muzzle)) < entry.spec.projectile.splash_radius * 1.25) return false;
    return !try allyNear(frame, blast.end, blast.end, entry.spec.projectile.splash_radius * 1.25);
}
/// Whether another of the party stands between the eye and the target,
/// within a widening cone about the line (a body's breadth, plus a spread).
fn allyInFire(frame: Frame, eye: v.Vec3, target: v.Vec3) !bool {
    const line = v.subtract(target, eye);
    const length = v.length(line);
    if (length < 1) return false;
    const direction = v.scale(line, 1 / length);
    for (frame.slots.occupants) |slot_entity| {
        const other = slot_entity orelse continue;
        if (other.index == frame.entity.index) continue;
        if (frame.targets == .specified and frame.targets.specified.world == frame.world and frame.targets.specified.entity.index == other.index) continue;
        if ((frame.world.get(other, data.Player) catch null) == null and !@import("../../game/server/session_classes.zig").party.isMember(frame.world, other)) continue;
        const health = frame.world.get(other, data.Health) catch continue;
        if (health.current <= 0) continue;
        const centre = v.add((frame.world.get(other, data.Transform) catch continue).position, .{ 0, 0, 8 });
        const along = v.dot(v.subtract(centre, eye), direction);
        if (along <= 0 or along >= length - 16) continue;
        const across = v.length(v.subtract(centre, v.add(eye, v.scale(direction, along))));
        if (across < 28 + along * 0.15) return true;
    }
    return false;
}
/// Whether another of the party (a player or a companion) stands within
/// `radius` of `to`, or within a stride of the line from `from` to it.
/// The nearest lingering blast within its class's hold distance.
fn lingeringNear(frame: Frame, position: v.Vec3) !?struct { center: v.Vec3, lingering: @import("weapon_classes/registry.zig").Lingering } {
    var nearest: ?v.Vec3 = null;
    var found: @import("weapon_classes/registry.zig").Lingering = undefined;
    var best: f32 = std.math.floatMax(f32);
    for (frame.slots.occupants) |slot_entity| {
        const other = slot_entity orelse continue;
        const lingering = @import("weapon_classes/registry.zig").lingeringOf(frame.world, other) orelse continue;
        const at = (frame.world.get(other, data.Transform) catch continue).position;
        const distance = v.length(v.subtract(at, position));
        if (distance < lingering.hold and distance < best) {
            best = distance;
            nearest = at;
            found = lingering;
        }
    }
    return if (nearest) |center| .{ .center = center, .lingering = found } else null;
}
pub fn allyNear(frame: Frame, from: v.Vec3, to: v.Vec3, radius: f32) !bool {
    for (frame.slots.occupants) |slot_entity| {
        const other = slot_entity orelse continue;
        if (other.index == frame.entity.index) continue;
        if (frame.targets == .specified and frame.targets.specified.world == frame.world and frame.targets.specified.entity.index == other.index) continue;
        if ((frame.world.get(other, data.Player) catch null) == null and !@import("../../game/server/session_classes.zig").party.isMember(frame.world, other)) continue;
        const health = frame.world.get(other, data.Health) catch continue;
        if (health.current <= 0) continue;
        const at = (frame.world.get(other, data.Transform) catch continue).position;
        if (v.length(v.subtract(at, to)) < radius) return true;
        const line = v.subtract(to, from);
        const length = v.length(line);
        if (length < 1) continue;
        const along = std.math.clamp(v.dot(v.subtract(at, from), line) / (length * length), 0, 1);
        if (v.length(v.subtract(at, v.add(from, v.scale(line, along)))) < 48) return true;
    }
    return false;
}
fn lineReaches(frame: Frame, hit: collision_module.Trace, target: Ref, slot: u16) bool {
    const owner = if (hit.world == 0) frame.world else &(access.byHandle(@enumFromInt(hit.world)) orelse return false).world.?;
    if (owner != target.world) return false;
    return hit.fraction == 1 or hit.entity == slot;
}
fn claimed(frame: Frame, route_obstacle: u32) bool {
    const team = frame.coordination orelse return false;
    return team.claimed(team.context, route_obstacle);
}
/// What a probe hit, in whichever world the trace ended.
fn occupant(frame: Frame, hit: collision_module.Trace) ?Ref {
    if (frame.region) return access.victim(frame.world, frame.slots, hit);
    if (hit.entity >= frame.slots.occupants.len) return null;
    return .{ .world = frame.world, .entity = frame.slots.occupants[hit.entity] orelse return null };
}
/// The way out from under a moving lift whose underside is within 200 units
/// above the player's head (null when none threatens).
pub fn crushOverhead(frame: Frame, position: v.Vec3) !?v.Vec3 {
    var query = frame.world.queryAccess(data.World.mask(.{ data.MapObject, data.Binding }), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.Binding)) |entity, binding| {
        if (binding.slot >= frame.projections.len) continue;
        const moving = if (@import("platforms.zig").pathPhase(frame.world, entity)) |phase| phase.moving else if (frame.world.get(entity, data.Mover) catch null) |mover| !mover.angular and mover.moving() and @abs(mover.opened[2] - mover.closed[2]) > 32 else false;
        if (!moving) continue;
        const box = frame.projections[binding.slot].shared;
        const hull = frame.hull;
        if (position[0] + hull.maxs[0] <= box.absmin[0] or position[0] + hull.mins[0] >= box.absmax[0] or position[1] + hull.maxs[1] <= box.absmin[1] or position[1] + hull.mins[1] >= box.absmax[1]) continue;
        const gap = box.absmin[2] - (position[2] + hull.maxs[2]);
        if (gap < 0 or gap > 200) continue;
        // Out toward the nearest side of its footprint.
        const centre = v.scale(v.add(box.absmin, box.absmax), 0.5);
        var out: v.Vec3 = .{ position[0] - centre[0], position[1] - centre[1], 0 };
        if (v.length(out) < 1) out = .{ 1, 0, 0 };
        return v.normalize(out);
    };
    return null;
}
/// `direction` bent away from an active current within reach whose push would
/// carry the player over a drop.
fn leanFromCurrents(frame: Frame, position: v.Vec3, direction: v.Vec3, direct: bool) !v.Vec3 {
    var bias: v.Vec3 = @splat(0);
    var outranked = false;
    const heading = v.normalize(.{ direction[0], direction[1], 0 });
    var controls = frame.world.queryAccess(data.World.mask(.{ data.WorldControl, data.Binding }), 0, 0);
    defer controls.deinit();
    while (controls.next()) |view| for (view.read(data.WorldControl), view.read(data.Binding)) |control, binding| {
        const push = @import("entity_classes/registry.zig").current(control.action) orelse continue;
        const flat: v.Vec3 = .{ push.velocity[0], push.velocity[1], 0 };
        if (!push.enabled or v.length(flat) < 1 or binding.slot >= frame.projections.len) continue;
        const box = frame.projections[binding.slot].shared;
        // Within a stride of the hull's edge, at the height the hull spans.
        const reach: f32 = frame.hull.maxs[0] + 24;
        if (position[0] < box.absmin[0] - reach or position[0] > box.absmax[0] + reach or position[1] < box.absmin[1] - reach or position[1] > box.absmax[1] + reach) continue;
        if (position[2] + frame.hull.maxs[2] < box.absmin[2] or position[2] + frame.hull.mins[2] > box.absmax[2]) continue;
        const along = v.normalize(flat);
        // Going with the current is the route's own errand: an authored
        // straight segment that rides a flow over a fall must keep its line.
        if (direct and v.dot(heading, along) > 0.5) continue;
        const centre = v.scale(v.add(box.absmin, box.absmax), 0.5);
        const beyond = v.add(.{ centre[0], centre[1], position[2] }, v.scale(along, 64));
        const floor = try frame.collision.trace(.{ .start = beyond, .end = v.add(beyond, .{ 0, 0, -96 }), .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = frame.motionMask() });
        if (floor.fraction < 1) continue;
        bias = v.subtract(bias, along);
        // A push that outranks a full stroke cannot be fought from inside: the
        // volume sets the velocity every frame it touches, so the stroke is
        // erased as fast as it is made (the fan at e1m2b's plank measured 200
        // against a walk of 320 at a crawl of 23). Such a current is stepped
        // around, not leaned against: give the way round it the whole weight.
        if (v.length(flat) >= run_speed) outranked = true;
    };
    if (v.length(bias) < 0.01) return direction;
    const ahead = heading;
    // Keep the way's own heading but never toward the current.
    const toward = v.dot(ahead, v.scale(bias, -1));
    var bent = if (toward > 0) v.subtract(ahead, v.scale(v.normalize(v.scale(bias, -1)), toward)) else ahead;
    bent = v.add(bent, v.scale(v.normalize(bias), if (outranked) @as(f32, 1) else 0.35));
    return v.scale(v.normalize(bent), v.length(.{ direction[0], direction[1], 0 }));
}
/// Bends a heading away from an enabled lethal hazard the hull runs within a
/// few units of, keeping the way's own progress.
/// `extent`: how far the heading goes before the route turns.
fn leanFromHazards(frame: Frame, position: v.Vec3, direction: v.Vec3, head: f32, extent: f32) !v.Vec3 {
    var bias: v.Vec3 = @splat(0);
    var hazards = frame.world.queryAccess(data.World.mask(.{ data.Hazard, data.Binding }), 0, 0);
    defer hazards.deinit();
    while (hazards.next()) |view| for (view.read(data.Hazard), view.read(data.Binding)) |hazard, binding| {
        if (!hazard.enabled or hazard.damage < 100 or hazard.damage < frame.hazard_damage or binding.slot >= frame.projections.len) continue;
        const box = frame.projections[binding.slot].shared;
        if (box.linked == 0) continue;
        if (position[2] + head < box.absmin[2] or position[2] + frame.hull.mins[2] > box.absmax[2]) continue;
        // Here, or a stride on (passing the volume's corner).
        const stride = v.add(position, v.scale(v.normalize(.{ direction[0], direction[1], 0 }), @min(extent, 32)));
        const at = if (clearance(frame, binding.slot, stride) < clearance(frame, binding.slot, position)) stride else position;
        if (clearance(frame, binding.slot, at) >= 12) continue;
        // Away from the nearest point of the volume.
        const nearest: v.Vec3 = .{ std.math.clamp(at[0], box.absmin[0], box.absmax[0]), std.math.clamp(at[1], box.absmin[1], box.absmax[1]), at[2] };
        const away: v.Vec3 = .{ at[0] - nearest[0], at[1] - nearest[1], 0 };
        if (v.length(away) < 0.01) continue;
        bias = v.add(bias, v.normalize(away));
    };
    if (v.length(bias) < 0.01) return direction;
    const ahead = v.normalize(.{ direction[0], direction[1], 0 });
    const outward = v.normalize(bias);
    // No component toward the volume; a small one away from it. Heading
    // straight in is left to the stride check (it stops short).
    const toward = v.dot(ahead, v.scale(outward, -1));
    if (toward > 0.8) return direction;
    var bent = if (toward > 0) v.add(ahead, v.scale(outward, toward)) else ahead;
    bent = v.add(bent, v.scale(outward, 0.4));
    if (!try evasion.supportedUnder(frame, position, v.add(position, v.scale(v.normalize(bent), 40)), head)) return direction;
    return v.scale(v.normalize(bent), v.length(.{ direction[0], direction[1], 0 }));
}
/// Whether lethal liquid lies straight below `at` with nothing solid between:
/// an open lip over a pool rather than a floor. A slim point drop, because it
/// asks what is under one spot, which is what an edge is made of.
fn edgeOfLethal(frame: Frame, at: v.Vec3) !bool {
    const down = try frame.collision.trace(.{ .start = at, .end = .{ at[0], at[1], at[2] - 320 }, .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = frame.motionMask() | frame.liquid_mask });
    if (down.start_solid or down.all_solid or down.fraction == 1) return false;
    return down.contents & frame.liquid_mask != 0;
}
/// Bends a heading away from a lethal-liquid edge that runs beside the player.
/// One side only: an edge with liquid on both sides is a beam the route meant
/// to cross, and no side is not an edge. The lean is small (a quarter) and
/// only taken where the bent stride still has floor all the way.
fn leanFromLiquidEdge(frame: Frame, position: v.Vec3, direction: v.Vec3, head: f32) !v.Vec3 {
    const ahead = v.normalize(.{ direction[0], direction[1], 0 });
    if (v.length(ahead) < 0.5) return direction;
    const side: v.Vec3 = .{ -ahead[1], ahead[0], 0 };
    const left = try edgeOfLethal(frame, v.add(position, v.scale(side, 44)));
    const right = try edgeOfLethal(frame, v.add(position, v.scale(side, -44)));
    if (left == right) return direction;
    const off = if (left) v.scale(side, -1) else side;
    const bent = v.normalize(v.add(ahead, v.scale(off, 0.4)));
    if (!try evasion.supportedUnder(frame, position, v.add(position, v.scale(bent, 48)), head)) return direction;
    return v.scale(bent, v.length(.{ direction[0], direction[1], 0 }));
}
/// Bodies and an open mover's remaining leaf can obstruct a precise corridor.
/// Closed or moving solids remain the authored control's responsibility.
fn detourAhead(frame: Frame, position: v.Vec3, movement: v.Vec3) !bool {
    const flat: v.Vec3 = .{ movement[0], movement[1], 0 };
    if (v.length(flat) < 0.01) return false;
    const ahead = try frame.collision.trace(.{ .start = position, .end = v.add(position, v.scale(v.normalize(flat), 40)), .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
    if (ahead.fraction == 1 or ahead.start_solid) return false;
    const blocker = occupant(frame, ahead) orelse return false;
    if (blocker.get(data.Mover) catch null) |mover| return mover.state == .open and !mover.moving();
    return (blocker.get(data.Actor) catch null) != null;
}
/// The furthest of the route's next few points the player can walk to in a
/// straight line (clear hull sweep, level, floor all the way), so the bot
/// cuts corners the area graph's entrance points would make it turn at. On
/// a ledge split lengthwise into two thin areas, each routes through the
/// other's entrance far behind; walking straight to the point beyond both
/// stops the bot turning back and forth between them.
fn lookAhead(frame: Frame, position: v.Vec3, goal: v.Vec3) !?v.Vec3 {
    const player = frame.state;
    if (player.ground_entity == c.ENTITYNUM_NONE or player.water_level >= 2) return null;
    var points: [6]v.Vec3 = undefined;
    const count = try frame.service.predict(.{ .position = position, .destination = goal, .slot = frame.slot, .player = true, .allow_slime_escape = true }, &points);
    var index = count;
    while (index > 0) {
        index -= 1;
        const point = points[index];
        if (nav.horizontalDistance(point, position) > 256 or nav.horizontalDistance(point, position) < 24 or @abs(point[2] - position[2]) > 20) continue;
        if (try walkable(frame, position, point)) return point;
    }
    return null;
}
/// A plain walk to the goal beats the route's next step: the goal is within a
/// stride of ground, reached by a supported straight line, while the step the
/// area graph offers is further from the goal than the traveller already is.
/// Only a plain step is ever passed over: a jump, crouch, ladder, lift or drop
/// is a step the body must stand on whatever the straight line looks like.
fn walksStraight(frame: Frame, position: v.Vec3, goal: v.Vec3, step: ?nav.Waypoint) !bool {
    const player = frame.state;
    if (player.ground_entity == c.ENTITYNUM_NONE or player.water_level >= 2) return false;
    const span = nav.horizontalDistance(position, goal);
    if (span < 8 or span > 256 or @abs(goal[2] - position[2]) > 24) return false;
    const chosen = step orelse return false;
    if (chosen.jump or chosen.crouch or chosen.ladder or chosen.elevator or chosen.drop) return false;
    if (nav.horizontalDistance(chosen.point, goal) <= span + 16) return false;
    return walkable(frame, position, goal);
}
fn motorRoute(frame: Frame, position: v.Vec3, goal: v.Vec3) !?v.Vec3 {
    var parameters = frame.motor orelse return null;
    if (frame.state.mode != .normal or nav.horizontalDistance(position, goal) > 256) return null;
    // Dynamic bodies cannot stand in for a floor. Existing per-stride actor
    // avoidance still handles them after route selection.
    parameters.mask &= ~@as(u32, c.CONTENTS_BODY);
    var volumes: [256]steering.Bounds = undefined;
    var count: usize = 0;
    {
        var hazards_found = frame.world.queryAccess(data.World.mask(.{ data.Hazard, data.Binding }), 0, 0);
        defer hazards_found.deinit();
        while (hazards_found.next()) |view| for (view.read(data.Hazard), view.read(data.Binding)) |hazard, binding| {
            if (!hazard.enabled or hazard.damage < frame.hazard_damage) continue;
            if (count == volumes.len) return null;
            const bounds = frame.projections[binding.slot].shared;
            volumes[count] = .{ .mins = bounds.absmin, .maxs = bounds.absmax };
            count += 1;
        };
    }
    if (frame.capabilities.exits) {
        var exits = frame.world.queryAccess(data.World.mask(.{ data.Exit, data.Body, data.Transform }), 0, 0);
        defer exits.deinit();
        while (exits.next()) |view| for (view.read(data.Body), view.read(data.Transform)) |body, pose| {
            const mins = v.add(pose.position, body.mins);
            const maxs = v.add(pose.position, body.maxs);
            if (route.overlaps(position, frame.hull.mins, frame.hull.maxs, mins, maxs)) continue;
            if (count == volumes.len) return null;
            volumes[count] = .{ .mins = mins, .maxs = maxs };
            count += 1;
        };
    }
    // A submerged route may stay in its existing ordinary water. Dry feet
    // still cannot use this shortcut to enter water, or any harmful liquid.
    const wet = try frame.collision.contents(v.add(position, .{ 0, 0, frame.hull.mins[2] + 1 }), frame.slot) & c.CONTENTS_WATER != 0;
    const forbidden = frame.liquid_mask | (if (wet) @as(u32, 0) else @as(u32, c.CONTENTS_WATER));
    const forecast = @import("../domain/motion_forecast.zig");
    const contacts = try evasion.persistent(frame, position);
    if (contacts.overflow) return null;
    var fields: [16]forecast.Field = undefined;
    for (contacts.slice(), fields[0..contacts.len]) |field, *sphere| sphere.* = .{ .point = field.point, .radius = field.radius, .bounds = field.bounds, .contact = field.contact };
    const result = try @import("../domain/motion_forecast.zig").walk(frame.state, .{ .position = position, .velocity = (try frame.world.get(frame.entity, data.Velocity)).linear }, goal, parameters, frame.collision, forbidden, volumes[0..count], fields[0..contacts.len]);
    if (engine.integer("developer") >= 3) {
        var text: [384]u8 = undefined;
        engine.print(try std.fmt.bufPrintZ(&text, "dk3 {s} walk: t={d} safe={d} reason={s} start={d:.2},{d:.2},{d:.2} goal={d:.2},{d:.2},{d:.2} end={d:.2},{d:.2},{d:.2} normal={d:.3}\n", .{ frame.label, frame.now, @intFromBool(result.safe), @tagName(result.reason), position[0], position[1], position[2], goal[0], goal[1], goal[2], result.position[0], result.position[1], result.position[2], result.normal }));
    }
    if (result.safe) return goal;
    if (result.reason != .field) return null;
    return forecast.route(frame.state, .{ .position = position, .velocity = (try frame.world.get(frame.entity, data.Velocity)).linear }, goal, parameters, frame.collision, forbidden, volumes[0..count], fields[0..contacts.len]);
}
/// A straight walk with no gap, drop, steep slope or new liquid along it:
/// the hull sweeps clear at stepping height and finds level floor every
/// 16 units, never more than a step below the line.
pub fn walkable(frame: Frame, from: v.Vec3, to: v.Vec3) !bool {
    // Try a level stride before a stair-height sweep. Raising every query
    // first incorrectly rejects a corridor whose actual standing hull fits.
    return evasion.supportedDrop(frame, from, to, frame.hull.maxs[2], 22);
}
/// Whether a shot from `eye` would meet water within an ion discharge's reach
/// (64 units) of the shooter at `origin`: the eye under water, or the line's
/// first water close by.
fn waterNear(frame: Frame, eye: v.Vec3, origin: v.Vec3, aim: ?v.Vec3) !bool {
    const collision = frame.collision;
    if (try collision.contents(eye, frame.slot) & c.MASK_WATER != 0) return true;
    const point = aim orelse return false;
    const direction = v.normalize(v.subtract(point, eye));
    const span = @min(v.length(v.subtract(point, eye)), 128);
    var along: f32 = 8;
    while (along <= span) : (along += 8) {
        const sample = v.add(eye, v.scale(direction, along));
        if (try collision.contents(sample, frame.slot) & c.MASK_WATER != 0) return v.length(v.subtract(sample, origin)) < 64;
    }
    return false;
}
/// Whether a submerged player rising straight up would get its head out of
/// the water within a short climb.
/// Air for a player-like swimmer, the time it budgets for the margin, and the rising speed it
/// assumes (half its run speed is the swim stroke; this stays under it).
const air_ms: i64 = 12000;
const surfacing_margin_ms: i64 = 1500;
const surfacing_speed: f32 = 120;
/// How far a swimmer covers in a second of stroke (used to ask whether the air
/// left reaches the next pocket, and so whether to keep going or turn back).
const air_swim_speed: f32 = 150;
/// How far the body must rise to have its head out of the water, when air lies straight above
/// within 1024 units and short of a ceiling; null when there is none.
fn airDistance(frame: Frame, position: v.Vec3, view: f32) !?f32 {
    const collision = frame.collision;
    const rise = try collision.trace(.{ .start = position, .end = v.add(position, .{ 0, 0, 1024 }), .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
    if (rise.start_solid) return null;
    if (try collision.contents(v.add(rise.end, .{ 0, 0, view }), frame.slot) & (c.MASK_WATER | c.CONTENTS_SOLID) != 0) return null;
    var low: f32 = 0;
    var high: f32 = rise.end[2] - position[2];
    for (0..8) |_| {
        const middle = (low + high) * 0.5;
        if (try collision.contents(v.add(position, .{ 0, 0, middle + view }), frame.slot) & c.MASK_WATER != 0) low = middle else high = middle;
    }
    return high;
}
const lethal_liquids: u32 = c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO;
/// Class-owned finite protection changes which liquid the body can endure.
pub fn liquidMask(world: *data.World, entity: ecs.Entity, episode: u8) u32 {
    const character = world.get(entity, data.Character) catch return lethal_liquids;
    inline for (@import("../../game/domain/item_protections.zig").classes) |Class| if (@hasDecl(Class.State, "protectsToxins")) {
        if (@field(character.item_protection, Class.state_field).protectsToxins(episode)) return lethal_liquids & ~@as(u32, c.CONTENTS_SLIME);
    };
    return lethal_liquids;
}
/// Slick floor (ice) straight under the hull.
fn slickUnder(frame: Frame, position: v.Vec3) !bool {
    const floor = try frame.collision.trace(.{ .start = position, .end = v.add(position, .{ 0, 0, -4 }), .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
    return floor.fraction < 1 and floor.slick;
}
/// The speed the motor steers a walker to at a full stroke (the base run
/// speed; a slower pace scales it down where the command is scaled).
const run_speed: f32 = 320;
/// The speed a walker actually reaches with this stroke: the base run speed
/// scaled by how far the command is pushed, less what the liquid it stands in
/// takes back. `Frame.walk` cuts a wading step by a sixth per level of water
/// (`speed * (1 - water_level/6)`), and a current is fought with what the legs
/// truly deliver, not with the speed the same boots reach on dry ground: aim
/// upstream by the dry-ground figure and the body is short of the compensation
/// every frame, and walks sideways into whatever the flow runs at.
fn groundSpeed(player: data.Player, magnitude: f32) f32 {
    const wade: f32 = if (player.water_level >= 2) 2.0 / 3.0 else if (player.water_level == 1) 5.0 / 6.0 else 1;
    return @min(run_speed, run_speed * magnitude / 127) * wade;
}
/// The shove the currents have on the hull where it stands, as the motor
/// counts it: a flowing brush underfoot carries a walker at its conveyor
/// speed, a liquid the feet stand in at half the swim speed. Only the
/// walking case: a swimmer's stroke is a different fight (see `swim`).
fn currentUnder(frame: Frame, position: v.Vec3) !v.Vec3 {
    const authored = @import("../player_state.zig").currents;
    const move = @import("../domain/player_move.zig");
    var push: v.Vec3 = @splat(0);
    const feet = v.add(position, .{ 0, 0, frame.hull.mins[2] + 1 });
    const here = try frame.collision.contents(feet, frame.slot);
    if (here & c.MASK_WATER != 0 and here & authored.mask() != 0) push = v.add(push, v.scale(authored.direction(here), move.water_current_speed / 2));
    const floor = try frame.collision.trace(.{ .start = position, .end = v.add(position, .{ 0, 0, -4 }), .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
    if (floor.fraction < 1 and floor.contents & authored.mask() != 0) push = v.add(push, v.scale(authored.direction(floor.contents), move.conveyor_speed));
    push[2] = 0;
    return push;
}
/// The heading to aim so the track keeps `direction`: the flow takes its
/// sideways part out of the walk, the rest of the stroke still points the
/// way. Where the flow is stronger than the walk, aim as far upstream as the
/// walk reaches (the track then still claws along the wanted line).
fn aimAgainstCurrent(frame: Frame, position: v.Vec3, direction: v.Vec3, push: v.Vec3, speed: f32) v.Vec3 {
    const wanted = v.normalize(.{ direction[0], direction[1], 0 });
    var sideways = v.subtract(push, v.scale(wanted, v.dot(push, wanted)));
    sideways[2] = 0;
    const reach = @min(v.length(sideways), speed * 0.92);
    if (v.length(sideways) > 0.01) sideways = v.scale(v.normalize(sideways), reach);
    const along = @sqrt(@max(0, speed * speed - reach * reach));
    const aimed = v.scale(v.subtract(v.scale(wanted, along), sideways), 1 / speed);
    if (engine.integer("developer") >= 3) {
        var text: [200]u8 = undefined;
        engine.print(std.fmt.bufPrintZ(&text, "dk3 {s} current: t={d} pos={d:.0},{d:.0},{d:.0} flow={d:.0},{d:.0} walk={d:.0} track={d:.2},{d:.2} aim={d:.2},{d:.2}\n", .{ frame.label, frame.now, position[0], position[1], position[2], push[0], push[1], speed, wanted[0], wanted[1], aimed[0], aimed[1] }) catch "");
    }
    return v.scale(aimed, v.length(.{ direction[0], direction[1], 0 }));
}
/// How far ahead a body moving this fast still travels once it lets go,
/// with a stride's margin: ground friction stops a runner within about
/// 45 units; on slick floor only the opposing stroke (about 320 u/s²) does.
fn stoppingReach(speed: f32, slick: bool) f32 {
    const travel = if (slick) speed * speed / 640 else speed / 7;
    return std.math.clamp(16 + travel, 24, 256);
}
/// Whether lethal liquid lies under the way within `reach` along the
/// horizontal `heading`, before any floor (up to 256 units down). The way
/// ends at a wall: what lies beyond it is not underfoot.
fn lethalAlong(frame: Frame, position: v.Vec3, heading: v.Vec3, reach: f32) !bool {
    const flat = v.normalize(.{ heading[0], heading[1], 0 });
    if (v.length(flat) < 0.5) return false;
    const open = try frame.collision.trace(.{ .start = position, .end = v.add(position, v.scale(flat, reach)), .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = frame.motionMask() });
    const limit = if (open.start_solid) 24 else @max(@as(f32, 24), reach * open.fraction);
    var along: f32 = 24;
    while (true) : (along += 24) {
        const ahead = v.add(position, v.scale(flat, @min(along, limit)));
        // Footing is what the body's hull stands on, not what a slim column
        // happens to touch: a catwalk's lip over the nitrogen carries the hull
        // while a narrow probe down its middle finds only the gas beneath, and
        // a routed step along such a lip then refuses itself for ever (e1m6c's
        // ring). Where the body cannot even stand, the slim probe still answers.
        var below = try frame.collision.trace(.{ .start = ahead, .end = v.add(ahead, .{ 0, 0, -256 }), .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() | frame.liquid_mask });
        if (below.start_solid or below.all_solid) below = try frame.collision.trace(.{ .start = ahead, .end = v.add(ahead, .{ 0, 0, -256 }), .mins = .{ -4, -4, 0 }, .maxs = .{ 4, 4, 0 }, .slot = frame.slot, .mask = frame.motionMask() | frame.liquid_mask });
        if (below.fraction < 1 and below.contents & frame.liquid_mask != 0) return true;
        if (along >= limit) return false;
    }
}
/// Whether a hop taken now comes down in lethal liquid: a jump stays about
/// two thirds of a second in the air, carried by the speed it has.
fn hopLandsLethal(frame: Frame, position: v.Vec3, velocity: v.Vec3, direction: v.Vec3) !bool {
    const speed = nav.horizontalDistance(velocity, @splat(0));
    const heading = if (speed > 60) velocity else direction;
    if (nav.horizontalDistance(heading, @splat(0)) < 0.01) return false;
    return lethalAlong(frame, position, heading, @max(speed, 160) * 0.7 + 24);
}
/// The nearest floor out of lava, slime, nitrogen and water around a body
/// standing in one, that it reaches by rising and then moving straight
/// across: rings out to 576 units (a wide pool's rim).
fn safeFloorNear(frame: Frame, position: v.Vec3) !?v.Vec3 {
    const hull = frame.hull;
    const feet = hull.mins[2] + 1;
    const parameters = frame.motor;
    const jump = @max(if (parameters) |motor| motor.jump_speed else @as(f32, 270), if (frame.state.water_level >= 2) @import("../domain/player_move.zig").water_jump_speed else @as(f32, 0));
    const gravity = if (parameters) |motor| motor.gravity else @as(f32, 800);
    const max_rise = @max(64, if (gravity > 0) jump * jump / (2 * gravity) + 18 else 64);
    for ([_]f32{ 40, 72, 112, 160, 208, 256, 336, 448, 576 }) |radius| {
        var best: ?v.Vec3 = null;
        var best_rise: f32 = 0;
        for (0..12) |step| {
            const angle = @as(f32, @floatFromInt(step)) * std.math.pi / 6;
            const column = v.add(position, .{ @cos(angle) * radius, @sin(angle) * radius, @max(64, max_rise + 0.25) });
            const floor = try frame.collision.trace(.{ .start = column, .end = v.add(column, .{ 0, 0, -192 }), .mins = hull.mins, .maxs = hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
            if (floor.start_solid or floor.all_solid or floor.fraction == 1 or floor.normal[2] < 0.7) continue;
            if (try frame.collision.contents(v.add(floor.end, .{ 0, 0, feet }), frame.slot) & (frame.liquid_mask | c.MASK_WATER) != 0) continue;
            // Up to the floor's height (and a step), then across to it.
            const height = @max(position[2], floor.end[2]) + 18;
            const rise = try frame.collision.trace(.{ .start = position, .end = .{ position[0], position[1], height }, .mins = hull.mins, .maxs = hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
            if (rise.start_solid or rise.fraction < 1) continue;
            const across = try frame.collision.trace(.{ .start = rise.end, .end = .{ floor.end[0], floor.end[1], height }, .mins = hull.mins, .maxs = hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
            if (across.fraction < 1) continue;
            const climb = floor.end[2] - position[2];
            if (climb > max_rise) continue;
            if (best == null or climb < best_rise) {
                best = floor.end;
                best_rise = climb;
            }
        }
        if (best) |point| return point;
    }
    return null;
}
/// The nearest point at the same depth, reachable in a straight stroke, with air straight above.
fn nearestAir(frame: Frame, position: v.Vec3, view: f32, ahead: ?v.Vec3) !?v.Vec3 {
    // A submerged route reaches its air at the far end of the run it is
    // already making, and a passage bends: the eight fixed rays miss the
    // opening whenever its leg turns. Sweep a fan about the way the body is
    // going first (e1m2b's tank: the only air gap of the flooded lower level
    // lies east along a corridor that stands on none of the rays, and with no
    // air found the bot turned for the surface it had left twelve seconds
    // earlier and lost a leg with two hundred and twenty units to go).
    var heading: ?f32 = null;
    if (ahead) |point| {
        const toward = v.subtract(point, position);
        const across = nav.horizontalDistance(toward, @splat(0));
        if (across > 1) heading = std.math.atan2(toward[1], toward[0]);
    }
    if (heading) |facing| for ([_]f32{ 64, 128, 256, 384, 512, 768, 1024 }) |radius| {
        for ([_]f32{ 0, -25, 25, -50, 50, -75, 75 }) |off| {
            const angle = facing + off * std.math.pi / 180;
            const point = v.add(position, .{ @cos(angle) * radius, @sin(angle) * radius, 0 });
            const stroke = try frame.collision.trace(.{ .start = position, .end = point, .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
            if (stroke.start_solid or stroke.fraction < 1) continue;
            if (try airDistance(frame, point, view) != null) return point;
        }
    };
    for ([_]f32{ 64, 128, 256, 384, 512 }) |radius| {
        for (0..8) |step| {
            const angle = @as(f32, @floatFromInt(step)) * std.math.pi / 4;
            const point = v.add(position, .{ @cos(angle) * radius, @sin(angle) * radius, 0 });
            const stroke = try frame.collision.trace(.{ .start = position, .end = point, .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
            if (stroke.start_solid or stroke.fraction < 1) continue;
            if (try airDistance(frame, point, view) != null) return point;
        }
    }
    return null;
}
/// Halfway up a ladder with nothing under the feet. A body that stops on the
/// rungs to take on a fight slides off them and must start the climb again, so
/// a climb already begun is finished before anything else is taken on.
pub fn onRungs(frame: Frame, position: v.Vec3) !bool {
    if (frame.state.ground_entity != c.ENTITYNUM_NONE) return false;
    return (try climbable(frame, position)) != null;
}
/// Outward normal of a ladder surface touching the player hull, if any (the
/// same four-way probe the movement code uses to start climbing).
fn climbable(frame: Frame, position: v.Vec3) !?v.Vec3 {
    return climbableWithin(frame, position, @import("../domain/player_move.zig").ladder_contact_distance);
}
fn climbableWithin(frame: Frame, position: v.Vec3, distance: f32) !?v.Vec3 {
    for (0..4) |axis| {
        var direction: v.Vec3 = @splat(0);
        direction[axis / 2] = if (axis & 1 == 0) 1 else -1;
        const hit = try frame.collision.trace(.{ .start = position, .end = v.add(position, v.scale(direction, distance)), .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
        if (hit.fraction < 1 and hit.ladder and @abs(hit.normal[2]) < 0.5) return hit.normal;
    }
    return null;
}
/// `goal`, or when the area graph has no route there but the last stretch
/// can be walked straight (within `direct_radius`), the nearest point within
/// 96 units of it that the graph does reach.
fn reachableNearImpl(self: *Pilot, frame: Frame, position: v.Vec3, goal: v.Vec3, direct_radius: f32) !v.Vec3 {
    if (direct_radius < 96) return goal;
    // There already: the last stretch is walked straight (routing to the goal
    // fails, and the caller steers at it directly).
    if (v.length(v.subtract(goal, self.near_goal)) < 1) if (self.near_point) |point| if (nav.horizontalDistance(position, point) < 32) return goal;
    if (v.length(v.subtract(goal, self.near_goal)) < 1 and frame.now - self.near_ms < 3000) return self.near_point orelse goal;
    self.near_goal = goal;
    self.near_ms = frame.now;
    self.near_point = null;
    if (try frame.service.next(.{ .position = position, .destination = goal, .slot = frame.slot, .player = true }) != null) return goal;
    // Nearest the goal first, and only where the last stretch to it is a
    // supported straight walk (not the far side of a wall).
    const hull = (try frame.world.get(frame.entity, data.Body)).*;
    const diagnostic = engine.integer("developer") >= 3;
    var probed: usize = 0;
    for ([_]f32{ 32, 64, 96 }) |radius| {
        var best: ?v.Vec3 = null;
        var shortest: f32 = std.math.inf(f32);
        for (0..8) |heading| {
            const angle = @as(f32, @floatFromInt(heading)) * std.math.pi / 4;
            const candidate = v.add(goal, .{ @cos(angle) * radius, @sin(angle) * radius, 0 });
            if (diagnostic) probed += 1;
            if (try frame.service.next(.{ .position = position, .destination = candidate, .slot = frame.slot, .player = true }) == null) continue;
            // Raised a little: goal points sit on the floor plane.
            // The goal itself may be pressed against a console (a touch
            // volume's middle): the walk need only end a hull short of it.
            const lift: v.Vec3 = .{ 0, 0, 8 };
            const short = v.add(goal, v.scale(v.normalize(.{ candidate[0] - goal[0], candidate[1] - goal[1], 0 }), 16));
            if (try steering.walkPath(frame.collision, .{ .start = v.add(candidate, lift), .end = v.add(short, lift), .mins = hull.mins, .maxs = hull.maxs, .slot = frame.slot, .mask = frame.motionMask() }, frame.liquid_mask, &.{}) == null) continue;
            const span = v.length(v.subtract(candidate, position));
            if (span >= shortest) continue;
            shortest = span;
            best = candidate;
        }
        if (diagnostic) {
            var text: [224]u8 = undefined;
            engine.print(std.fmt.bufPrintZ(&text, "dk3 {s}: t={d} event=near radius={d:.0} probed={d} best={d:.0},{d:.0},{d:.0}\n", .{ frame.label, frame.now, radius, probed, if (best) |point| point[0] else 0, if (best) |point| point[1] else 0, if (best) |point| point[2] else 0 }) catch "");
        }
        if (best) |point| {
            self.near_point = point;
            return point;
        }
    }
    return goal;
}
/// Persistent id of a volume the next stride must not enter: a campaign exit
/// other than the targeted one, or an enabled hazard harmful enough to kill
/// (laser barriers and crushers are authored as hurt triggers).
/// `extent`: how far the stride goes before turning (the route's next corner):
/// a hazard past the corner is not walked into.
fn forbiddenExit(world: *data.World, position: v.Vec3, ahead: [3]v.Vec3, hull: Hull, allowed: u32) !u32 {
    // Resident travel can unlink the old engine trigger while its authored
    // seam remains active. Fence the physical exit volume independently of
    // its current engine projection.
    var exits = world.queryAccess(data.World.mask(.{ data.Exit, data.Body, data.Transform }), 0, 0);
    defer exits.deinit();
    while (exits.next()) |view| {
        for (view.entities(), view.read(data.Body), view.read(data.Transform)) |entity, body, pose| {
            const id = try world.persistentId(entity);
            if (id == allowed) continue;
            for (ahead) |point| {
                const mins = v.add(pose.position, body.mins);
                const maxs = v.add(pose.position, body.maxs);
                if (route.overlaps(point, hull.mins, hull.maxs, mins, maxs) and
                    !route.overlaps(position, hull.mins, hull.maxs, mins, maxs)) return id;
            }
        }
    }
    return 0;
}
test "unlinked resident exits fence only unauthorised entry" {
    var world = data.World.init(std.testing.allocator, 4);
    defer world.deinit();
    _ = try world.create(27, .{ data.Exit{}, data.Transform{ .position = .{ 48, 0, 0 } }, data.Body{ .mins = .{ -4, -40, -40 }, .maxs = .{ 4, 40, 40 } } });
    const ahead = [_]v.Vec3{ .{ 40, 0, 0 }, .{ 80, 0, 0 }, .{ 120, 0, 0 } };
    try std.testing.expectEqual(@as(u32, 27), try forbiddenExit(&world, @splat(0), ahead, .{}, 0));
    try std.testing.expectEqual(@as(u32, 0), try forbiddenExit(&world, @splat(0), ahead, .{}, 27));
    try std.testing.expectEqual(@as(u32, 0), try forbiddenExit(&world, .{ 48, 0, 0 }, ahead, .{}, 0));
}
fn avoidExits(frame: Frame, position: v.Vec3, movement: v.Vec3, allowed: u32, head: f32, wary: bool, extent: f32) !u32 {
    const direction = v.normalize(.{ movement[0], movement[1], 0 });
    const stride = v.add(position, v.scale(direction, @min(40, @max(0, extent))));
    const speed = nav.horizontalDistance((try frame.world.get(frame.entity, data.Velocity)).linear, @splat(0));
    const reach = @max(@as(f32, 40), speed * 0.3 + 24);
    if (frame.capabilities.exits) {
        var ahead: [3]v.Vec3 = undefined;
        for (&ahead, [_]f32{ 0.34, 0.67, 1 }) |*point, part| point.* = v.add(position, v.scale(direction, reach * part));
        var hull = frame.hull;
        hull.maxs[2] = head;
        const forbidden = try forbiddenExit(frame.world, position, ahead, hull, allowed);
        if (forbidden != 0) return forbidden;
    }
    // Harmful liquids are authored as brush contents, not entities: never step
    // from dry ground into slime, lava or nitro.
    const harmful = frame.liquid_mask;
    const collision = frame.collision;
    const feet = frame.hull.mins[2] + 1;
    if (try collision.contents(v.add(position, .{ 0, 0, feet }), frame.slot) & harmful == 0) {
        const floor = try collision.trace(.{ .start = stride, .end = v.add(stride, .{ 0, 0, -64 }), .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() });
        if (try collision.contents(v.add(floor.end, .{ 0, 0, feet }), frame.slot) & harmful != 0) return std.math.maxInt(u32);
    }
    const step = v.add(position, v.scale(v.normalize(.{ movement[0], movement[1], 0 }), std.math.clamp(extent, 16, 40)));
    var hazards = frame.world.queryAccess(data.World.mask(.{ data.Hazard, data.Binding }), 0, 0);
    defer hazards.deinit();
    while (hazards.next()) |view| for (view.entities(), view.read(data.Hazard), view.read(data.Binding)) |entity, hazard, binding| {
        // Lethal brushes (laser barriers, crushers) keep a margin across
        // against knockback.
        const margin: f32 = if (hazard.damage >= 100) (if (wary) frame.lethal_margin else @min(frame.lethal_margin, 8)) else 0;
        if (hazard.enabled and hazard.damage >= frame.hazard_damage and closesOn(frame, binding.slot, position, step, margin, head)) return try frame.world.persistentId(entity);
    };
    return 0;
}
fn lowAmmoReserve(loadout: data.Weapons, table: *const @import("../domain/weapons.zig").Table, weapon: u5) bool {
    return combat.reserveLow(loadout, table, weapon);
}
/// Actor-owned admission is authoritative for bots as well as actual impacts.
pub fn damageExclusions(target: Ref, now: i64) i32 {
    const actor = target.get(data.Actor) catch return 0;
    var excluded: i32 = 0;
    for (@import("weapon_catalog").entries) |entry| {
        if (!@import("actor_classes/registry.zig").admitDamage(catalog.entries[actor.definition].kind, actor, .{ .weapon = entry.id, .now = now })) excluded |= @as(i32, 1) << entry.id;
    }
    return excluded;
}
/// The owned melee weapon with the most damage, if any.
fn melee(loadout: data.Weapons, frame: Frame, excluded: i32) ?u5 {
    var best: ?u5 = null;
    var damage: f32 = 0;
    for (@import("weapon_catalog").entries) |entry| {
        if (loadout.dk3Inventory & (@as(i32, 1) << entry.id) == 0 or !entry.spec.auto_select or excluded & (@as(i32, 1) << entry.id) != 0) continue;
        if (weaponReach(frame, entry.id) >= 160) continue;
        const tuning = frame.table.entries[entry.id];
        if (tuning.damage <= damage or (loadout.ammo[entry.id] < tuning.ammoCost and entry.spec.bot_contact_melee_range == null)) continue;
        damage = tuning.damage;
        best = entry.id;
    }
    return best;
}
fn weaponReach(frame: Frame, weapon: u5) f32 {
    const loadout = frame.world.get(frame.entity, data.Weapons) catch return 0;
    return combat.reachFor(loadout.*, frame.table, weapon);
}
fn blocked(frame: Frame, position: v.Vec3, step: v.Vec3) anyerror!bool {
    return try avoidExits(frame, position, step, 0, frame.hull.maxs[2], true, 40) != 0;
}
/// Whether a body standing at `point` would be inside an enabled hazard
/// volume harmful enough for this frame to avoid.
pub fn insideHazard(frame: Frame, point: v.Vec3) !bool {
    var hazards = frame.world.queryAccess(data.World.mask(.{ data.Hazard, data.Binding }), 0, 0);
    defer hazards.deinit();
    while (hazards.next()) |view| for (view.read(data.Hazard), view.read(data.Binding)) |hazard, binding| {
        if (!hazard.enabled or hazard.damage < frame.hazard_damage or binding.slot >= frame.projections.len) continue;
        const box = frame.projections[binding.slot].shared;
        if (box.linked == 0) continue;
        const margin: v.Vec3 = if (hazard.damage >= 100) .{ 48, 48, 0 } else @splat(0);
        if (route.overlaps(point, frame.hull.mins, frame.hull.maxs, v.subtract(box.absmin, margin), v.add(box.absmax, margin))) return true;
    };
    return false;
}
/// A step into a hazard volume, or within `margin` of it while getting
/// closer: walking alongside a laser at a safe distance is no approach.
fn closesOn(frame: Frame, slot: u16, position: v.Vec3, stride: v.Vec3, margin: f32, head: f32) bool {
    if (enteringWithin(frame, slot, position, stride, 0, head)) return true;
    if (margin == 0 or !enteringWithin(frame, slot, position, stride, margin, head)) return false;
    return clearance(frame, slot, stride) < clearance(frame, slot, position) - 1;
}
/// Horizontal clearance between the body's hull at `position` and a volume.
fn clearance(frame: Frame, slot: u16, position: v.Vec3) f32 {
    const box = frame.projections[slot].shared;
    var squared: f32 = 0;
    for (0..2) |axis| {
        const low = position[axis] + frame.hull.mins[axis];
        const high = position[axis] + frame.hull.maxs[axis];
        const outside = @max(box.absmin[axis] - high, low - box.absmax[axis], 0);
        squared += outside * outside;
    }
    return @sqrt(squared);
}
fn enteringWithin(frame: Frame, slot: u16, position: v.Vec3, stride: v.Vec3, margin: f32, head: f32) bool {
    if (slot >= frame.projections.len) return false;
    const box = frame.projections[slot].shared;
    if (box.linked == 0) return false;
    const pad: v.Vec3 = .{ margin, margin, 0 };
    const mins = v.subtract(box.absmin, pad);
    const maxs = v.add(box.absmax, pad);
    const hull_mins = frame.hull.mins;
    const hull_maxs: v.Vec3 = .{ frame.hull.maxs[0], frame.hull.maxs[1], head };
    return route.overlaps(stride, hull_mins, hull_maxs, mins, maxs) and
        !route.overlaps(position, hull_mins, hull_maxs, mins, maxs);
}

const testing = std.testing;
/// Floor at z = 0 for x < 100; beyond, a lava pool (surface z = 0) over a
/// floor at z = -64. Every horizontal way is open.
const Pool = struct {
    fn trace(_: *anyopaque, request: collision_module.Request) anyerror!collision_module.Trace {
        const down = request.end[2] < request.start[2] - 1 and @abs(request.end[0] - request.start[0]) < 0.5 and @abs(request.end[1] - request.start[1]) < 0.5;
        if (!down) return .{ .fraction = 1, .end = request.end, .normal = .{ 0, 0, 1 } };
        const liquid = request.start[0] >= 100;
        const surface: f32 = if (liquid and request.mask & c.CONTENTS_LAVA == 0) -64 else 0;
        const rest = surface - request.mins[2];
        if (request.start[2] < rest or request.end[2] > rest) return .{ .fraction = 1, .end = request.end, .normal = .{ 0, 0, 1 } };
        const fraction = (request.start[2] - rest) / (request.start[2] - request.end[2]);
        return .{ .fraction = fraction, .end = .{ request.start[0], request.start[1], rest }, .normal = .{ 0, 0, 1 }, .contents = if (liquid and surface == 0) c.CONTENTS_LAVA else c.CONTENTS_SOLID };
    }
    fn contents(_: *anyopaque, point: v.Vec3, _: u16) anyerror!u32 {
        return if (point[0] >= 100 and point[2] < 0) c.CONTENTS_LAVA else 0;
    }
};
fn poolFrame(world: *data.World, slots: *Slots) Frame {
    const static = struct {
        var pool: u8 = 0;
    };
    return .{ .world = world, .slots = slots, .projections = &.{}, .service = undefined, .collision = .{ .context = &static.pool, .trace_fn = Pool.trace, .contents_fn = Pool.contents }, .table = undefined, .slot = 0, .entity = undefined, .state = .{}, .now = 0 };
}
test "a lethally frozen player requests recovery without moving or skipping a living cinematic" {
    var world = data.World.init(testing.allocator, 1);
    defer world.deinit();
    const entity = try world.create(null, .{ data.Transform{}, data.Weapons{}, data.Health{ .current = -99809 } });
    var slots: Slots = .{};
    var frame = poolFrame(&world, &slots);
    frame.entity = entity;
    frame.state.mode = .frozen;
    frame.state.ground_entity = c.ENTITYNUM_NONE;
    frame.now = 5000;
    var pilot: Pilot = .{};
    const dead = try pilot.steer(frame, .{ .attack_when_dead = true });
    try testing.expect(dead.command.attack);
    try testing.expectEqual(@as(i8, 0), dead.command.forward);
    try testing.expectEqual(@as(i8, 0), dead.command.right);
    try testing.expectEqual(@as(i8, 0), dead.command.up);
    (try world.get(entity, data.Health)).current = 100;
    const alive = try pilot.steer(frame, .{ .attack_when_dead = true });
    try testing.expect(!alive.command.attack);
}
test "aimed object blasts require clearance from the shooter, walls and party" {
    const Fixture = struct {
        blocked: bool = false,
        solid: bool = false,
        fn trace(context: *anyopaque, request: collision_module.Request) !collision_module.Trace {
            const self: *@This() = @ptrCast(@alignCast(context));
            return .{
                .fraction = if (self.blocked) 0.25 else 1,
                .end = if (self.blocked) v.add(request.start, v.scale(v.subtract(request.end, request.start), 0.25)) else request.end,
                .normal = @splat(0),
                .start_solid = self.solid,
            };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var world = data.World.init(testing.allocator, 2);
    defer world.deinit();
    const shooter = try world.create(null, .{data.Body{}});
    const ally = try world.create(null, .{ data.Player{}, data.Health{}, data.Transform{ .position = .{ 1024, 0, 24 } } });
    var slots: Slots = .{};
    var table: weapons.Table = .{};
    var fixture: Fixture = .{};
    var frame = poolFrame(&world, &slots);
    frame.entity = shooter;
    frame.table = &table;
    frame.collision = .{ .context = &fixture, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents };
    const gun = @import("weapon_catalog").classes.sidewinder.id;
    const eye: v.Vec3 = .{ 0, 0, 24 };
    const distant: v.Vec3 = .{ 1024, 0, 24 };
    try testing.expect(try objectBlastSafe(frame, eye, @splat(0), gun, 128, distant));
    try testing.expect(!try objectBlastSafe(frame, eye, @splat(0), gun, 128, .{ 32, 0, 24 }));
    fixture.blocked = true;
    try testing.expect(!try objectBlastSafe(frame, eye, @splat(0), gun, 128, distant));
    fixture.blocked = false;
    fixture.solid = true;
    try testing.expect(!try objectBlastSafe(frame, eye, @splat(0), gun, 128, distant));
    fixture.solid = false;
    slots.occupants[1] = ally;
    try testing.expect(!try objectBlastSafe(frame, eye, @splat(0), gun, 128, distant));
}
test "a hovering obstruction is passed crouched before a lateral detour is chosen" {
    const Fixture = struct {
        no_headroom: bool = false,
        fn trace(raw: *anyopaque, request: collision_module.Request) !collision_module.Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (request.mask & c.CONTENTS_BODY != 0 and request.end[0] >= 35 and request.end[0] > request.start[0] and
                (self.no_headroom or request.maxs[2] > 4))
                return .{ .fraction = 0.5, .end = request.start, .normal = .{ -1, 0, 0 }, .entity = 64 };
            if (request.end[2] < request.start[2]) {
                const floor = -request.mins[2];
                if (request.start[2] >= floor and request.end[2] <= floor)
                    return .{ .fraction = 0, .end = .{ request.start[0], request.start[1], floor }, .normal = .{ 0, 0, 1 } };
            }
            return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var world = data.World.init(testing.allocator, 2);
    defer world.deinit();
    const body = try world.create(null, .{data.Body{ .collision_mask = c.MASK_PLAYERSOLID }});
    const obstacle = try world.create(null, .{data.Actor{ .definition = 0 }});
    var slots: Slots = .{};
    try testing.expectEqual(@as(u16, 64), try slots.acquire(obstacle, null));
    var fixture: Fixture = .{};
    var frame = poolFrame(&world, &slots);
    frame.entity = body;
    frame.collision = .{ .context = &fixture, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents };
    frame.state.ground_entity = 2046;
    var pilot: Pilot = .{ .jump_until = 1000, .unstick_until = 1000 };
    var report: Report = .{};
    var duck = false;
    try testing.expectEqual(@as(?v.Vec3, null), try pilot.sidestep(frame, .{ 0, 0, 24 }, .{ 120, 0, 0 }, &report, &duck));
    try testing.expect(duck);
    try testing.expectEqual(@as(i64, 0), pilot.jump_until);
    try testing.expectEqual(@as(i64, 0), pilot.unstick_until);
    fixture.no_headroom = true;
    duck = false;
    try testing.expect((try pilot.sidestep(frame, .{ 0, 0, 24 }, .{ 120, 0, 0 }, &report, &duck)) != null);
    try testing.expect(!duck);
}

test "careful footing looks as far ahead as the body slides, further on ice" {
    try testing.expectEqual(@as(f32, 24), stoppingReach(0, false));
    try testing.expect(stoppingReach(320, false) > 55 and stoppingReach(320, false) < 70);
    try testing.expect(stoppingReach(320, true) > 170);
    try testing.expect(stoppingReach(2000, true) <= 256);
}
test "lethal liquid ahead is seen within the reach and only there" {
    var world = data.World.init(testing.allocator, 1);
    defer world.deinit();
    var slots: Slots = .{};
    const frame = poolFrame(&world, &slots);
    const at: v.Vec3 = .{ 40, 0, 24 };
    try testing.expect(!try lethalAlong(frame, at, .{ 1, 0, 0 }, 24));
    try testing.expect(try lethalAlong(frame, at, .{ 1, 0, 0 }, 80));
    try testing.expect(!try lethalAlong(frame, at, .{ -1, 0, 0 }, 200));
    // A run at the pool's edge would take a hop into it; a hop from rest away from it would not.
    try testing.expect(try hopLandsLethal(frame, at, .{ 300, 0, 0 }, .{ 1, 0, 0 }));
    try testing.expect(!try hopLandsLethal(frame, at, @splat(0), .{ -1, 0, 0 }));
}
test "a body in lava heads for the nearest dry floor" {
    var world = data.World.init(testing.allocator, 1);
    defer world.deinit();
    var slots: Slots = .{};
    const frame = poolFrame(&world, &slots);
    const out = (try safeFloorNear(frame, .{ 150, 0, -40 })).?;
    try testing.expect(out[0] < 100);
    try testing.expectApproxEqAbs(@as(f32, 24), out[2], 0.01);
    try testing.expect(out[0] > 60);
}
