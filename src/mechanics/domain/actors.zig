// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: actor state (shared fields plus each class's declared slot) and aidata definitions.
const std = @import("std");
const catalog = @import("actor_catalog");
const v = @import("../../core/domain/vector.zig");
const animation = @import("../../core/domain/animation.zig");
pub const Mode = enum { idle, flee, chase, attack, reload, dead };
/// What every actor carries, whatever its class.
const Shared = struct {
    definition: u8,
    stepped_ms: ?i64 = null,
    audio: @import("actor_audio.zig").State = .{},
    idle_pose: ?animation.Sequence = null,
    idle_started_ms: ?i64 = null,
    melee: catalog.melee_cycle.State = .{},
    pain_ready_ms: i64 = 0,
    evasion: catalog.evasion.State = .{},
    cover: catalog.cover.State = .{},
    roam: catalog.wander.Roam = .{},
    reaction: ?animation.Sequence = null,
    reaction_started_ms: i64 = 0,
    reaction_until_ms: ?i64 = null,
    death_pose: ?animation.Sequence = null,
    uses: u32 = 0,
    use_ready_ms: i64 = 0,
    think_ms: i64 = 0,
    unique: []const u8 = "",
    ignore_player: bool = false,
    path: u32 = 0,
    scripted_pose: ?animation.Sequence = null,
    moving_pose: ?animation.Sequence = null,
    scripted_ms: i64 = 0,
    script_paused_ms: ?i64 = null,

    liquid: @import("environment.zig").State = .{},
    mode: Mode = .idle,
    changed_ms: i64 = 0,
    panic_until: i64 = 0,
    threat: u32 = 0,
    threat_position: v.Vec3 = @splat(0),
    threat_seen_ms: i64 = 0,
    witness_ms: i64 = -1,
    receipt: u32 = 0,
    death_dispatched: bool = false,
    gibbed: bool = false,
    ground_entity: u16 = 2047,
    route: @import("../../core/domain/navigation.zig").State = .{},
    escape_until: i64 = 0,
    jump_ready_ms: i64 = 0,
};
/// An actor's state: the shared fields, then one slot per class policy that declares a `State`,
/// named by its `state_field` (the saved key, so saves keep their layout). Classes own their
/// slots; this module names none.
pub const State = blk: {
    @setEvalBranchQuota(100_000);
    const shared = @typeInfo(Shared).@"struct".fields;
    var count: usize = shared.len;
    for (catalog.policies) |policy| {
        if (@hasDecl(policy, "state_field")) count += 1;
    }
    var names: [count][]const u8 = undefined;
    var types: [count]type = undefined;
    var attributes: [count]std.builtin.Type.StructField.Attributes = undefined;
    for (shared, 0..) |field, index| {
        names[index] = field.name;
        types[index] = field.type;
        attributes[index] = .{ .@"comptime" = field.is_comptime, .@"align" = field.alignment, .default_value_ptr = field.default_value_ptr };
    }
    var at: usize = shared.len;
    for (catalog.policies) |policy| if (@hasDecl(policy, "state_field")) {
        names[at] = policy.state_field;
        types[at] = policy.State;
        attributes[at] = .{ .default_value_ptr = &policy.State{} };
        at += 1;
    };
    break :blk @Struct(.auto, null, &names, &types, &attributes);
};
/// Flees from `point` for `duration_ms`.
pub fn panic(self: *State, source: u32, point: v.Vec3, duration_ms: i64, now: i64) void {
    if (self.mode == .dead) return;
    if (self.mode != .flee) self.changed_ms = now;
    self.mode = .flee;
    self.panic_until = now + duration_ms;
    self.threat = source;
    self.threat_position = point;
}
pub const Definition = struct {
    loaded: bool = false,
    audio: []const @import("actor_audio.zig").Cue = &.{},
    idle_choices: []const @import("actor_audio.zig").Idle = &.{},
    attenuation: [2]f32 = .{ 256, 648 },
    cower: [2]animation.Sequence = @splat(.{}),
    pain_c: ?animation.Sequence = null,
    alternate_idle: animation.Sequence = .{},
    model: []const u8 = "",
    health: i32 = 0,
    mass: f32 = 100,
    speed: f32 = 0,
    walk_speed: f32 = 0,
    mins: v.Vec3 = @splat(0),
    maxs: v.Vec3 = @splat(0),
    idle: animation.Sequence = .{},
    run: animation.Sequence = .{},
    ground_run: animation.Sequence = .{},
    death: animation.Sequence = .{},
    attacks: [8]animation.Sequence = @splat(.{}),
    /// False for an optional attack clip the model lacks (`AttackLoad.optional`).
    attack_present: [8]bool = @splat(true),
    /// The frame whose arrival raises each attack clip's strike (the table frame + 1, the reference's rule).
    strikes: [8]u16 = @splat(1),
    second_strikes: [8]?u16 = @splat(null),
    attack_alternative: [8]?f32 = @splat(null),
    attack_sound_enabled: [8]bool = @splat(true),
    attack_sounds: [8][]const u8 = @splat(""),
    attack_sound_ms: [8]i64 = @splat(0),
    second_attack_sounds: [8][]const u8 = @splat(""),
    second_sound_ms: [8]?i64 = @splat(null),
    swim: animation.Sequence = .{},
    walk: animation.Sequence = .{},
    death_b: animation.Sequence = .{},
    death_d: animation.Sequence = .{},
    awakening: animation.Sequence = .{},
    pain: [2]?animation.Sequence = @splat(null),
    hatch_sound: []const u8 = "",
    reload: animation.Sequence = .{},
    hatch: animation.Sequence = .{},
    sight_range: f32 = 0,
    /// How far its calls to other monsters carry: 0.15 × its aidata active distance (before any
    /// class override of its sight).
    speak_range: f32 = 0,
    attack_range: f32 = 0,
    fov: f32 = 180,
    yaw_speed: f32 = 20,
    pitch_speed: f32 = 20,
    upward_speed: f32 = 0,
    /// A leap clip's strike: its second sound frame; none when the row has none (the reference never strikes then).
    jump_strike_ms: ?i64 = null,
    jump_distance: f32 = 0,
    damage: f32 = 0,
    random_damage: f32 = 0,
    range: f32 = 0,
    offset: v.Vec3 = @splat(0),
    spread: [2]f32 = @splat(0),
    scale: v.Vec3 = @splat(1),
    /// The owning class's aidata tuning beyond the shared columns.
    class: catalog.ClassTuning = .none,
    pub fn tuning(self: *const Definition, comptime Policy: type) *const Policy.ClassTuning {
        return catalog.tuningOf(Policy, &self.class);
    }
};
/// Gold AIATTRIBUTE_ParseData multiplies these aidata values by 0.75, 1 or
/// 1.25 for skill 0, 1 or 2 (AI_GetSkill).
const difficulty_scaled = [_][]const u8{ "health", "basehealth", "active_distance", "run_speed", "walk_speed", "attack_speed", "weapon1_base_damage", "weapon1_random_damage", "weapon1_speed", "weapon2_base_damage", "weapon2_random_damage", "weapon3_base_damage", "weapon3_random_damage" };
/// `g_spSkill` (Ronin 1, Samurai 3, Shogun 5) as Gold's multiplier.
pub fn difficultyFactor(skill: i32) f32 {
    return catalog.difficulty.factor(skill);
}
pub const Table = struct {
    definitions: [catalog.entries.len]Definition = @splat(.{}),
    /// A difficulty change during play scales the shared difficulty columns already parsed (health,
    /// run and walk speed, sight and call range, the first weapon's damage) by `ratio`; class
    /// tuning columns keep the difficulty the map was loaded with.
    pub fn rescale(self: *Table, ratio: f32) void {
        for (&self.definitions) |*entry| {
            if (!entry.loaded) continue;
            entry.health = @max(1, @as(i32, @intFromFloat(@round(@as(f32, @floatFromInt(entry.health)) * ratio))));
            inline for (.{ "speed", "walk_speed", "sight_range", "speak_range", "damage", "random_damage" }) |field| @field(entry, field) *= ratio;
        }
    }
    pub fn parse(bytes: []const u8, difficulty: f32) !Table {
        var result: Table = .{};
        var reader = try @import("../../core/domain/tables.zig").Reader.init(bytes);
        while (try reader.next()) |read| {
            var row = read;
            row.scaled = &difficulty_scaled;
            row.scale = difficulty;
            const id = catalog.find(row.field("classname") orelse return error.MissingActorClass) orelse continue;
            const entry = &result.definitions[id];
            if (entry.loaded) return error.DuplicateActorClass;
            entry.model = row.field("model_name") orelse return error.MissingActorModel;
            if (entry.model.len == 0 or entry.model.len >= 64) return error.InvalidActorModel;
            entry.speak_range = try row.number("active_distance", 1000) * 0.15;
            if (!catalog.sharedTuning(catalog.entries[id].kind)) {
                try catalog.parseTuning(catalog.entries[id].kind, &row, entry);
                entry.loaded = true;
                continue;
            }
            const health = try row.number("health", 0);
            entry.speed = try row.number("run_speed", 0);
            entry.walk_speed = try row.number("walk_speed", 0);
            entry.jump_distance = try row.number("jump_attack_distance", 0);
            entry.upward_speed = try row.number("upward_velocity", 0);
            if (entry.upward_speed < 0 or entry.upward_speed > 2000) return error.InvalidActorJump;
            if (health <= 0 or health > 1000000 or entry.speed < 0 or entry.speed > 2000) return error.InvalidActorTuning;
            entry.health = @intFromFloat(health);
            entry.mass = try row.number("mass", 100);
            if (!std.math.isFinite(entry.mass) or entry.mass <= 0 or entry.mass > 100000) return error.InvalidActorMass;
            entry.attack_range = try row.number("attack_distance", 0);
            entry.sight_range = try row.number("active_distance", 1000);
            entry.attenuation = .{ try row.number("min_attenuation", 256), try row.number("max_attenuation", 648) };
            for (entry.attenuation) |attenuation| if (attenuation < 0 or attenuation > 65536) return error.InvalidActorAttenuation;
            entry.fov = try row.number("fov", 180);
            if (row.field("angle_speed")) |angles| {
                var parts = std.mem.tokenizeAny(u8, angles, " \t");
                entry.pitch_speed = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidActorAngles);
                entry.yaw_speed = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidActorAngles);
                if (!std.math.isFinite(entry.pitch_speed) or entry.pitch_speed < 0 or entry.pitch_speed > 360) return error.InvalidActorAngles;
                if (!std.math.isFinite(entry.yaw_speed) or entry.yaw_speed <= 0 or entry.yaw_speed > 360) return error.InvalidActorAngles;
            }
            entry.damage = try row.number("weapon1_base_damage", 0);
            entry.random_damage = try row.number("weapon1_random_damage", 0);
            entry.range = try row.number("weapon1_distance", 0);
            entry.spread = .{ try row.number("weapon1_spread_x", 0), try row.number("weapon1_spread_z", 0) };
            if (entry.sight_range < 0 or entry.sight_range > 65536 or entry.fov < 0 or entry.fov > 360 or entry.damage < 0 or entry.damage > 1000000 or entry.random_damage < 0 or entry.random_damage > 1000000 or entry.range < 0 or entry.range > 65536) return error.InvalidActorTuning;
            for (entry.spread) |spread| if (spread < 0 or spread > 8192) return error.InvalidActorSpread;
            if (row.field("render_scale")) |scale| {
                var axes = std.mem.tokenizeAny(u8, scale, " \t");
                for (&entry.scale) |*value| {
                    value.* = try std.fmt.parseFloat(f32, axes.next() orelse return error.InvalidActorScale);
                    if (!std.math.isFinite(value.*) or value.* <= 0 or value.* > 16) return error.InvalidActorScale;
                }
                if (axes.next() != null) return error.InvalidActorScale;
            }
            inline for (.{ "x", "y", "z" }, 0..) |axis, i| {
                entry.offset[i] = try row.number("weapon1_offset_" ++ axis, 0);
                if (@abs(entry.offset[i]) > 1024) return error.InvalidActorOffset;
                entry.mins[i] = try row.number("size_min_" ++ axis, 0);
                entry.maxs[i] = try row.number("size_max_" ++ axis, 0);
                if (entry.mins[i] >= entry.maxs[i] or @abs(entry.mins[i]) > 1024 or @abs(entry.maxs[i]) > 1024) return error.InvalidActorBounds;
            }
            try catalog.parseTuning(catalog.entries[id].kind, &row, entry);
            entry.loaded = true;
        }
        return result;
    }
};
pub fn fleeVelocity(position: v.Vec3, threat: v.Vec3, speed: f32) v.Vec3 {
    var away = v.add(position, v.scale(threat, -1));
    away[2] = 0;
    if (v.length(away) < 0.01) away = .{ 1, 0, 0 };
    return v.scale(v.normalize(away), speed);
}
test "civilian panic has bounded duration, stable speed and no post-death transition" {
    var state: State = .{ .definition = 0 };
    panic(&state, 42, .{ 10, 20, 0 }, 6000, 1000);
    try std.testing.expectEqual(Mode.flee, state.mode);
    try std.testing.expect(state.panic_until > 1000);
    try std.testing.expectApproxEqAbs(@as(f32, 150), v.length(fleeVelocity(.{ 1, 2, 0 }, .{ 1, 3, 0 }, 150)), 0.001);
    state.mode = .dead;
    panic(&state, 43, @splat(0), 6000, 2000);
    try std.testing.expectEqual(@as(u32, 42), state.threat);
}

test "a difficulty change rescales the parsed difficulty columns" {
    var table: Table = .{};
    table.definitions[0] = .{ .loaded = true, .health = 100, .speed = 200, .damage = 10 };
    table.rescale(1.25);
    try std.testing.expectEqual(@as(i32, 125), table.definitions[0].health);
    try std.testing.expectApproxEqAbs(@as(f32, 250), table.definitions[0].speed, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12.5), table.definitions[0].damage, 0.001);
    try std.testing.expectEqual(@as(i32, 0), table.definitions[1].health);
}
