// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Reviewed Gold animation, audio and muzzle bindings for every native weapon.
//! Common value types used inside concrete weapon definitions.

pub const Animation = struct {
    view_model: [:0]const u8 = "",
    ready: [:0]const u8 = "",
    away: [:0]const u8 = "",
    fire: [:0]const u8 = "",
    fire_variants: [4]?[:0]const u8 = @splat(null),
    reload: ?[:0]const u8 = null,
    /// Gold ANIM_AMBIENT_STD..: one is drawn at random and played once while
    /// the holder stands still, every 2-8 s; the last frame holds in between.
    idle: [3]?[:0]const u8 = .{ null, null, null },
    /// Gold WFL_LOOPAMBIENT_ANIM: the first idle loops instead, even in motion.
    idle_loop: bool = false,
    /// Percent of still loop cycles that play one of the idle sounds.
    idle_loop_sound_percent: u8 = 0,
    /// Gold discusCommand: no idle while the weapon itself is out of ammunition.
    idle_needs_ammo: bool = false,
    alternate: ?[:0]const u8 = null,
    rate: u8 = 20,
    raise_ms: u16 = 0,
    drop_ms: u16 = 0,
    hold_fire: bool = false,
    fire_loop: bool = false,
    fire_end: ?[:0]const u8 = null,
    fire_start_ms: i16 = 0,
    finish_ms: u16 = 0,
    scale_fire_rate: bool = true,
    charge: ?struct { max_frame: u16, frame_ms: u16, sound: [:0]const u8, sound_ms: u16 } = null,
    reselect: ?[:0]const u8 = null,
};
pub const AttackAnimation = struct { pose: [:0]const u8, rate: u16 };

pub const Audio = struct {
    /// Gold weaponTouch / ammo_touch defaults; individual classes override ammunition.
    pickup: [:0]const u8 = "global/i_pickup6.wav",
    ammo_pickup: [:0]const u8 = "global/i_c4ammo.wav",
    fire: ?[:0]const u8 = null,
    variants: [3]?[:0]const u8 = .{ null, null, null },
    ready: ?[:0]const u8 = null,
    away: ?[:0]const u8 = null,
    reload: ?[:0]const u8 = null,
    finish: ?[:0]const u8 = null,
    /// Gold SND_WEAPON_STD: looped on the holder while selected.
    hum: ?[:0]const u8 = null,
    /// Gold SND_AMBIENT_STD..: played with the matching idle animation.
    idle: [3]?[:0]const u8 = .{ null, null, null },
};

pub const Visual = struct {
    projectile_scale: f32 = 1,
    projectile_sprite: ?[:0]const u8 = null,
    resting_sprite: ?[:0]const u8 = null,
    sprite_additive: bool = true,
    projectile_model: [:0]const u8 = "",
    impact_sprite: [:0]const u8 = "models/global/we_expl.sp2",
    blast_sound: ?[:0]const u8 = null,
    color: [3]f32 = .{ 1, 0.45, 0.12 },
    spin: bool = false,
    /// Constant light around the projectile model.
    glow: bool = true,
    fade_stuck: bool = true,
};

pub const ProjectileSpawn = struct {
    mins: [3]f32 = @splat(-1),
    maxs: [3]f32 = @splat(1),
    recoil: f32 = 0,
    recoil_on_launch: bool = false,
    sound_on_launch: bool = true,
    inertial: bool = false,
    aim_range: f32 = 2000,
    self_splash: f32 = 0.5,
    gravity: bool = false,
    water_collision: bool = false,
    loop_sound: ?[:0]const u8 = null,
    direct_scale: f32 = 1,
    splash_scale: f32 = 0,
    splash_radius: f32 = 128,
    action_delay_ms: u32 = 0,
    lifetime_ms: u32 = 0,
    lifetime_scale: f32 = 1,
    collide_owner_after_bounce: bool = false,
    contact_when_resting: bool = false,
    remove_when_resting: bool = false,
    resting_lifetime_scale: f32 = 0,
};
pub const Muzzle = struct {
    model: [:0]const u8,
    sprite: bool = false,
    delay_ms: u16 = 0,
    animation: [:0]const u8 = "stand",
    shader: ?[:0]const u8 = null,
    scale: f32 = 1,
    alpha: u8 = 153,
    offset: f32 = 0,
    light_radius: f32 = 150,
    color: [3]f32 = .{ 0.8, 0.4, 0.2 },
};

pub const Combat = union(enum) {
    pending,
    /// A ballistic projectile flown and resolved by the shared projectile system (`flight_tag`,
    /// `flightMotion`, `flightContact`).
    projectile,
    /// A projectile spawned by the shared system and flown by its server class adapter (`step`).
    flown,
    melee,
    /// Fired by the weapon's own server class adapter (`fire`).
    owned,
    hitscan: struct { single_player_scale: f32 = 1, standing_height: ?f32 = null, crouching_height: ?f32 = null, inertial: bool = false },
    pellets: struct { count: u8, spread: f32, single_player_scale: f32 = 1, range: f32 = 4000, aim_reach: bool = false, max_victims: u8 = 12, inertial: bool = false, recoil: f32 = 0 },
    /// An energy bolt launched at the crosshair that bounces off walls a few times.
    bolt: struct { radius: f32, water_radius: f32, bounce_retention: f32, max_bounces: u8, cleanup_ms: i64 },
};

pub const PlayerGrip = enum { glove, pistol, rifle, shoulder };
pub const Companion = struct {
    slot: u2,
    pickup: bool = true,
    ammunition: bool = true,
    empty_melee: bool = false,
    clearance: f32 = 5,
    safety: enum { none, spread, owner, both } = .none,
};
/// Automatic acquisition distinguishes story allies from ordinary actors.
/// Direct weapon contacts retain their separate damage rules.
pub const AutomaticTargets = struct {
    pub const Mode = enum { never, deathmatch, always };
    pub const Role = enum { actor, player, party, other };
    actors: bool = true,
    players: Mode = .deathmatch,
    party: Mode = .deathmatch,
    pub fn allows(self: AutomaticTargets, role: Role, deathmatch: bool) bool {
        const mode: Mode = switch (role) {
            .actor => return self.actors,
            .player => self.players,
            .party => self.party,
            .other => return false,
        };
        return mode == .always or (mode == .deathmatch and deathmatch);
    }
};
test "automatic acquisition admits hostile actors without selecting story allies" {
    const t = @import("std").testing;
    const policy: AutomaticTargets = .{};
    try t.expect(policy.allows(.actor, false));
    try t.expect(!policy.allows(.party, false));
    try t.expect(!policy.allows(.player, false));
    try t.expect(!policy.allows(.other, true));
    try t.expect(policy.allows(.party, true));
    try t.expect(policy.allows(.player, true));
    try t.expect(!(AutomaticTargets{ .party = .never }).allows(.party, true));
}
pub const Spec = struct {
    /// The attack is placed where its user stands (a charge): users on the move do not choose it.
    placed: bool = false,
    player_grip: PlayerGrip,
    reselect_command: ?[:0]const u8 = null,
    combat: Combat = .pending,
    impact: @import("impact.zig").Style = .none,
    ammo_class: ?[:0]const u8 = null,
    /// Rounds in one gold ammo pack; 0 falls back to the initial ammunition.
    ammo_pack: c_int = 0,
    auto_select: bool = true,
    automatic_targets: AutomaticTargets = .{},
    droppable: bool = true,
    /// Authored pickups remain available when the server enables weapons-stay.
    /// Dropped weapons are always consumed, regardless of this policy.
    respects_weapons_stay: bool = true,
    pickup_respawn_ms: u32 = 30000,
    /// Ammunition earned by a credited, non-sword kill in this weapon's episode.
    credited_kill_ammo: u16 = 0,
    companion: ?Companion = null,
    start_episode: u8 = 0,
    campaign_equipment: bool = false,
    splash_hazard: bool = false,
    /// Optional class-reviewed bound for a short-flight splash shot. Other
    /// weapons retain the ordinary blast keep-out unconditionally.
    bot_close_splash: ?struct {
        max_damage_scale: f32,
        max_flight_ms: f32,
        min_distance: f32 = 32,
        health_reserve: f32 = 40,
    } = null,
    bot_charge_ms: c_int = 0,
    bot_range: ?f32 = null,
    /// A deliberate route request may use this attack; autonomous fallback may not.
    bot_requires_request: bool = false,
    /// Aim a body-origin melee arc using its own origin.
    bot_aim_from_body: bool = false,
    /// Keep ordinary attack input pressed between aim-qualified bursts.
    /// Some classes advance their attack chain only while it stays held.
    bot_hold_trigger: bool = false,
    /// Normal class prediction strikes on close contact, including when empty.
    bot_contact_melee_range: ?f32 = null,
    /// Rounds retained for authored shot controls. Recoverable ammunition can
    /// opt out: a thrown round in flight is not a scarce consumable reserve.
    bot_ammo_reserve: u16 = 12,
    /// Wait for recoverable ammunition before abandoning an engagement.
    bot_rearm_ms: u16 = 0,
    protects_water: bool = false,
    inventory_view_model: bool = false,
    world_model: ?[:0]const u8 = null,
    /// Pickup and equipped representations have independent contracts.
    equipped: bool = true,
    equipped_frame: c_int = 4,
    /// Handle centre in the equipped mesh, for attachment to a skeletal palm.
    skeletal_grip_origin: [3]f32 = .{ 0, 0, 0 },
    animation: Animation = .{},
    muzzle: ?Muzzle = null,
    audio: Audio = .{},
    visual: Visual = .{},
    projectile: ProjectileSpawn = .{},
    burst_shots: u8 = 0,
    burst_recovery_ms: u16 = 0,
    projectile_muzzle: bool = false,

    /// Match the physical attack: pellet rays are points, energy bolts use
    /// their declared radius, and ballistic rounds use their own hull.
    pub fn shotBounds(self: Spec) struct { mins: [3]f32, maxs: [3]f32 } {
        return switch (self.combat) {
            .bolt => |bolt| .{ .mins = @splat(-bolt.radius), .maxs = @splat(bolt.radius) },
            .hitscan, .pellets, .melee => .{ .mins = @splat(0), .maxs = @splat(0) },
            // Class-owned firing can launch physical rounds too. Preserve
            // their declared hull instead of assuming an unknown attack is
            // a point ray merely because its class owns the launch adapter.
            else => .{ .mins = self.projectile.mins, .maxs = self.projectile.maxs },
        };
    }
};

test "muzzle admission uses ray, bolt and ballistic collision bounds" {
    const t = @import("std").testing;
    var spec: Spec = .{ .player_grip = .rifle, .combat = .{ .pellets = .{ .count = 10, .spread = 0.1 } } };
    try t.expectEqual([3]f32{ 0, 0, 0 }, spec.shotBounds().mins);
    spec.combat = .{ .bolt = .{ .radius = 2, .water_radius = 64, .bounce_retention = 1, .max_bounces = 3, .cleanup_ms = 1000 } };
    try t.expectEqual([3]f32{ -2, -2, -2 }, spec.shotBounds().mins);
    try t.expectEqual([3]f32{ 2, 2, 2 }, spec.shotBounds().maxs);
    spec.combat = .projectile;
    spec.projectile.mins = .{ -3, -2, -1 };
    try t.expectEqual(spec.projectile.mins, spec.shotBounds().mins);
    spec.combat = .owned;
    try t.expectEqual(spec.projectile.mins, spec.shotBounds().mins);
}
