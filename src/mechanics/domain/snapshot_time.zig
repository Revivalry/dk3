// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Explicit native save timestamp mapping. Durations never shift with the clock.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const saved = @import("actor_catalog").saved_time;
const shift = saved.shift;
const active = saved.active;
const deadline = saved.deadline;
/// A class state that declares `method` (rebase, validate, remapIds).
pub fn classState(comptime T: type, comptime method: []const u8) bool {
    return @typeInfo(T) == .@"struct" and @hasDecl(T, method);
}
fn liquid(value: *@import("environment.zig").State, delta: i64) !void {
    if (!value.initialized) return;
    inline for (.{ "next_ms", "air_until_ms", "damage_ms", "cold_start_ms", "cold_next_ms" }) |field| try shift(&@field(value, field), delta);
    try deadline(&value.nitro_ms, delta);
}
/// Shared components rebase here; every other component rebases itself.
pub fn rebase(comptime id: data.ComponentId, value: *data.types[@intFromEnum(id)], delta: i64) !void {
    switch (id) {
        .destructible => if (value.wall_explode) |*wall| try wall.rebase(saved.Clock{ .delta = delta }),
        .world_control => {
            try active(&value.ready_ms, delta);
            // Control states rebase themselves.
            const clock: saved.Clock = .{ .delta = delta };
            switch (value.action) {
                inline else => |*state| if (comptime classState(@TypeOf(state.*), "rebase")) try state.rebase(clock),
            }
        },
        .scenery => {
            try shift(&value.started_ms, delta);
            try deadline(&value.breaking_ms, delta);
            try deadline(&value.expires_ms, delta);
            if (value.gib) |*gib| {
                try shift(&gib.next_ms, delta);
                try deadline(&gib.fade_ms, delta);
            }
        },
        .session => {
            try active(&value.respawn_ms, delta);
            try shift(&value.joined_ms, delta);
            if (value.pose.initialized) try shift(&value.pose.started_ms, delta);
        },
        .objective => {
            try deadline(&value.deadline, delta);
            try active(&value.pickup_ms, delta);
            try active(&value.beep_ms, delta);
            if (value.airborne) try shift(&value.stepped_ms, delta);
        },
        .script => {
            try shift(&value.due_ms, delta);
            try shift(&value.next_ms, delta);
        },
        .cinematic => try shift(&value.started_ms, delta),
        .performer => {
            try shift(&value.head_ms, delta);
            try shift(&value.animation_ms, delta);
            try shift(&value.due_ms, delta);
            try shift(&value.next_ms, delta);
        },
        .lifetime => try shift(&value.expires_ms, delta),
        .player => {
            try shift(&value.command_ms, delta);
            try active(&value.teleport_until_ms, delta);
        },
        .weapons => {
            try active(&value.gas_until_ms, delta);
            try deadline(&value.last_fire_ms, delta);
        },
        .trigger => try active(&value.ready_ms, delta),
        .pickup => {
            try deadline(&value.respawn_ms, delta);
            try deadline(&value.expires_ms, delta);
        },
        .item_motion => try shift(&value.started_ms, delta),
        .character => {
            try liquid(&value.liquid, delta);
            for (&value.boost_until) |*at| try active(at, delta);
            try active(&value.invincible_until, delta);
            try active(&value.invisible_until, delta);
            try active(&value.environment_until, delta);
        },
        .projectile => {
            try shift(&value.born_ms, delta);
            try shift(&value.stepped_ms, delta);
        },
        .melee => try shift(&value.started_ms, delta),
        .weapon_launch => try shift(&value.execute_ms, delta),
        .ailments => {
            if (value.warp) |*warp| {
                try shift(&warp.until_ms, delta);
                try shift(&warp.next_ms, delta);
            }
            if (value.poison) |*poison| {
                try shift(&poison.until_ms, delta);
                try shift(&poison.next_ms, delta);
            }
            try deadline(&value.freeze_at_ms, delta);
            try deadline(&value.freeze_next_ms, delta);
        },
        .actor_attack => try value.rebase(delta),
        .actor => {
            // Class states rebase themselves; these are the shared actor timestamps.
            inline for (@typeInfo(data.Actor).@"struct".fields) |field| if (comptime classState(field.type, "rebase")) try @field(value, field.name).rebase(delta);
            try deadline(&value.stepped_ms, delta);
            try liquid(&value.liquid, delta);
            try active(&value.pain_ready_ms, delta);
            try deadline(&value.idle_started_ms, delta);
            try deadline(&value.audio.attack_started_ms, delta);
            try deadline(&value.audio.started_ms, delta);
            try deadline(&value.audio.sampled_ms, delta);
            try deadline(&value.audio.ambient_ready_ms, delta);
            try deadline(&value.script_paused_ms, delta);
            try shift(&value.reaction_started_ms, delta);
            try deadline(&value.reaction_until_ms, delta);
            try shift(&value.think_ms, delta);
            try shift(&value.scripted_ms, delta);
            try shift(&value.use_ready_ms, delta);
            try shift(&value.changed_ms, delta);
            try active(&value.panic_until, delta);
            try shift(&value.threat_seen_ms, delta);
            if (value.witness_ms != -1) try shift(&value.witness_ms, delta);
            try active(&value.escape_until, delta);
            try active(&value.jump_ready_ms, delta);
            // Routing caches are derived from the current collision/nav world.
            value.route = .{};
        },
        .hurt => {
            if (value.at_ms != -1) try shift(&value.at_ms, delta);
            if (value.feedback.flash_alpha > 0) try shift(&value.feedback.flash_ms, delta);
            try deadline(&value.feedback.pain_ready_ms, delta);
            try deadline(&value.feedback.hazard_voice_ms, delta);
        },
        .hazard => try active(&value.ready_ms, delta),
        .exit => {
            try active(&value.ready_ms, delta);
            try deadline(&value.ending_started, delta);
        },
        .target_sequence => {
            try shift(&value.started_ms, delta);
            try active(&value.ready_ms, delta);
        },
        // Every other component rebases itself (`rebase(clock)`), or holds no timestamps.
        else => if (comptime classState(@TypeOf(value.*), "rebase")) try value.rebase(saved.Clock{ .delta = delta }),
    }
}
test "save time rebasing preserves deadlines, inactive sentinels and durations" {
    var train: data.Train = .{ .position = .{ .start_ms = 1200, .duration_ms = 900 }, .action = .{ .at_ms = 2200 } };
    try rebase(.train, &train, 10000);
    try std.testing.expectEqual(@as(i64, 11200), train.position.start_ms);
    try std.testing.expectEqual(@as(i32, 900), train.position.duration_ms);
    try std.testing.expectEqual(@as(?i64, 12200), train.action.at_ms);
    var character: data.Character = .{ .boost_until = .{ 0, 100, 0, 0, 0 } };
    try rebase(.character, &character, 10000);
    try std.testing.expectEqual(@as(i64, 0), character.boost_until[0]);
    try std.testing.expectEqual(@as(i64, 10100), character.boost_until[1]);
}

test "companion collection and yielding deadlines rebase without changing targets" {
    var state: data.Companion = .{ .identity = .superfly, .motor = .{ .command_ms = 1000, .ducked = true, .water_level = 2, .timer = .water_jump, .timer_ms = 400 }, .jump_started_ms = 900, .collecting = 42, .collect_forced = true, .collect_scan_ms = 2000, .collect_until_ms = 4000, .avoided_item = 43, .avoid_until_ms = 5000, .yielding_until_ms = 1800, .yield_position = .{ 16, 32, 0 } };
    try rebase(.companion, &state, 8000);
    try std.testing.expectEqual(@as(i64, 9000), state.motor.command_ms);
    try std.testing.expectEqual(@as(i64, 8900), state.jump_started_ms);
    try std.testing.expect(state.motor.ducked and state.motor.water_level == 2);
    try std.testing.expectEqual(@as(u32, 400), state.motor.timer_ms);
    try std.testing.expectEqual(@as(i64, 10000), state.collect_scan_ms);
    try std.testing.expectEqual(@as(i64, 12000), state.collect_until_ms);
    try std.testing.expectEqual(@as(i64, 13000), state.avoid_until_ms);
    try std.testing.expectEqual(@as(i64, 9800), state.yielding_until_ms);
    try std.testing.expectEqual(@as(u32, 42), state.collecting);
    try std.testing.expect(state.collect_forced);
    try std.testing.expectEqual(@as(u32, 43), state.avoided_item);
}

test "liquid reserves preserve remaining air nitro callback and suit charge on restore" {
    var character: data.Character = .{ .environment_until = 9000, .environment_charge_ms = 5000, .liquid = .{ .initialized = true, .next_ms = 4100, .air_until_ms = 12000, .damage_ms = 4200, .cold_start_ms = 4000, .cold_next_ms = 6000, .nitro_ms = 7000, .level = 3, .kind = .water, .fraction = 0.75 } };
    try rebase(.character, &character, 8000);
    try std.testing.expectEqual(@as(i64, 12100), character.liquid.next_ms);
    try std.testing.expectEqual(@as(i64, 20000), character.liquid.air_until_ms);
    try std.testing.expectEqual(@as(?i64, 15000), character.liquid.nitro_ms);
    try std.testing.expectEqual(@as(i64, 5000), character.environment_charge_ms);
    try std.testing.expectEqual(@as(f32, 0.75), character.liquid.fraction);
}

test "wildlife restoration keeps target hysteresis wave phase and pending blood cloud delay" {
    const t = std.testing;
    var actor: data.Actor = .{ .definition = @import("actor_catalog").find("fish_dopefish").?, .fish = .{ .owner = 42, .aggressive = true, .motion_ms = 1100, .wander_until_ms = 2400 }, .seagull = .{ .motion_ms = 1200, .wave = 7, .bobbing = true } };
    try rebase(.actor, &actor, 8000);
    try t.expectEqual(@as(?i64, 9100), actor.fish.motion_ms);
    try t.expectEqual(@as(?i64, 10400), actor.fish.wander_until_ms);
    try t.expectEqual(@as(u32, 42), actor.fish.owner);
    try t.expect(actor.fish.aggressive);
    try t.expectEqual(@as(?i64, 9200), actor.seagull.motion_ms);
    try t.expectEqual(@as(u4, 7), actor.seagull.wave);
    var cloud: data.WorldControl = .{ .action = .{ .blood_cloud = .{ .next_ms = 1100, .extent = .{ 92, 92, -240 }, .mass = 200 } } };
    try rebase(.world_control, &cloud, 8000);
    try t.expectEqual(@as(i64, 9100), cloud.action.blood_cloud.next_ms);
    try t.expectEqual(null, cloud.action.blood_cloud.until_ms);
    cloud.action.blood_cloud.until_ms = 9600;
    try rebase(.world_control, &cloud, 1000);
    try t.expectEqual(@as(?i64, 10600), cloud.action.blood_cloud.until_ms);
    try t.expectEqual(@as(i64, 500), cloud.action.blood_cloud.until_ms.? - cloud.action.blood_cloud.next_ms);
}

test "actor audio restoration retains consumed cues, choices and remaining ambient delay" {
    var value: data.Actor = .{ .definition = 0, .idle_pose = .{ .first = 10, .last = 29 }, .idle_started_ms = 1000, .audio = .{
        .attack_started_ms = 1000,
        .attack_index = 2,
        .attack_sounds = 2,
        .attack_alternate = true,
        .cue = 4,
        .started_ms = 1000,
        .sampled_ms = 1400,
        .frame = 14,
        .pending = 1,
        .sounded = 1,
        .alternate = true,
        .threat = 8,
        .ambient_ready_ms = 31000,
    } };
    try rebase(.actor, &value, 8000);
    try std.testing.expectEqual(@as(?i64, 9000), value.idle_started_ms);
    try std.testing.expectEqual(@as(?i64, 9000), value.audio.attack_started_ms);
    try std.testing.expectEqual(@as(?i64, 9000), value.audio.started_ms);
    try std.testing.expectEqual(@as(?i64, 9400), value.audio.sampled_ms);
    try std.testing.expectEqual(@as(?i64, 39000), value.audio.ambient_ready_ms);
    try std.testing.expectEqual(@as(u2, 2), value.audio.attack_sounds);
    try std.testing.expectEqual(@as(u2, 1), value.audio.sounded);
    try std.testing.expectEqual(@as(u2, 1), value.audio.pending);
    try std.testing.expectEqual(@as(u32, 8), value.audio.threat);
    try std.testing.expect(value.audio.alternate and value.audio.attack_alternate);
}

test "world timer restore shifts its deadline but preserves variance sequence and activation" {
    var control: data.WorldControl = .{ .uses = 3, .action = .{ .timer = .{ .next_ms = 2000, .wait_ms = 1000, .variance_ms = 500, .activator = 9, .random = 123 } } };
    try rebase(.world_control, &control, 8000);
    try std.testing.expectEqual(@as(?i64, 10000), control.action.timer.next_ms);
    try std.testing.expectEqual(@as(u32, 123), control.action.timer.random);
    try std.testing.expectEqual(@as(u32, 9), control.action.timer.activator);
    try std.testing.expectEqual(@as(u32, 3), control.uses);
    var player: data.Player = .{ .command_ms = 1000, .teleport_until_ms = 1700, .teleport_bit = true };
    try rebase(.player, &player, 8000);
    try std.testing.expectEqual(@as(i64, 9700), player.teleport_until_ms);
    try std.testing.expect(player.teleport_bit);
}

test "authored speaker and healing station deadlines retain remaining time" {
    const t = std.testing;
    var speaker: data.WorldControl = .{ .action = .{ .speaker = .{ .count = 1, .timed = true, .delay_secs = 3, .next_ms = 3000 } } };
    try rebase(.world_control, &speaker, 9000);
    try t.expectEqual(@as(?i64, 12000), speaker.action.speaker.next_ms);
    var healer: data.WorldControl = .{ .action = .{ .healer = .{ .phase = .giving, .recipient = 8, .next_ms = 1200, .effect_ms = 1000, .charge = 42 } } };
    try rebase(.world_control, &healer, 9000);
    try t.expectEqual(@as(?i64, 10200), healer.action.healer.next_ms);
    try t.expectEqual(@as(?i64, 10000), healer.action.healer.effect_ms);
    try t.expectEqual(@as(u32, 42), healer.action.healer.charge);
    try t.expectEqual(@as(u32, 8), healer.action.healer.recipient);
}

test "authored earthquake and light restoration retain pending pulses, ramp progress and pattern phase" {
    const t = std.testing;
    var quake: data.WorldControl = .{ .action = .{ .earthquake = .{ .next_ms = 1300, .until_ms = 6100 } } };
    var light: data.WorldControl = .{ .action = .{ .light = .{ .kind = .light, .pattern = "amb", .phase_ms = 700, .revision = 42 } } };
    var ramp: data.WorldControl = .{ .action = .{ .light_ramp = .{ .from = 0, .to = 25, .started_ms = 900, .next_ms = 1300, .target = 14 } } };
    const before = ramp.action.light_ramp.sample(1250);
    const phase = @import("../../classes/entities/light/domain/lightstyles.zig").sample(light.action.light.pattern, 1250 - light.action.light.phase_ms);
    try rebase(.world_control, &quake, 9000);
    try rebase(.world_control, &light, 9000);
    try rebase(.world_control, &ramp, 9000);
    try t.expectEqual(@as(i64, 50), quake.action.earthquake.next_ms.? - 10250);
    try t.expectEqual(@as(i64, 4850), quake.action.earthquake.until_ms - 10250);
    try t.expectEqual(before, ramp.action.light_ramp.sample(10250));
    try t.expectEqual(phase, @import("../../classes/entities/light/domain/lightstyles.zig").sample(light.action.light.pattern, 10250 - light.action.light.phase_ms));
    try t.expectEqual(@as(u64, 42), light.action.light.revision);
}

test "restored lightning keeps link and expiry boundaries while preserving intervals" {
    const t = std.testing;
    var emitter: data.WorldControl = .{ .action = .{ .lightning = .{ .flags = 0, .next_ms = 2100, .uncull_until_ms = 3000 } } };
    var attractor: data.WorldControl = .{ .action = .{ .attractor = .{ .link_ms = 700 } } };
    var bolt: data.WorldControl = .{ .action = .{ .lightning_bolt = .{ .emitter = 9, .target = 4, .endpoint = .{ 1, 2, 3 }, .next_ms = 800, .until_ms = 1000, .damage = 10 } } };
    try rebase(.world_control, &emitter, 5000);
    try rebase(.world_control, &attractor, 5000);
    try rebase(.world_control, &bolt, 5000);
    try t.expectEqual(@as(?i64, 7100), emitter.action.lightning.next_ms);
    try t.expectEqual(@as(i64, 8000), emitter.action.lightning.uncull_until_ms);
    try t.expectEqual(@as(i64, 2000), emitter.action.lightning.delay_ms);
    try t.expectEqual(@as(?i64, 5700), attractor.action.attractor.link_ms);
    try t.expectEqual(@as(i64, 5800), bolt.action.lightning_bolt.next_ms);
    try t.expectEqual(@as(i64, 6000), bolt.action.lightning_bolt.until_ms);
    try t.expectEqual(@as(u32, 9), bolt.action.lightning_bolt.emitter);
    try t.expectEqual(@as(u32, 4), bolt.action.lightning_bolt.target);
}

test "target-effect restore retains the strict final boundary and pulse identity" {
    var value: data.WorldControl = .{ .action = .{ .target_effect = .{ .flags = 0, .next_ms = 1200, .until_ms = 1400, .pulse_ms = 1100, .serial = 7, .visible = true, .duration_ms = 400 } } };
    try rebase(.world_control, &value, 8000);
    try std.testing.expectEqual(@as(?i64, 9200), value.action.target_effect.next_ms);
    try std.testing.expectEqual(@as(?i64, 9400), value.action.target_effect.until_ms);
    try std.testing.expectEqual(@as(?i64, 9100), value.action.target_effect.pulse_ms);
    try std.testing.expectEqual(@as(u32, 7), value.action.target_effect.serial);
    try std.testing.expectEqual(@as(i64, 400), value.action.target_effect.duration_ms);
}

test "chest restoration preserves selected reward and remaining reveal duration" {
    var value: data.WorldControl = .{ .action = .{ .chest = .{ .kind = .black, .stepped_ms = 2400 } } };
    const state = &value.action.chest;
    _ = state.use(7, 500, 50);
    try std.testing.expectEqual(.reveal, state.advance(2300, 3));
    try rebase(.world_control, &value, -2000);
    try std.testing.expectEqual(@as(?i64, -1500), state.started_ms);
    try std.testing.expectEqual(@as(i64, 400), state.stepped_ms);
    try std.testing.expectEqual(.none, state.advance(1799, 0));
    try std.testing.expectEqual(.reward, state.advance(1800, 0));
    try std.testing.expectEqualStrings("item_invincibility", state.rewardClass());
    try std.testing.expectEqual(.none, state.advance(1900, 0));
}

test "death-drop expiry and consumed player injury survive clock rebasing" {
    var pickup: data.Pickup = .{ .kind = .{ .weapon = 2 }, .amount = 7, .dropped = true, .expires_ms = 61000 };
    try rebase(.pickup, &pickup, 9000);
    try std.testing.expectEqual(@as(?i64, 70000), pickup.expires_ms);
    try std.testing.expectEqual(null, pickup.respawn_ms);
    var hurt: data.Hurt = .{ .at_ms = 1000, .revision = 4, .feedback = .{ .handled_revision = 4, .death_handled = true, .pain_ready_ms = 2000, .hazard_voice_ms = 4000, .flash_alpha = 0.5, .flash_ms = 1000 } };
    try rebase(.hurt, &hurt, 9000);
    try std.testing.expectEqual(@as(i64, 10000), hurt.at_ms);
    try std.testing.expectEqual(@as(?i64, 11000), hurt.feedback.pain_ready_ms);
    try std.testing.expectEqual(@as(?i64, 13000), hurt.feedback.hazard_voice_ms);
    try std.testing.expectEqual(hurt.revision, hurt.feedback.handled_revision);
    try std.testing.expect(hurt.feedback.death_handled);
    try std.testing.expectApproxEqAbs(@as(f32, 0.455), hurt.feedback.alpha(10100), 0.00001);
}
