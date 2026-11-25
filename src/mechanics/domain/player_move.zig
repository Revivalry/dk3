// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: player and companion movement.
// Copyright (C) 1999-2005 Id Software, Inc.
// Shared Zig movement adapted from bundled GPL bg_pmove.c and project dk_ladder.inc.
// See LICENSE. No private reference implementation is imported.
const std = @import("std");
const v = @import("../../core/domain/vector.zig");
const collision = @import("../../core/domain/collision.zig");
const slide = @import("../../core/domain/slide.zig");
pub const Mode = enum { normal, spectator, noclip, dead, frozen };
pub const water_jump_speed: f32 = 350;
/// Controllers must not declare attachment before the motor can touch a rung.
pub const ladder_contact_distance: f32 = 3;
pub const Timer = enum { none, land, knockback, water_jump };
pub const Player = struct {
    command_ms: i64 = 0,
    teleport_until_ms: i64 = 0,
    teleport_bit: bool = false,
    delta_angles: [3]i32 = @splat(0),
    mode: Mode = .normal,
    ducked: bool = false,
    jump_held: bool = false,
    respawned: bool = false,
    view_height: f32 = 22,
    ground_entity: u16 = 2047,
    water_level: u2 = 0,
    water_type: u32 = 0,
    timer: Timer = .none,
    timer_ms: u32 = 0,
};
pub const Command = struct {
    time_ms: i64,
    angles: v.Vec3,
    forward: i8 = 0,
    right: i8 = 0,
    up: i8 = 0,
    weapon: u8 = 0,
    talking: bool = false,
    attack: bool = false,
    use: bool = false,
};
pub const Parameters = struct {
    speed: f32 = 320,
    gravity: f32 = 800,
    jump_speed: f32 = 270,
    slot: u16,
    mask: u32,
    water_mask: u32,
    solid_mask: u32,
    mins: v.Vec3 = .{ -15, -15, -24 },
    maxs: v.Vec3 = .{ 15, 15, 32 },
    fixed_ms: ?u8 = null,
    snap_velocity: bool = true,
    currents: Currents = .{},
};
/// Content bits of authored currents, supplied by the engine adapter (surfaceflags.h
/// CONTENTS_DK3_CURRENT_*); the motor itself knows no engine values.
pub const Currents = struct {
    east: u32 = 0,
    north: u32 = 0,
    west: u32 = 0,
    south: u32 = 0,
    up: u32 = 0,
    down: u32 = 0,
    pub fn mask(self: Currents) u32 {
        return self.east | self.north | self.west | self.south | self.up | self.down;
    }
    /// The unit push of a current's contents; mixed bits add, as in Gold.
    pub fn direction(self: Currents, contents: u32) v.Vec3 {
        var result: v.Vec3 = @splat(0);
        if (contents & self.east != 0) result[0] += 1;
        if (contents & self.north != 0) result[1] += 1;
        if (contents & self.west != 0) result[0] -= 1;
        if (contents & self.south != 0) result[1] -= 1;
        if (contents & self.up != 0) result[2] += 1;
        if (contents & self.down != 0) result[2] -= 1;
        return result;
    }
};
/// Gold PM_AddCurrents: conveyor belts move walkers at 100 u/s, water
/// currents swimmers at the 400 u/s water speed (half while wading on ground).
pub const conveyor_speed: f32 = 100;
pub const water_current_speed: f32 = 400;
pub const Event = union(enum) { jump, step: f32, land: f32, water_enter, water_leave, water_under, water_surface };
pub const Result = struct {
    events: [256]Event = undefined,
    event_count: usize = 0,
    touches: [32]u16 = undefined,
    touch_count: usize = 0,
    mins: v.Vec3 = .{ -15, -15, -24 },
    maxs: v.Vec3 = .{ 15, 15, 32 },
    slide_abort: ?slide.Abort = null,
    fn event(self: *Result, value: Event) !void {
        if (self.event_count == self.events.len) return error.MovementEventCapacity;
        self.events[self.event_count] = value;
        self.event_count += 1;
    }
};
const Frame = struct {
    player: *Player,
    motion: *slide.State,
    cmd: Command,
    parameters: Parameters,
    service: collision.Collision,
    result: *Result,
    delta: f32,
    ground: ?collision.Trace = null,
    walking: bool = false,
    forward: v.Vec3,
    right: v.Vec3,
    fn trace(self: *Frame, start: v.Vec3, end: v.Vec3) !collision.Trace {
        return self.service.trace(.{ .start = start, .end = end, .mins = self.result.mins, .maxs = self.result.maxs, .slot = self.parameters.slot, .mask = self.parameters.mask });
    }
    fn water(self: *Frame) !void {
        const p = self.player;
        p.water_level = 0;
        p.water_type = 0;
        var point = self.motion.position;
        point[2] += self.parameters.mins[2] + 1;
        const contents = try self.service.contents(point, self.parameters.slot);
        if (contents & self.parameters.water_mask == 0) return;
        p.water_type = contents;
        p.water_level = 1;
        point[2] = self.motion.position[2] + self.parameters.mins[2] + @trunc((p.view_height - self.parameters.mins[2]) / 2);
        if (try self.service.contents(point, self.parameters.slot) & self.parameters.water_mask == 0) return;
        p.water_level = 2;
        point[2] = self.motion.position[2] + p.view_height;
        if (try self.service.contents(point, self.parameters.slot) & self.parameters.water_mask != 0) p.water_level = 3;
    }
    fn bounds(self: *Frame) !void {
        const p = self.player;
        if (p.mode == .dead) {
            self.result.maxs[2] = -8;
            p.view_height = -16;
            return;
        }
        // Swimming down must not enlarge a traveller already shorter than
        // the crouching hull, or move its eye down to its feet.
        if (self.cmd.up < 0 and self.parameters.maxs[2] > 4) p.ducked = true else if (p.ducked) {
            self.result.maxs[2] = self.parameters.maxs[2];
            const standing = try self.trace(self.motion.position, self.motion.position);
            if (!standing.start_solid and !standing.all_solid) p.ducked = false;
        }
        self.result.maxs[2] = if (p.ducked) 4 else self.parameters.maxs[2];
        // Nonhuman controllers can have a much shorter hull. Their head
        // sample must stay inside that hull when measuring immersion.
        const eye_inset = @min(4, (self.parameters.maxs[2] - self.parameters.mins[2]) * 0.25);
        p.view_height = if (p.ducked) -2 else @min(22, @max((self.parameters.mins[2] + self.parameters.maxs[2]) * 0.5, self.parameters.maxs[2] - eye_inset));
    }
    fn groundTrace(self: *Frame) !void {
        var end = self.motion.position;
        end[2] -= 0.25;
        var hit = try self.trace(self.motion.position, end);
        self.walking = false;
        self.ground = null;
        self.player.ground_entity = 2047;
        if (hit.all_solid) {
            var clear = false;
            outer: for (0..3) |x| for (0..3) |y| for (0..3) |z| {
                const point = v.add(self.motion.position, .{ @as(f32, @floatFromInt(x)) - 1, @as(f32, @floatFromInt(y)) - 1, @as(f32, @floatFromInt(z)) - 1 });
                if (!(try self.trace(point, point)).all_solid) {
                    clear = true;
                    break :outer;
                }
            };
            if (!clear) return;
            hit = try self.trace(self.motion.position, end);
        }
        if (hit.fraction == 1 or (self.motion.velocity[2] > 0 and v.dot(self.motion.velocity, hit.normal) > 10)) return;
        self.ground = hit;
        if (hit.normal[2] < 0.7) return;
        self.walking = true;
        self.player.ground_entity = hit.entity;
        if (self.player.timer == .water_jump) {
            self.player.timer = .none;
            self.player.timer_ms = 0;
        }
    }
    fn friction(self: *Frame, flying: bool) void {
        var velocity = self.motion.velocity;
        if (self.walking) velocity[2] = 0;
        const speed = v.length(velocity);
        if (speed < 1) {
            self.motion.velocity[0] = 0;
            self.motion.velocity[1] = 0;
            return;
        }
        var drop: f32 = 0;
        if (self.player.water_level <= 1 and self.walking and self.player.timer != .knockback)
            drop += @max(speed, 100) * 6 * self.delta * self.traction();
        drop += speed * @as(f32, @floatFromInt(self.player.water_level)) * self.delta;
        if (flying) drop += speed * 5 * self.delta;
        self.motion.velocity = v.scale(self.motion.velocity, @max(0, speed - drop) / speed);
    }
    // Converted slick surfaces are authored ice. Low-speed footing retains
    // control; only a fast slide reduces friction and acceleration. Ice does
    // not apply a new gravity force along a supported, walkable slope.
    fn traction(self: *const Frame) f32 {
        return if (self.walking and self.ground.?.slick and v.length(self.motion.velocity) > 170) 0.025 else 1;
    }
    fn currents(self: *Frame) v.Vec3 {
        var push: v.Vec3 = @splat(0);
        const authored = self.parameters.currents;
        if (self.player.water_type & authored.mask() != 0) {
            const speed = if (self.player.water_level == 1 and self.walking) water_current_speed / 2 else water_current_speed;
            push = v.scale(authored.direction(self.player.water_type), speed);
        }
        if (self.walking) if (self.ground) |hit| if (hit.contents & authored.mask() != 0) {
            push = v.add(push, v.scale(authored.direction(hit.contents), conveyor_speed));
        };
        return push;
    }
    fn commandScale(self: *Frame) f32 {
        const axes: v.Vec3 = .{ @floatFromInt(self.cmd.forward), @floatFromInt(self.cmd.right), @floatFromInt(self.cmd.up) };
        const maximum = @max(@abs(axes[0]), @abs(axes[1]), @abs(axes[2]));
        return if (maximum == 0) 0 else self.parameters.speed * maximum / (127 * v.length(axes));
    }
    fn accelerate(self: *Frame, direction: v.Vec3, speed: f32, acceleration: f32) void {
        const add = speed - v.dot(self.motion.velocity, direction);
        if (add > 0) self.motion.velocity = v.add(self.motion.velocity, v.scale(direction, @min(add, acceleration * self.delta * speed)));
    }
    fn slideMove(self: *Frame, gravity: bool, step: bool) !void {
        var context: slide.Context = .{ .service = self.service, .mins = self.result.mins, .maxs = self.result.maxs, .slot = self.parameters.slot, .mask = self.parameters.mask, .delta = self.delta, .gravity = if (gravity) self.parameters.gravity else 0, .ground = if (self.ground) |hit| hit.normal else null, .preserve_velocity = self.player.timer_ms > 0 };
        if (step) try context.step(self.motion) else _ = try context.move(self.motion);
        if (context.abort) |aborted| self.result.slide_abort = aborted;
        self.result.touch_count = context.touch_count;
        @memcpy(self.result.touches[0..context.touch_count], context.touches[0..context.touch_count]);
        if (context.step_height > 2) try self.result.event(.{ .step = context.step_height });
    }
    fn ladder(self: *Frame) !bool {
        if (self.player.mode != .normal or self.player.water_level > 1) return false;
        const horizontal = v.normalize(.{ self.forward[0], self.forward[1], 0 });
        if (v.length(horizontal) == 0) return false;
        for (0..4) |axis| {
            var direction: v.Vec3 = @splat(0);
            direction[axis / 2] = if (axis & 1 == 0) 1 else -1;
            const hit = try self.trace(self.motion.position, v.add(self.motion.position, v.scale(direction, ladder_contact_distance)));
            if (hit.fraction == 1 or !hit.ladder or @abs(hit.normal[2]) >= 0.5) continue;
            const facing = v.dot(horizontal, hit.normal);
            // Dismount follows the complete horizontal intent. Looking along
            // the ladder and strafing outward must release it too; checking
            // only forward/back input consumes an outward jump as a climb.
            const lateral = v.normalize(.{ self.right[0], self.right[1], 0 });
            const travel = v.add(v.scale(horizontal, @floatFromInt(self.cmd.forward)), v.scale(lateral, @floatFromInt(self.cmd.right)));
            if (v.dot(travel, hit.normal) > @max(1, v.length(travel) * 0.1)) return false;
            if (self.cmd.up == 0 and facing > -0.5) return false;
            // Crouch shares the vertical input axis. Looking up and holding
            // forward must still climb with the short hull under a low head;
            // the crouch key alone and downward views retain their descent.
            const crouched_ascent = self.player.ducked and self.cmd.up < 0 and self.cmd.forward > 0 and self.forward[2] > 0.35;
            const climb: f32 = if (crouched_ascent) @floatFromInt(self.cmd.forward) else if (self.cmd.up != 0) @floatFromInt(self.cmd.up) else @as(f32, @floatFromInt(self.cmd.forward)) * (if (self.forward[2] < -0.35) @as(f32, -1) else 1);
            const speed = @min(self.parameters.speed, 140);
            var wish = v.scale(self.right, @as(f32, @floatFromInt(self.cmd.right)) * speed / 127);
            wish[2] = climb * speed / 127;
            wish = v.clip(wish, hit.normal);
            // At a low ladder head the crouched body must step into the
            // opening before its feet clear the last rung. Preserve that
            // inward intent and let the ordinary swept step solver qualify
            // the lip; clipping it away traps the body below the duct.
            const inward = @min(@as(f32, 127), -v.dot(travel, hit.normal));
            if (self.player.ducked and inward > 0) {
                const duck_speed = @min(speed, self.parameters.speed * 0.25);
                wish = v.subtract(wish, v.scale(hit.normal, inward * duck_speed / 127));
            }
            self.motion.velocity = v.add(self.motion.velocity, v.scale(v.add(wish, v.scale(self.motion.velocity, -1)), @min(1, 12 * self.delta)));
            self.player.ground_entity = 2047;
            try self.slideMove(false, true);
            return true;
        }
        return false;
    }
    fn swim(self: *Frame) !void {
        if (self.player.water_level == 2 and self.player.timer_ms == 0) {
            const flat = v.normalize(.{ self.forward[0], self.forward[1], 0 });
            var spot = v.add(self.motion.position, v.scale(flat, 30));
            // The low bank probe belongs inside the traveller's hull. A
            // fixed four-unit offset sits above a very short swimmer and
            // misses a ledge still blocking its feet.
            spot[2] += @min(4, @max(self.parameters.mins[2] + 1, self.parameters.maxs[2] - 4));
            if (try self.service.contents(spot, self.parameters.slot) & self.parameters.solid_mask != 0) {
                spot[2] += 16;
                // Detail, trigger and monster-only clip contents above a
                // ledge do not obstruct this mover's collision mask.
                if (try self.service.contents(spot, self.parameters.slot) & self.parameters.mask == 0) {
                    self.motion.velocity = v.scale(self.forward, 200);
                    self.motion.velocity[2] = water_jump_speed;
                    self.player.timer = .water_jump;
                    self.player.timer_ms = 2000;
                    try self.waterJump();
                    return;
                }
            }
        }
        self.friction(false);
        const scale = self.commandScale();
        var wish = v.add(v.scale(self.forward, scale * @as(f32, @floatFromInt(self.cmd.forward))), v.scale(self.right, scale * @as(f32, @floatFromInt(self.cmd.right))));
        wish[2] += scale * @as(f32, @floatFromInt(self.cmd.up));
        if (scale == 0) wish = .{ 0, 0, -60 };
        wish = v.add(wish, self.currents());
        self.accelerate(v.normalize(wish), @min(v.length(wish), self.parameters.speed * 0.5), 4);
        if (self.ground) |hit| if (v.dot(self.motion.velocity, hit.normal) < 0) {
            self.motion.velocity = v.scale(v.normalize(v.clip(self.motion.velocity, hit.normal)), v.length(self.motion.velocity));
        };
        // Submerged steps still admit the ordinary stair height. A flat
        // slide alone traps swimmers against even an eight-unit tunnel sill.
        try self.slideMove(false, true);
    }
    fn waterJump(self: *Frame) !void {
        try self.slideMove(true, true);
        self.motion.velocity[2] -= self.parameters.gravity * self.delta;
        if (self.motion.velocity[2] < 0) {
            self.player.timer = .none;
            self.player.timer_ms = 0;
        }
    }
    fn fly(self: *Frame, noclip: bool) !void {
        if (noclip) {
            const speed = v.length(self.motion.velocity);
            self.motion.velocity = if (speed < 1) @splat(0) else v.scale(self.motion.velocity, @max(0, speed - @max(speed, 100) * 9 * self.delta) / speed);
        } else self.friction(true);
        const scale = self.commandScale();
        var wish = v.add(v.scale(self.forward, scale * @as(f32, @floatFromInt(self.cmd.forward))), v.scale(self.right, scale * @as(f32, @floatFromInt(self.cmd.right))));
        wish[2] += scale * @as(f32, @floatFromInt(self.cmd.up));
        self.accelerate(v.normalize(wish), v.length(wish), if (noclip) 10 else 8);
        if (noclip) self.motion.position = v.add(self.motion.position, v.scale(self.motion.velocity, self.delta)) else try self.slideMove(false, true);
    }
    fn walkAir(self: *Frame) !void {
        if (self.walking and self.cmd.up >= 10 and !self.player.respawned) {
            if (self.player.jump_held) self.cmd.up = 0 else {
                self.player.jump_held = true;
                self.player.ground_entity = 2047;
                self.walking = false;
                self.ground = null;
                self.motion.velocity[2] = self.parameters.jump_speed;
                try self.result.event(.jump);
            }
        }
        if (self.walking and self.ground.?.slick and self.player.timer != .knockback)
            self.motion.velocity[2] = 0;
        self.friction(false);
        var forward = v.normalize(.{ self.forward[0], self.forward[1], 0 });
        var right = v.normalize(.{ self.right[0], self.right[1], 0 });
        if (self.walking) {
            forward = v.normalize(v.clip(forward, self.ground.?.normal));
            right = v.normalize(v.clip(right, self.ground.?.normal));
        }
        const wish = v.add(v.scale(forward, @floatFromInt(self.cmd.forward)), v.scale(right, @floatFromInt(self.cmd.right)));
        var speed = v.length(wish) * self.commandScale();
        if (self.walking and self.player.ducked) speed = @min(speed, self.parameters.speed * 0.25);
        if (self.walking and self.player.water_level > 0) speed = @min(speed, self.parameters.speed * (1 - 0.5 * @as(f32, @floatFromInt(self.player.water_level)) / 3));
        const knocked = self.walking and self.player.timer == .knockback;
        var wish_velocity = v.add(v.scale(v.normalize(wish), speed), self.currents());
        // Gold clamps the combined wish, current included, to the running speed.
        if (v.length(wish_velocity) > self.parameters.speed) wish_velocity = v.scale(v.normalize(wish_velocity), self.parameters.speed);
        self.accelerate(v.normalize(wish_velocity), v.length(wish_velocity), if (self.walking and !knocked) 10 * self.traction() else 1);
        if (knocked) self.motion.velocity[2] -= self.parameters.gravity * self.delta;
        if (self.ground) |hit| {
            const before = v.length(self.motion.velocity);
            const tangent = v.subtract(self.motion.velocity, v.scale(hit.normal, v.dot(self.motion.velocity, hit.normal)));
            self.motion.velocity = v.clip(self.motion.velocity, hit.normal);
            // Overclip leaves a tiny outward normal component. A lift catching
            // a stationary falling player must not normalize that residue back
            // into the full falling speed and launch the rider upward.
            if (self.walking) self.motion.velocity = if (v.length(tangent) < 0.001) @splat(0) else v.scale(v.normalize(self.motion.velocity), before);
        }
        if (self.walking and self.motion.velocity[0] == 0 and self.motion.velocity[1] == 0) return;
        try self.slideMove(!self.walking, true);
    }
};

pub const AfterStep = struct {
    context: *anyopaque,
    run_fn: *const fn (*anyopaque, *Player, *slide.State, Command, u32) anyerror!void,
};
pub fn run(player: *Player, motion: *slide.State, command: Command, parameters: Parameters, service: collision.Collision) !Result {
    return runWithHook(player, motion, command, parameters, service, null);
}
pub fn runWithHook(player: *Player, motion: *slide.State, command: Command, parameters: Parameters, service: collision.Collision, hook: ?AfterStep) !Result {
    if (parameters.fixed_ms) |ms| if (ms < 1 or ms > 200) return error.InvalidMovementStep;
    if (!std.math.isFinite(parameters.speed) or parameters.speed < 0 or !std.math.isFinite(parameters.gravity) or !std.math.isFinite(parameters.jump_speed)) return error.InvalidMovementParameters;
    for (command.angles) |angle| if (!std.math.isFinite(angle)) return error.InvalidMovementParameters;
    for (parameters.mins, parameters.maxs) |low, high| if (!std.math.isFinite(low) or !std.math.isFinite(high) or low >= high) return error.InvalidMovementBounds;
    var result: Result = .{ .mins = parameters.mins, .maxs = parameters.maxs };
    result.maxs[2] = if (player.mode == .dead) -8 else if (player.ducked) 4 else parameters.maxs[2];
    if (command.time_ms < player.command_ms) return result;
    const elapsed = std.math.sub(i64, command.time_ms, player.command_ms) catch return error.InvalidMovementTime;
    if (elapsed > 1000) player.command_ms = command.time_ms - 1000;
    var cmd = command;
    if (cmd.talking or player.mode == .dead) {
        cmd.forward = 0;
        cmd.right = 0;
        cmd.up = 0;
    }
    if (!cmd.attack and !cmd.use) player.respawned = false;
    const basis = v.basis(command.angles);
    while (player.command_ms < command.time_ms) {
        const milliseconds: u32 = @intCast(@min(command.time_ms - player.command_ms, parameters.fixed_ms orelse 66));
        player.command_ms += milliseconds;
        if (cmd.up < 10) player.jump_held = false;
        if (player.mode == .frozen) {
            if (hook) |after| {
                var step_command = cmd;
                step_command.time_ms = player.command_ms;
                try after.run_fn(after.context, player, motion, step_command, milliseconds);
            }
            continue;
        }
        var frame: Frame = .{ .player = player, .motion = motion, .cmd = cmd, .parameters = parameters, .service = service, .result = &result, .delta = @as(f32, @floatFromInt(milliseconds)) * 0.001, .forward = basis.forward, .right = basis.right };
        if (player.mode == .noclip or player.mode == .spectator) {
            if (player.mode == .spectator) try frame.bounds() else player.view_height = 22;
            try frame.fly(player.mode == .noclip);
            player.timer_ms -|= milliseconds;
            if (player.timer_ms == 0) player.timer = .none;
            continue;
        }
        try frame.water();
        const prior_water = player.water_level;
        try frame.bounds();
        const prior_ground = player.ground_entity;
        const prior_velocity = motion.velocity;
        try frame.groundTrace();
        if (player.mode == .dead and frame.walking) motion.velocity = v.scale(v.normalize(motion.velocity), @max(0, v.length(motion.velocity) - 20));
        player.timer_ms -|= milliseconds;
        if (player.timer_ms == 0) player.timer = .none;
        if (player.timer == .water_jump) try frame.waterJump() else if (!try frame.ladder()) {
            if (player.water_level > 1) try frame.swim() else try frame.walkAir();
        }
        try frame.groundTrace();
        try frame.water();
        if (prior_ground == 2047 and player.ground_entity != 2047) {
            try result.event(.{ .land = @max(0, -prior_velocity[2]) });
            if (prior_velocity[2] < -200) {
                player.timer = .land;
                player.timer_ms = 250;
            }
        }
        if (prior_water == 0 and player.water_level > 0) try result.event(.water_enter);
        if (prior_water > 0 and player.water_level == 0) try result.event(.water_leave);
        if (prior_water != 3 and player.water_level == 3) try result.event(.water_under);
        if (prior_water == 3 and player.water_level != 3) try result.event(.water_surface);
        if (hook) |after| {
            var step_command = cmd;
            step_command.time_ms = player.command_ms;
            try after.run_fn(after.context, player, motion, step_command, milliseconds);
        }
        if (parameters.snap_velocity) for (&motion.velocity) |*axis| {
            axis.* = v.snap(axis.*);
        };
        if (player.jump_held) cmd.up = 20;
    }
    return result;
}

test "immersion samples the actual small hull while retaining the ordinary standing eye" {
    const Fixture = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
        }
        fn contents(_: *anyopaque, point: v.Vec3, _: u16) !u32 {
            return if (point[2] < 10) 2 else 0;
        }
    };
    var context: u8 = 0;
    var player: Player = .{};
    var motion: slide.State = .{ .position = @splat(0), .velocity = @splat(0) };
    var result: Result = .{ .mins = .{ -8, -8, -8 }, .maxs = .{ 8, 8, 8 } };
    var frame: Frame = .{ .player = &player, .motion = &motion, .cmd = .{ .time_ms = 0, .angles = @splat(0) }, .parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .mins = result.mins, .maxs = result.maxs }, .service = .{ .context = &context, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents }, .result = &result, .delta = 0.05, .forward = @splat(0), .right = @splat(0) };
    try frame.bounds();
    try frame.water();
    try std.testing.expectEqual(@as(f32, 4), player.view_height);
    try std.testing.expectEqual(@as(u8, 3), player.water_level);
    frame.parameters.mins = .{ -15, -15, -24 };
    frame.parameters.maxs = .{ 15, 15, 32 };
    try frame.bounds();
    try frame.water();
    try std.testing.expectEqual(@as(f32, 22), player.view_height);
    try std.testing.expectEqual(@as(u8, 2), player.water_level);
    frame.parameters.mins = .{ -2, -2, -2 };
    frame.parameters.maxs = .{ 2, 2, 2 };
    frame.cmd.up = -127;
    try frame.bounds();
    try std.testing.expect(!player.ducked);
    try std.testing.expectEqual(@as(f32, 2), result.maxs[2]);
    try std.testing.expectEqual(@as(f32, 1), player.view_height);
}

test "an outward strafe jump leaves a ladder while an upward command keeps climbing" {
    const Fixture = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            var hit: collision.Trace = .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const wall = 16 - request.maxs[0];
            if (request.end[0] > wall and request.start[0] <= wall) {
                hit.fraction = (wall - request.start[0]) / (request.end[0] - request.start[0]);
                hit.normal = .{ -1, 0, 0 };
                hit.ladder = true;
            }
            const bottom = request.start[2] + request.mins[2];
            const end_bottom = request.end[2] + request.mins[2];
            if (bottom >= 0 and end_bottom < 0) {
                const fraction = bottom / (bottom - end_bottom);
                if (fraction <= hit.fraction) {
                    hit.fraction = fraction;
                    hit.normal = .{ 0, 0, 1 };
                    hit.ladder = false;
                }
            }
            hit.end = v.add(request.start, v.scale(v.subtract(request.end, request.start), hit.fraction));
            return hit;
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var fixture: u8 = 0;
    const service: collision.Collision = .{ .context = &fixture, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents };
    const parameters: Parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1 };
    var leaving: Player = .{};
    var motion: slide.State = .{ .position = .{ 0, 0, 24 }, .velocity = @splat(0) };
    _ = try run(&leaving, &motion, .{ .time_ms = 50, .angles = .{ 0, 90, 0 }, .right = -127, .up = 127 }, parameters, service);
    try std.testing.expect(leaving.jump_held);
    try std.testing.expect(motion.velocity[2] > 140);
    try std.testing.expect(motion.position[0] < 0);
    var climbing: Player = .{};
    motion = .{ .position = .{ 0, 0, 24 }, .velocity = @splat(0) };
    _ = try run(&climbing, &motion, .{ .time_ms = 50, .angles = .{ 0, 90, 0 }, .up = 127 }, parameters, service);
    try std.testing.expect(!climbing.jump_held);
    try std.testing.expect(motion.velocity[2] > 0 and motion.velocity[2] <= 140);
    var ducking_up: Player = .{};
    motion = .{ .position = .{ 0, 0, 64 }, .velocity = @splat(0) };
    _ = try run(&ducking_up, &motion, .{ .time_ms = 50, .angles = .{ -45, 0, 0 }, .forward = 127, .up = -127 }, parameters, service);
    try std.testing.expect(ducking_up.ducked);
    try std.testing.expect(motion.velocity[2] > 0);
    var ducking_down: Player = .{};
    motion = .{ .position = .{ 0, 0, 64 }, .velocity = @splat(0) };
    _ = try run(&ducking_down, &motion, .{ .time_ms = 50, .angles = .{ 45, 0, 0 }, .forward = 127, .up = -127 }, parameters, service);
    try std.testing.expect(ducking_down.ducked);
    try std.testing.expect(motion.velocity[2] < 0);
}

test "a short surface swimmer probes the bank inside its own hull" {
    const Fixture = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
        }
        fn contents(_: *anyopaque, point: v.Vec3, _: u16) !u32 {
            if (point[0] >= 29 and point[2] < 32) return 1;
            return if (point[2] < 32) 2 else 0;
        }
    };
    var context: u8 = 0;
    var player: Player = .{ .water_level = 2 };
    var motion: slide.State = .{ .position = .{ 0, 0, 31 }, .velocity = @splat(0) };
    var result: Result = .{ .mins = @splat(-2), .maxs = @splat(2) };
    var frame: Frame = .{ .player = &player, .motion = &motion, .cmd = .{ .time_ms = 50, .angles = @splat(0), .forward = 127 }, .parameters = .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1, .mins = result.mins, .maxs = result.maxs }, .service = .{ .context = &context, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents }, .result = &result, .delta = 0.05, .forward = .{ 1, 0, 0 }, .right = .{ 0, -1, 0 } };
    try frame.swim();
    try std.testing.expectEqual(Timer.water_jump, player.timer);
    try std.testing.expect(motion.velocity[2] > 0);
}

test "uncrouching requires a clear standing hull even without an all-solid trace" {
    const Fixture = struct {
        fn trace(_: *anyopaque, request: collision.Request) !collision.Trace {
            if (request.maxs[2] > 4) return .{ .fraction = 0, .end = request.start, .normal = @splat(0), .start_solid = true };
            const a = request.start[2] + request.mins[2];
            const b = request.end[2] + request.mins[2];
            if (b >= 0) return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const fraction = if (a > 0) a / (a - b) else 0;
            return .{ .fraction = fraction, .end = v.add(request.start, v.scale(v.subtract(request.end, request.start), fraction)), .normal = .{ 0, 0, 1 }, .entity = 2046 };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
    };
    var fixture: u8 = 0;
    var player: Player = .{ .command_ms = 950, .ducked = true };
    var motion: slide.State = .{ .position = .{ 0, 0, 24 }, .velocity = @splat(0) };
    const result = try run(&player, &motion, .{ .time_ms = 1000, .angles = @splat(0) }, .{ .slot = 0, .mask = 1, .water_mask = 2, .solid_mask = 1 }, .{ .context = &fixture, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents });
    try std.testing.expect(player.ducked);
    try std.testing.expectEqual(@as(f32, 4), result.maxs[2]);
}
