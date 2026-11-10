// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Persistent party behavior and shared native locomotion state.
const policy = @import("actor_catalog").companions;
pub const State = struct {
    identity: policy.Identity,
    carrying: bool = false,
    enabled: bool = true,
    order: policy.Order = .follow,
    owner: u32 = 0,
    anger: policy.anger.State = .{},
    target: u32 = 0,
    destination: [3]f32 = @splat(0),
    authored: policy.Authored = .none,
    animation_until: ?i64 = null,
    after_teleport: policy.Order = .follow,
    stopped: bool = false,
    /// Authored STAY staging outside the playable floor; released by a supported placement.
    parked: bool = false,
    next_ms: i64 = 0,
    last_ms: i64 = 0,
    death_reported: bool = false,
    motor: @import("../../../../mechanics/domain/player_move.zig").Player = .{},
    jump_started_ms: i64 = 0,
    selected_weapon: u5 = 0,
    collecting: u32 = 0,
    collect_forced: bool = false,
    collect_scan_ms: i64 = 0,
    collect_until_ms: i64 = 0,
    avoided_item: u32 = 0,
    avoid_until_ms: i64 = 0,
    yielding_until_ms: i64 = 0,
    yield_position: [3]f32 = @splat(0),
    /// It says no authored line before this time.
    talk_ready_ms: i64 = 0,
    /// A physical puzzle station, retained across saves until its class releases it.
    puzzle: ?struct { control: u32, point: [3]f32, holding: bool = false } = null,
    /// Maps saved entity ids to restored ones (snapshot_ids.zig).
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.fields(self, .{ "owner", "target", "collecting", "avoided_item" });
        if (self.puzzle) |*puzzle| try map.one(&puzzle.control);
    }
    /// Moves saved timestamps onto the restoring clock (`clock`: shift, active, deadline).
    pub fn rebase(self: *State, clock: anytype) !void {
        try self.anger.rebase(clock);
        try clock.active(&self.motor.teleport_until_ms);
        try clock.shift(&self.motor.command_ms);
        try clock.active(&self.jump_started_ms);
        try clock.deadline(&self.animation_until);
        try clock.shift(&self.next_ms);
        try clock.shift(&self.last_ms);
        try clock.active(&self.collect_scan_ms);
        try clock.active(&self.collect_until_ms);
        try clock.active(&self.avoid_until_ms);
        try clock.active(&self.talk_ready_ms);
        try clock.active(&self.yielding_until_ms);
    }
    /// Rejects saved values its class could never hold (snapshot.zig `Check`).
    pub fn validateSaved(self: *const State, check: anytype) !void {
        if (!self.anger.valid()) return error.InvalidSavedCompanionAnger;
        try check.require(.{ "Actor", "Health", "Weapons", "Character", "Keys", "Ailments" });
        const kind = @import("actor_catalog").entries[(try check.get("Actor")).definition];
        if (!@import("actor_catalog").traitsOf(kind.kind).party or self.carrying != @import("std").mem.eql(u8, kind.classname, "mikikofly") or (self.identity == .mikiko) != @import("std").mem.eql(u8, kind.classname, "mikiko")) return error.InvalidSavedCompanion;
        if (self.owner != 0) {
            const owner = check.find(self.owner) orelse return error.InvalidSavedCompanionOwner;
            try owner.require(.{"Player"});
        }
        const motor = self.motor;
        if (!@import("std").math.isFinite(motor.view_height) or motor.view_height < -64 or motor.view_height > 128 or motor.ground_entity > 2047 or motor.timer_ms > 2147483647 or (motor.mode != .normal and motor.mode != .frozen)) return error.InvalidSavedCompanionMotor;
        if (self.selected_weapon != 0) {
            const entry = @import("weapon_catalog").find(self.selected_weapon) orelse return error.InvalidSavedCompanionWeapon;
            if (entry.spec.companion == null or self.carrying or (try check.get("Weapons")).dk3Inventory & (@as(i32, 1) << self.selected_weapon) == 0) return error.InvalidSavedCompanionWeapon;
        }
        for (self.destination ++ self.yield_position) |axis| if (!@import("std").math.isFinite(axis)) return error.InvalidSavedCompanionAction;
        if (self.puzzle) |puzzle| {
            if (puzzle.control == 0) return error.InvalidSavedCompanionAction;
            for (puzzle.point) |axis| if (!@import("std").math.isFinite(axis)) return error.InvalidSavedCompanionAction;
        }
        if (self.collect_forced and self.collecting == 0) return error.InvalidSavedCompanionAction;
        if (self.animation_until != null and (self.authored == .none or (try check.get("Actor")).scripted_pose == null)) return error.InvalidSavedCompanionAction;
    }
    /// A party member may be saved holding no weapon at all (snapshot.zig).
    pub const saved_unarmed = true;
};
/// The party members travelling with `player` (travel.zig), each captured with `Follower.capture`
/// into its identity's slot.
pub fn captureFollowers(comptime Follower: type, world: anytype, player: anytype, out: *[2]?Follower) !void {
    const data = @import("../../../../game/domain/components.zig");
    const origin = (try world.get(player, data.Transform)).position;
    const leader = try world.persistentId(player);
    var query = world.queryAccess(data.World.mask(.{data.Companion}), 0, 0);
    defer query.deinit();
    while (query.next()) |view| for (view.entities(), view.read(data.Companion)) |entity, state| {
        if (state.owner != leader) continue;
        out[@intFromEnum(state.identity)] = try Follower.capture(world, entity, origin);
    };
}

/// Preserve hidden provocation while resetting transient travel orders.
pub fn arriveFollower(follower: anytype, now: i64, delta: i64, episode: u8, previous_episode: u8, table: *const @import("../../../../mechanics/domain/weapons.zig").Table) !void {
    try @import("../../../../mechanics/domain/snapshot_time.zig").rebase(.character, &follower.character, delta);
    follower.character.liquid = .{};
    try @import("../../../../mechanics/domain/snapshot_time.zig").rebase(.weapons, &follower.weapons, delta);
    try follower.state.anger.rebase(@import("actor_catalog").saved_time.Clock{ .delta = delta });
    follower.state.motor = .{ .command_ms = now };
    follower.state.jump_started_ms = 0;
    follower.state.target = 0;
    follower.state.collecting = 0;
    follower.state.collect_forced = false;
    follower.state.collect_scan_ms = now;
    follower.state.collect_until_ms = 0;
    follower.state.avoided_item = 0;
    follower.state.avoid_until_ms = 0;
    follower.state.yielding_until_ms = 0;
    follower.state.selected_weapon = 0;
    follower.state.owner = 0;
    follower.state.order = .follow;
    follower.state.authored = .none;
    follower.state.animation_until = null;
    follower.state.stopped = false;
    follower.state.parked = false;
    follower.state.next_ms = now;
    follower.state.last_ms = now;
    follower.ailments.cure();
    follower.weapons.weaponTime = 0;
    follower.weapons.weaponstate = 0;
    follower.weapons.dk3AttackHeld = 0;
    if (episode != previous_episode) {
        follower.keys = .{};
        follower.weapons = .{};
        if (episode == 1 and !follower.state.carrying) {
            const initial = @import("weapon_catalog").starting(episode);
            _ = follower.weapons.acquire(table, initial, table.entries[initial].initialAmmo);
        }
    }
}
