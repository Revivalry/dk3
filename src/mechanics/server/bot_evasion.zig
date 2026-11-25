// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Bot survival movement: what a careful player does under fire. Incoming
//! hostile projectiles and forecast spray impacts become threats; the bot picks
//! a walkable step that maximises its distance from them. Only movement input is
//! produced; damage, collision and projectile flight stay with the simulation.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const c = @import("../../engine/abi.zig").c;
const engine = @import("../../engine/server.zig");
const v = @import("../../core/domain/vector.zig");
const nav = @import("../../core/domain/navigation.zig");
const Frame = @import("bot_pilot.zig").Frame;
/// A predicted hit: where and when it lands, and how far its damage reaches.
pub const Threat = struct { point: v.Vec3, eta: f32, radius: f32 = 96, field: bool = false, transient: bool = false, bounds: ?@import("../../core/domain/navigation_input.zig").Bounds = null, contact: ?@import("../../core/domain/navigation_input.zig").Bounds = null };
pub const Threats = struct {
    items: [16]Threat = undefined,
    len: usize = 0,
    overflow: bool = false,
    fn add(self: *Threats, threat: Threat) void {
        if (self.len < self.items.len) {
            self.items[self.len] = threat;
            self.len += 1;
        } else self.overflow = true;
    }
    pub fn slice(self: *const Threats) []const Threat {
        return self.items[0..self.len];
    }
    pub fn keepFields(self: *Threats) void {
        var count: usize = 0;
        for (self.slice()) |threat| if (threat.field) {
            self.items[count] = threat;
            count += 1;
        };
        self.len = count;
    }
    pub fn removeFields(self: *Threats) void {
        var count: usize = 0;
        for (self.slice()) |threat| if (!threat.field or threat.transient) {
            self.items[count] = threat;
            count += 1;
        };
        self.len = count;
    }
};
/// A validated physical corridor accounts for persistent contact fields through
/// the actual motor. Recheck live fields before allowing that route to replace
/// a straight-velocity evasion forecast; incoming missiles remain independent.
pub fn corridorClearsFields(frame: Frame, position: v.Vec3, point: v.Vec3, threats: *const Threats) !bool {
    if (threats.overflow) return false;
    var parameters = frame.motor orelse return false;
    parameters.mask &= ~@as(u32, c.CONTENTS_BODY);
    const forecast = @import("../domain/motion_forecast.zig");
    var fields: [16]forecast.Field = undefined;
    var count: usize = 0;
    for (threats.slice()) |threat| if (threat.field and !threat.transient) {
        fields[count] = .{ .point = threat.point, .radius = threat.radius, .bounds = threat.bounds, .contact = threat.contact };
        count += 1;
    };
    if (count == 0) return false;
    return (try forecast.walk(frame.state, .{ .position = position, .velocity = (try frame.world.get(frame.entity, data.Velocity)).linear }, point, parameters, frame.collision, frame.liquid_mask, &.{}, fields[0..count])).safe;
}
/// Hostile shots that will pass close to the player within 1.5 s, and spray
/// that the server forecasts to land near it within 2.5 s.
pub fn gather(frame: Frame, position: v.Vec3) !Threats {
    var result: Threats = .{};
    const world = frame.world;
    const self_id = try world.persistentId(frame.entity);
    {
        var query = world.queryAccess(data.World.mask(.{ data.Projectile, data.Transform, data.Velocity }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.read(data.Projectile), view.read(data.Transform), view.read(data.Velocity)) |shot, pose, velocity| {
            if (shot.stuck) continue;
            if (shot.resting) {
                const entry = @import("weapon_catalog").find(shot.weapon) orelse continue;
                if (entry.spec.projectile.contact_when_resting and nav.horizontalDistance(position, pose.position) < 160)
                    result.add(.{ .point = pose.position, .eta = 0.4, .radius = 80, .field = true });
                continue;
            }
            // A returned ricochet is dangerous to its shooter too. Initial
            // outgoing rounds still leave the owner's movement alone.
            if (shot.owner == self_id and shot.bounces == 0) continue;
            const speed2 = v.dot(velocity.linear, velocity.linear);
            if (speed2 < 1) continue;
            const relative = v.subtract(position, pose.position);
            const time = v.dot(relative, velocity.linear) / speed2;
            if (time < 0 or time > 1.5) continue;
            const closest = v.add(pose.position, v.scale(velocity.linear, time));
            if (v.length(v.subtract(closest, position)) > 96) continue;
            result.add(.{ .point = closest, .eta = time });
        };
    }
    // Actor-launched missiles (sludge globs, fireballs, rockets) are their
    // own attack entities, not player projectiles: dodge them alike.
    {
        var query = world.queryAccess(data.World.mask(.{ data.ActorAttack, data.Transform, data.Velocity }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.read(data.ActorAttack), view.read(data.Transform), view.read(data.Velocity)) |attack, pose, velocity| {
            if (attack.owner == self_id) continue;
            const speed2 = v.dot(velocity.linear, velocity.linear);
            if (speed2 < 1) continue;
            const relative = v.subtract(position, pose.position);
            const time = v.dot(relative, velocity.linear) / speed2;
            if (time < 0 or time > 1.5) continue;
            const closest = v.add(pose.position, v.scale(velocity.linear, time));
            if (v.length(v.subtract(closest, position)) > 96) continue;
            result.add(.{ .point = closest, .eta = time });
        };
    }
    // Actor lasers (an inmater's, a lasergat's, a deathsphere's bolts) fly
    // as their own entities too.
    {
        var query = world.queryAccess(data.World.mask(.{ data.ActorLaser, data.Transform, data.Velocity }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.read(data.ActorLaser), view.read(data.Transform), view.read(data.Velocity)) |laser, pose, velocity| {
            if (laser.owner == self_id) continue;
            const speed2 = v.dot(velocity.linear, velocity.linear);
            if (speed2 < 1) continue;
            const relative = v.subtract(position, pose.position);
            const time = v.dot(relative, velocity.linear) / speed2;
            if (time < 0 or time > 1.5) continue;
            const closest = v.add(pose.position, v.scale(velocity.linear, time));
            if (v.length(v.subtract(closest, position)) > 96) continue;
            result.add(.{ .point = closest, .eta = time, .radius = 48 });
        };
    }
    // Slow authored missiles burst on contact with the player as well as on
    // geometry: dodge their closest approach, not only their floor impact.
    inline for (hazards) |Class| if (@hasDecl(Class, "contact_missile")) {
        const Missile = Class.contact_missile;
        var query = world.queryAccess(data.World.mask(.{ Missile, data.Transform, data.Velocity }), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.read(data.Transform), view.read(data.Velocity)) |pose, velocity| {
            const speed2 = v.dot(velocity.linear, velocity.linear);
            if (speed2 < 1) continue;
            const relative = v.subtract(position, pose.position);
            const time = v.dot(relative, velocity.linear) / speed2;
            if (time < 0 or time > 2.5) continue;
            const closest = v.add(pose.position, v.scale(velocity.linear, time));
            if (v.length(v.subtract(closest, position)) > 200) continue;
            result.add(.{ .point = closest, .eta = time, .radius = 256 });
        };
    };
    inline for (hazards) |Class| if (@hasDecl(Class, "contact_hazard") and @hasDecl(Class, "contactForecast")) {
        const velocity = (try world.get(frame.entity, data.Velocity)).linear;
        var query = world.queryAccess(data.World.mask(.{Class.contact_hazard}), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities()) |entity| {
            if (try Class.contactForecast(world, entity, position, velocity, frame.now)) |prediction| {
                if (prediction.eta < 0 or prediction.eta > 2.5) continue;
                result.add(.{ .point = prediction.point, .eta = prediction.eta, .radius = prediction.radius, .field = prediction.field, .transient = true });
            }
        };
    };
    inline for (hazards) |Class| if (@hasDecl(Class, "hazard") and @hasDecl(Class, "forecast")) try forecastHazards(Class, world, frame, position, &result, false);
    return result;
}
pub fn lookAway(frame: Frame) !?v.Vec3 {
    inline for (hazards) |Class| if (@hasDecl(Class, "avoidLook")) {
        var query = frame.world.queryAccess(data.World.mask(.{Class.hazard}), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities()) |entity| {
            if (try Class.avoidLook(frame.world, entity, frame.entity, frame.now)) |point| return point;
        };
    };
    return null;
}
/// Adds the predicted impacts of one hazard class's entities.
pub fn persistent(frame: Frame, position: v.Vec3) !Threats {
    var result: Threats = .{};
    inline for (hazards) |Class| if (@hasDecl(Class, "hazard") and @hasDecl(Class, "forecast")) try forecastHazards(Class, frame.world, frame, position, &result, true);
    return result;
}
/// The normal arrival disk may straddle a contact field even when its centre
/// is unsafe. Use a clear supported point inside that same disk; never enlarge
/// the destination's ordinary sixteen-unit arrival radius.
pub fn safeArrival(frame: Frame, position: v.Vec3, goal: v.Vec3) !v.Vec3 {
    if (nav.horizontalDistance(position, goal) > 256) return goal;
    const fields = try persistent(frame, goal);
    if (fields.overflow or exposureAtSpeed(goal, goal, fields.slice(), 0) == 0) return goal;
    var best = goal;
    var cost = std.math.inf(f32);
    for (fields.slice()) |field| if (field.bounds) |box| {
        for (0..2) |axis| for ([_]f32{ box.mins[axis] - 0.125, box.maxs[axis] + 0.125 }) |edge| {
            var point = goal;
            point[axis] = edge;
            if (nav.horizontalDistance(point, goal) > 16 or exposureAtSpeed(point, point, fields.slice(), 0) > 0) continue;
            // Moving sideways on a ramp changes the supported height. Probe
            // that floor instead of requiring the goal's exact height there.
            const support = try frame.collision.trace(.{ .start = v.add(point, .{ 0, 0, 1 }), .end = v.add(point, .{ 0, 0, -24 }), .mins = frame.hull.mins, .maxs = frame.hull.maxs, .slot = frame.slot, .mask = frame.motionMask() & ~@as(u32, c.CONTENTS_BODY) });
            if (support.start_solid or support.all_solid or support.fraction == 1 or support.normal[2] < 0.7) continue;
            point = support.end;
            if (@abs(point[2] - goal[2]) > 24 or exposureAtSpeed(point, point, fields.slice(), 0) > 0) continue;
            const distance = v.length(v.subtract(point, position));
            if (distance < cost) {
                best = point;
                cost = distance;
            }
        };
    };
    return best;
}
fn forecastHazards(comptime Class: type, world: *data.World, frame: Frame, position: v.Vec3, result: *Threats, fields_only: bool) !void {
    var hazards_found = world.queryAccess(data.World.mask(.{Class.hazard}), 0, 0);
    defer hazards_found.deinit();
    while (hazards_found.next()) |view| for (view.entities()) |entity| {
        const prediction = try Class.forecast(world, entity, frame.now);
        const forecast = prediction orelse continue;
        const field = if (@hasField(@TypeOf(forecast), "field")) forecast.field else false;
        if (fields_only and !field) continue;
        if (forecast.eta < 0 or forecast.eta > 2.5) continue;
        const dx = forecast.point[0] - position[0];
        const dy = forecast.point[1] - position[1];
        if (dx * dx + dy * dy > 400 * 400 or @abs(forecast.point[2] - position[2]) > 160) continue;
        if (!fields_only and engine.integer("developer") > 1 and @mod(frame.now, 500) == 0) {
            const pose = (try world.get(entity, data.Transform)).position;
            var text: [256]u8 = undefined;
            engine.print(try std.fmt.bufPrintZ(&text, "dk3 {s}: t={d} event=spray id={d} pos={d:.0},{d:.0},{d:.0} forecast={d} eta={d:.2} impact={d:.0},{d:.0},{d:.0}\n", .{ frame.label, frame.now, try world.persistentId(entity), pose[0], pose[1], pose[2], @intFromBool(prediction != null), if (prediction) |value| value.eta else -1, if (prediction) |value| value.point[0] else 0, if (prediction) |value| value.point[1] else 0, if (prediction) |value| value.point[2] else 0 }));
        }
        const contact: ?@import("../../core/domain/navigation_input.zig").Bounds = if (@hasField(@TypeOf(forecast), "bounds")) forecast.bounds else null;
        var maxs = frame.hull.maxs;
        if (frame.state.ducked) maxs[2] = 4;
        const contact_field: @import("../domain/motion_forecast.zig").Field = .{ .point = forecast.point, .radius = if (@hasField(@TypeOf(forecast), "radius")) forecast.radius else 256, .contact = contact };
        const bounds = contact_field.forHull(frame.hull.mins, maxs).bounds;
        result.add(.{ .point = forecast.point, .eta = forecast.eta, .radius = if (@hasField(@TypeOf(forecast), "radius")) forecast.radius else 256, .field = field, .bounds = bounds, .contact = contact });
    };
}
/// Walkable step (16 headings, three lengths) with the least expected splash
/// damage at the moment each threat lands, or null when standing still is as
/// good. A held fight dodges inside a wide tether around its position.
pub fn inside(arena: ?[2][2]f32, point: v.Vec3) bool {
    const box = arena orelse return true;
    return point[0] >= box[0][0] and point[0] <= box[1][0] and point[1] >= box[0][1] and point[1] <= box[1][1];
}
pub fn escape(frame: Frame, position: v.Vec3, velocity: v.Vec3, threats: []const Threat, leash: ?v.Vec3, arena: ?[2][2]f32, attempt: u32, avoid: *const fn (Frame, v.Vec3, v.Vec3) anyerror!bool) !?v.Vec3 {
    var best: ?v.Vec3 = null;
    // Compare against both staying and continuing the current motion. A
    // harmless forecast must not cause a turn merely for the tie-break bonus.
    const speed = if (frame.motor) |parameters| parameters.speed else 280;
    const risk = @max(exposureAtSpeed(position, position, threats, speed), exposureAtSpeed(position, v.add(position, v.scale(velocity, 1.5)), threats, speed));
    if (risk <= 0) return null;
    var best_exposure = risk - 0.05;
    const running = v.normalize(.{ velocity[0], velocity[1], 0 });
    for ([_]f32{ 80, 160, 288, 416 }) |reach| for (0..16) |slot| {
        // Attempt-dependent candidate order changes tie-breaks between retries.
        const index = (slot + attempt * 5) % 16;
        const angle = @as(f32, @floatFromInt(index)) * std.math.pi / 8;
        var point = v.add(position, .{ @cos(angle) * reach, @sin(angle) * reach, 0 });
        // Inside an arena, a step that would leave it ends at its boundary.
        if (arena) |box| {
            point[0] = std.math.clamp(point[0], box[0][0], box[1][0]);
            point[1] = std.math.clamp(point[1], box[0][1], box[1][1]);
        }
        const step = v.subtract(point, position);
        if (nav.horizontalDistance(step, @splat(0)) < 40) continue;
        // Shots are led at the current velocity: favour breaking the line.
        const turning: f32 = if (v.dot(running, v.normalize(step)) < 0.7) 0.08 else 0;
        const value = exposureAtSpeed(position, point, threats, speed) - turning;
        if (value >= best_exposure) continue;
        if (leash) |anchor| if (@sqrt((point[0] - anchor[0]) * (point[0] - anchor[0]) + (point[1] - anchor[1]) * (point[1] - anchor[1])) > 320) continue;
        if (!inside(arena, point)) continue;
        if (!try walkable(frame, position, point) or try avoid(frame, position, step)) continue;
        best_exposure = value;
        best = step;
    };
    return best;
}
/// Shot by something the player cannot see to shoot back at: the nearest
/// walkable step (8 headings, two lengths) out of its line of fire, if any.
pub fn cover(frame: Frame, position: v.Vec3, shooter: v.Vec3) !?v.Vec3 {
    const collision = frame.collision;
    var best: ?v.Vec3 = null;
    var shortest: f32 = std.math.inf(f32);
    for ([_]f32{ 64, 128 }) |length| for (0..8) |heading| {
        const angle = @as(f32, @floatFromInt(heading)) * std.math.pi / 4;
        const step: v.Vec3 = .{ @cos(angle) * length, @sin(angle) * length, 0 };
        const spot = v.add(position, step);
        if (!try walkable(frame, position, spot)) continue;
        // Hidden when no line runs from the shooter to the head or the waist.
        var seen = false;
        for ([_]f32{ 24, 0 }) |height| {
            const line = try collision.trace(.{ .start = shooter, .end = v.add(spot, .{ 0, 0, height }), .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = c.MASK_SOLID });
            if (line.fraction == 1) seen = true;
        }
        if (seen or length >= shortest) continue;
        shortest = length;
        best = step;
    };
    return best;
}
/// Sum of quadratic splash fractions at each impact, running toward
/// `destination` at about player speed from `position`.
fn exposure(position: v.Vec3, destination: v.Vec3, threats: []const Threat) f32 {
    return exposureAtSpeed(position, destination, threats, 280);
}
fn exposureAtSpeed(position: v.Vec3, destination: v.Vec3, threats: []const Threat, speed: f32) f32 {
    const distance = @max(1, @sqrt((destination[0] - position[0]) * (destination[0] - position[0]) + (destination[1] - position[1]) * (destination[1] - position[1])));
    var total: f32 = 0;
    for (threats) |threat| {
        const fraction = @min(1, @max(0, threat.eta - 0.1) * speed / distance);
        const x = position[0] + (destination[0] - position[0]) * fraction - threat.point[0];
        const y = position[1] + (destination[1] - position[1]) * fraction - threat.point[1];
        const z = position[2] - threat.point[2];
        if (threat.bounds) |box| {
            const point = v.add(threat.point, .{ x, y, z });
            var inside_box = true;
            for (0..3) |axis| if (point[axis] <= box.mins[axis] or point[axis] >= box.maxs[axis]) {
                inside_box = false;
            };
            if (inside_box) total += 1;
        } else total += @max(0, 1 - (x * x + y * y + z * z) / (threat.radius * threat.radius));
    }
    return total;
}
/// If no supported escape exists, wait before entering a persistent contact field.
pub fn fieldBlocks(position: v.Vec3, movement: v.Vec3, threats: []const Threat) bool {
    return fieldBlocksAtSpeed(position, movement, threats, 280);
}
pub fn fieldBlocksAtSpeed(position: v.Vec3, movement: v.Vec3, threats: []const Threat, speed: f32) bool {
    const destination = v.add(position, v.scale(v.normalize(movement), @min(420, v.length(movement))));
    for (threats) |threat| if (threat.field) {
        const one = [_]Threat{threat};
        if (exposureAtSpeed(position, destination, &one, speed) > exposureAtSpeed(position, position, &one, speed) + 0.05) return true;
    };
    return false;
}
test "precise routes retain resting contact hazards and wait before walking into them" {
    var threats: Threats = .{};
    threats.add(.{ .point = .{ 96, 0, -16 }, .eta = 0.4, .radius = 80, .field = true });
    threats.add(.{ .point = .{ 0, 96, 0 }, .eta = 0.4 });
    threats.keepFields();
    try std.testing.expectEqual(@as(usize, 1), threats.len);
    try std.testing.expect(fieldBlocks(@splat(0), .{ 96, 0, 0 }, threats.slice()));
    try std.testing.expect(!fieldBlocks(@splat(0), .{ -96, 0, 0 }, threats.slice()));
    try std.testing.expect(!fieldBlocks(@splat(0), .{ 8, 0, 0 }, threats.slice()));
}
test "a contact field threatens the body rather than another floor" {
    const t = std.testing;
    const above = [_]Threat{.{ .point = .{ 0, 0, 128 }, .eta = 0.5, .radius = 32, .field = true }};
    try t.expectEqual(@as(f32, 0), exposure(@splat(0), @splat(0), &above));
    const touching = [_]Threat{.{ .point = .{ 0, 0, -16 }, .eta = 0.5, .radius = 32, .field = true }};
    try t.expectApproxEqAbs(@as(f32, 0.75), exposure(@splat(0), @splat(0), &touching), 0.001);
    try t.expectEqual(@as(f32, 0), exposure(@splat(0), .{ 80, 0, 0 }, &touching));
}
test "a supported corridor does not clear a moving contact forecast" {
    var threats: Threats = .{};
    threats.add(.{ .point = @splat(0), .eta = 0.5, .field = true });
    threats.add(.{ .point = .{ 80, 0, 0 }, .eta = 0.5, .field = true, .transient = true });
    threats.keepFields();
    threats.removeFields();
    try std.testing.expectEqual(@as(usize, 1), threats.len);
    try std.testing.expect(threats.items[0].transient);
}
/// A step is walkable when the hull can move there and every point along it
/// (each 48 units) has supported floor within a stair's drop, without slime,
/// lava, nitro or water: a sweep alone passes straight over gaps and ledges.
pub fn walkable(frame: Frame, from: v.Vec3, to: v.Vec3) !bool {
    if (!try supported(frame, from, to)) return false;
    const collision = frame.collision;
    const hull_mins = frame.hull.mins;
    const hull_maxs = frame.hull.maxs;
    const sweep = try collision.trace(.{ .start = from, .end = to, .mins = hull_mins, .maxs = hull_maxs, .slot = frame.slot, .mask = frame.motionMask() });
    // Knockback from the very blasts being dodged must not carry the player
    // over an edge: the destination needs floor all around it as well.
    for ([_]v.Vec3{ .{ 40, 0, 0 }, .{ -40, 0, 0 }, .{ 0, 40, 0 }, .{ 0, -40, 0 } }) |offset| {
        const around = v.add(sweep.end, offset);
        const floor = try collision.trace(.{ .start = around, .end = v.add(around, .{ 0, 0, -48 }), .mins = .{ -4, -4, hull_mins[2] }, .maxs = .{ 4, 4, 8 }, .slot = frame.slot, .mask = frame.motionMask() });
        if (!floor.start_solid and floor.fraction == 1) return false;
    }
    return true;
}
/// Any step the motor takes off its route (sidestep, charge, unstick) keeps
/// floor under the player along the whole way and stays out of liquids.
pub fn supported(frame: Frame, from: v.Vec3, to: v.Vec3) !bool {
    return supportedUnder(frame, from, to, frame.hull.maxs[2]);
}
/// `supported` for a hull `head` high (a crouched player: a crawlway).
pub fn supportedUnder(frame: Frame, from: v.Vec3, to: v.Vec3, head: f32) !bool {
    return supportedDrop(frame, from, to, head, 36);
}
/// Dismounting a body can land one body-height below; liquids stay excluded.
pub fn supportedDrop(frame: Frame, from: v.Vec3, to: v.Vec3, head: f32, drop: f32) !bool {
    const collision = frame.collision;
    const hull_mins = frame.hull.mins;
    const hull_maxs: v.Vec3 = .{ frame.hull.maxs[0], frame.hull.maxs[1], head };
    // Wading already, the step may stay in the same shallow water; harmful
    // liquids are never stepped into.
    var avoided: u32 = frame.liquid_mask | c.CONTENTS_WATER;
    if (try collision.contents(v.add(from, .{ 0, 0, hull_mins[2] + 1 }), frame.slot) & c.CONTENTS_WATER != 0) avoided &= ~@as(u32, c.CONTENTS_WATER);
    // Qualify every interval, including a clear stride across a narrow hole.
    // An actor over that hole blocks the body but cannot stand in for its floor.
    return try @import("../../core/domain/navigation_input.zig").walkPathSupported(collision, .{ .start = from, .end = to, .mins = hull_mins, .maxs = hull_maxs, .slot = frame.slot, .mask = frame.motionMask() }, avoided, &.{}, drop, frame.motionMask() & ~@as(u32, c.CONTENTS_BODY)) != null;
}
/// A hop armed for a stalled stride climbs the lip in the way; it is no
/// decision to leave the floor. The way ahead must not fall away a long way
/// below the feet or be a gas that kills on contact (the nitrogen under the
/// icelab's floors: e1m6a's lab killed the bot on every attempt by a hop off
/// the ledge beside the button's room). A way ahead that is solid — the lip
/// itself, a wall — says nothing either way and is left alone.
/// Where the route itself means to descend, the fall is the way: `drop` is how
/// far below the feet the route's own step or goal lies (0 when it means to
/// stay up), and the ground is sought that far down before the hop is refused.
/// Only a gas still refuses it — e1m7a's corridor comes down over a kerb too
/// high to step, and a hop is how a player goes over it.
pub fn hopSafe(frame: Frame, position: v.Vec3, direction: v.Vec3, drop: f32) !bool {
    const collision = frame.collision;
    const feet = position[2] + frame.hull.mins[2];
    const depth: f32 = 256 + @max(drop, 0);
    for ([_]f32{ 32, 56 }) |step| {
        const above: v.Vec3 = .{ position[0] + direction[0] * step, position[1] + direction[1] * step, position[2] - 8 };
        const down = try collision.trace(.{ .start = above, .end = .{ above[0], above[1], above[2] - depth }, .mins = @splat(0), .maxs = @splat(0), .slot = frame.slot, .mask = frame.motionMask() });
        if (down.start_solid or down.all_solid) continue;
        if (down.fraction == 1 or down.normal[2] < 0.5) return false;
        if (drop <= 0 and down.end[2] < feet - 64) return false;
        if (try collision.contents(.{ down.end[0], down.end[1], down.end[2] + 8 }, frame.slot) & (c.CONTENTS_LAVA | c.CONTENTS_SLIME | c.CONTENTS_DK3_NITRO) != 0) return false;
    }
    return true;
}
/// Sidestep across the enemy's line of fire, alternating sides, tethered to
/// the position the route chose to hold.
pub fn strafe(frame: Frame, position: v.Vec3, enemy: v.Vec3, anchor: v.Vec3, side: f32, tethered: bool, arena: ?[2][2]f32, avoid: *const fn (Frame, v.Vec3, v.Vec3) anyerror!bool) !?v.Vec3 {
    // Outside the arena, the first move is back into it.
    if (!inside(arena, position)) {
        const box = arena.?;
        const centre: v.Vec3 = .{ (box[0][0] + box[1][0]) / 2, (box[0][1] + box[1][1]) / 2, position[2] };
        return v.subtract(centre, position);
    }
    const away = v.subtract(position, anchor);
    const bearing = v.normalize(.{ enemy[0] - position[0], enemy[1] - position[1], 0 });
    // Inside a brawler's reach, back straight off (the tether gives way up
    // to twice its length): it hits far harder up close than from range
    // (a cryotech's freezing spray reaches about 250).
    const range = v.length(.{ enemy[0] - position[0], enemy[1] - position[1], 0 });
    // An explicit arena already bounds the fighting footprint. A second
    // tether must not pin its distant corner or pull a retreat toward a
    // brawler merely because the original firing stance is far behind it.
    if (range < 280 and (arena != null or !tethered or v.length(.{ away[0], away[1], 0 }) < 224)) {
        const heading = std.math.atan2(-bearing[1], -bearing[0]);
        // Turn along a wall while there is still room to shed running
        // momentum. A clear short step alone keeps choosing straight back
        // until the body is pinned against the wall by a faster pursuer.
        // Retain short qualified steps when no longer escape lane exists.
        // At a concave corner both backward and perpendicular directions can
        // meet walls. A shallow forward flank can lead along the open wall;
        // it still needs the same supported, hazard-free full-hull corridor.
        for ([_]f32{ 192, 0 }) |lookahead| for ([_]f32{ 64, 32 }) |stride| for ([_]f32{ 0, side * 0.7853982, -side * 0.7853982, side * 1.5707964, -side * 1.5707964, side * 2.3561945, -side * 2.3561945 }) |turn| {
            const back: v.Vec3 = .{ @cos(heading + turn) * stride, @sin(heading + turn) * stride, 0 };
            if (lookahead > 0) {
                const ahead = v.add(position, v.scale(back, lookahead / stride));
                if (!inside(arena, ahead) or !try walkable(frame, position, ahead)) continue;
            }
            if (inside(arena, v.add(position, back)) and try walkable(frame, position, v.add(position, back)) and !try avoid(frame, position, back)) return back;
        };
    }
    if (tethered and range >= 280 and v.length(.{ away[0], away[1], 0 }) > 112) {
        const back = v.scale(v.normalize(.{ -away[0], -away[1], 0 }), 64);
        if (inside(arena, v.add(position, back)) and try walkable(frame, position, v.add(position, back)) and !try avoid(frame, position, back)) return back;
    }
    for ([_]f32{ side, -side }) |direction| {
        const step = v.scale(.{ -bearing[1] * direction, bearing[0] * direction, 0 }, 96);
        if (inside(arena, v.add(position, step)) and try walkable(frame, position, v.add(position, step)) and !try avoid(frame, position, step)) return step;
    }
    return null;
}

test "evasion minimises the summed splash at the moment each threat lands" {
    const threats = [_]Threat{ .{ .point = .{ 0, 0, 0 }, .eta = 1, .radius = 256 }, .{ .point = .{ 100, 0, 0 }, .eta = 1, .radius = 256 } };
    try std.testing.expect(exposure(.{ 0, 0, 0 }, .{ -288, 0, 0 }, &threats) < exposure(.{ 0, 0, 0 }, .{ 50, 0, 0 }, &threats));
    try std.testing.expectApproxEqAbs(@as(f32, 1 + 1 - 10000.0 / 65536.0), exposure(.{ 0, 0, 0 }, .{ 0, 0, 0 }, &threats), 0.001);
    // An impact far in the future can still be outrun; an imminent one cannot.
    const late = [_]Threat{.{ .point = .{ 0, 0, 0 }, .eta = 2, .radius = 256 }};
    const soon = [_]Threat{.{ .point = .{ 0, 0, 0 }, .eta = 0.2, .radius = 256 }};
    try std.testing.expect(exposure(.{ 0, 0, 0 }, .{ 288, 0, 0 }, &late) < exposure(.{ 0, 0, 0 }, .{ 288, 0, 0 }, &soon));
}

test "retreat turns along a wall before its short backward step reaches it" {
    const Fixture = struct {
        wall_x: f32 = 100,
        wall_y: f32 = 10000,
        fn trace(raw: *anyopaque, request: @import("../../core/domain/collision.zig").Request) !@import("../../core/domain/collision.zig").Trace {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const Trace = @import("../../core/domain/collision.zig").Trace;
            var hit: Trace = .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
            const edge = self.wall_x - request.maxs[0];
            if (request.start[0] > edge) return .{ .fraction = 0, .end = request.start, .normal = .{ -1, 0, 0 }, .start_solid = true };
            if (request.end[0] > edge) {
                hit.fraction = (edge - request.start[0]) / (request.end[0] - request.start[0]);
                hit.normal = .{ -1, 0, 0 };
            }
            const edge_y = self.wall_y - request.maxs[1];
            if (request.start[1] > edge_y) return .{ .fraction = 0, .end = request.start, .normal = .{ 0, -1, 0 }, .start_solid = true };
            if (request.end[1] > edge_y) {
                const fraction = (edge_y - request.start[1]) / (request.end[1] - request.start[1]);
                if (fraction < hit.fraction) {
                    hit.fraction = fraction;
                    hit.normal = .{ 0, -1, 0 };
                }
            }
            const bottom = request.start[2] + request.mins[2];
            const end_bottom = request.end[2] + request.mins[2];
            if (end_bottom < 0 and bottom >= 0) {
                const fraction = bottom / (bottom - end_bottom);
                if (fraction <= hit.fraction) {
                    hit.fraction = fraction;
                    hit.normal = .{ 0, 0, 1 };
                }
            }
            hit.end = v.add(request.start, v.scale(v.subtract(request.end, request.start), hit.fraction));
            return hit;
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
        fn avoid(_: Frame, _: v.Vec3, _: v.Vec3) !bool {
            return false;
        }
    };
    var world = data.World.init(std.testing.allocator, 2);
    defer world.deinit();
    const entity = try world.create(1, .{data.Body{}});
    var fixture: Fixture = .{};
    const frame: Frame = .{ .world = &world, .slots = undefined, .projections = &.{}, .service = undefined, .collision = .{ .context = &fixture, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents }, .table = undefined, .slot = 0, .entity = entity, .state = .{}, .now = 0 };
    const position: v.Vec3 = .{ 0, 0, 24 };
    try std.testing.expect(try walkable(frame, position, .{ 64, 0, 24 }));
    try std.testing.expect(!try walkable(frame, position, .{ 192, 0, 24 }));
    const step = (try strafe(frame, position, .{ -200, 0, 24 }, position, 1, false, null, Fixture.avoid)).?;
    try std.testing.expect(@abs(step[0]) < 1);
    try std.testing.expect(@abs(step[1]) >= 32);
    // At an inside corner, the open wall leads slightly toward the pursuer.
    // Rejecting that flank leaves a body pinned despite clear supported floor.
    fixture = .{ .wall_x = 20, .wall_y = 20 };
    const flank = (try strafe(frame, position, .{ -108, -132, 24 }, position, 1, false, null, Fixture.avoid)).?;
    try std.testing.expect(flank[0] < -32);
    try std.testing.expect(flank[1] < 0);
    try std.testing.expect(try walkable(frame, position, v.add(position, flank)));
    // A large authored arena replaces the short firing tether. At its far
    // side, returning toward the old anchor walks straight into the brawler.
    fixture = .{ .wall_x = 10000 };
    const retreat = (try strafe(frame, position, .{ -80, 0, 24 }, .{ -256, 0, 24 }, 1, true, .{ .{ -512, -512 }, .{ 512, 512 } }, Fixture.avoid)).?;
    try std.testing.expect(retreat[0] > 0);
}

test "returning to a combat tether cannot cross an unsupported floor" {
    const Fixture = struct {
        fn trace(_: *anyopaque, request: @import("../../core/domain/collision.zig").Request) !@import("../../core/domain/collision.zig").Trace {
            return .{ .fraction = 1, .end = request.end, .normal = @splat(0) };
        }
        fn contents(_: *anyopaque, _: v.Vec3, _: u16) !u32 {
            return 0;
        }
        fn avoid(_: Frame, _: v.Vec3, _: v.Vec3) !bool {
            return false;
        }
    };
    var world = data.World.init(std.testing.allocator, 2);
    defer world.deinit();
    const entity = try world.create(1, .{data.Body{}});
    var fixture: u8 = 0;
    const frame: Frame = .{ .world = &world, .slots = undefined, .projections = &.{}, .service = undefined, .collision = .{ .context = &fixture, .trace_fn = Fixture.trace, .contents_fn = Fixture.contents }, .table = undefined, .slot = 0, .entity = entity, .state = .{}, .now = 0 };
    try std.testing.expect(try strafe(frame, .{ 160, 0, 24 }, .{ 600, 0, 24 }, .{ 0, 0, 24 }, 1, true, null, Fixture.avoid) == null);
}
const hazards = @import("../../game/server/hazard_classes.zig").classes;
