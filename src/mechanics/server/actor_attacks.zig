// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: persistent actor attack stepping and projection. Each payload's handler
//! (attack_classes.zig) owns its behaviour; this module only routes by the payload tag.
const std = @import("std");
const data = @import("../../game/domain/components.zig");
const ecs = @import("../../core/ecs/world.zig");
const abi = @import("../../engine/abi.zig");
const Slots = @import("../../engine/slots.zig").Slots;
const handlers = @import("../../game/server/attack_classes.zig").handlers;
const Tag = std.meta.Tag(@FieldType(data.ActorAttack, "attack"));
/// The handler index for each payload tag; every tag has exactly one.
const handler_of: [@typeInfo(Tag).@"enum".fields.len]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var table: [@typeInfo(Tag).@"enum".fields.len]?u8 = @splat(null);
    for (handlers, 0..) |H, index| for (H.policy.attack_payloads) |payload| {
        const at = @intFromEnum(@field(Tag, payload.tag));
        if (table[at] != null) @compileError("attack payload handled twice: " ++ payload.tag);
        table[at] = index;
    };
    var result: [table.len]u8 = undefined;
    for (table, 0..) |entry, index| result[index] = entry orelse @compileError("attack payload without a handler: " ++ @tagName(@as(Tag, @enumFromInt(index))));
    break :blk result;
};
/// Optional handler hooks, besides `publish` and `step`:
///   `holds(*const data.ActorAttack, victim_id: u32) bool`: the attack holds this victim frozen;
///   `damaged(*Damage) !void`: the attack entity itself was hurt;
///   `actionOwner(*const data.ActorAttack) ?u32`: the entity whose running action it is;
///   `linkedOwner(*const data.ActorAttack) ?u32`: the entity its projection names in `otherEntityNum`;
///   `admitsDamage(*const data.ActorAttack) bool`: false while the attack entity takes no damage.
/// Whether `target` is held frozen by the attack that owns its motion.
pub fn holds(world: *data.World, target: ecs.Entity) bool {
    const owner = (world.get(target, data.Body) catch return false).motion_owner orelse return false;
    const controller = @import("region_access.zig").find(world, owner) orelse return false;
    const attack = controller.get(data.ActorAttack) catch return false;
    const id = world.persistentId(target) catch return false;
    switch (handler_of[@intFromEnum(attack.attack)]) {
        inline 0...handlers.len - 1 => |index| return if (@hasDecl(handlers[index], "holds")) handlers[index].holds(attack, id) else false,
        else => unreachable,
    }
}
/// The entity whose running action an attack is, when its handler says so.
pub fn actionOwner(world: *data.World, entity: ecs.Entity) ?u32 {
    const attack = world.get(entity, data.ActorAttack) catch return null;
    switch (handler_of[@intFromEnum(attack.attack)]) {
        inline 0...handlers.len - 1 => |index| return if (@hasDecl(handlers[index], "actionOwner")) handlers[index].actionOwner(attack) else null,
        else => unreachable,
    }
}
/// The entity an attack's projection names, when its handler links one.
pub fn linkedOwner(attack: *const data.ActorAttack) ?u32 {
    switch (handler_of[@intFromEnum(attack.attack)]) {
        inline 0...handlers.len - 1 => |index| return if (@hasDecl(handlers[index], "linkedOwner")) handlers[index].linkedOwner(attack) else null,
        else => unreachable,
    }
}
/// Whether an attack entity takes damage now (its handler's `admitsDamage`, else yes).
pub fn admitsDamage(attack: *const data.ActorAttack) bool {
    switch (handler_of[@intFromEnum(attack.attack)]) {
        inline 0...handlers.len - 1 => |index| return if (@hasDecl(handlers[index], "admitsDamage")) handlers[index].admitsDamage(attack) else true,
        else => unreachable,
    }
}
/// A hit on an attack entity that has health, after the shared damage rules ran.
pub const Damage = struct {
    world: *data.World,
    entity: ecs.Entity,
    attack: *data.ActorAttack,
    health: *data.Health,
    source: u32,
    amount: i32,
    result: *@import("../domain/damage.zig").Result,
    now: i64,
};
pub fn damaged(hit: *Damage) !void {
    switch (handler_of[@intFromEnum(hit.attack.attack)]) {
        inline 0...handlers.len - 1 => |index| if (@hasDecl(handlers[index], "damaged")) try handlers[index].damaged(hit),
        else => unreachable,
    }
}
pub fn publish(world: *data.World, entity: ecs.Entity, projections: []abi.EntityProjection, now: i64) !void {
    switch (handler_of[@intFromEnum((try world.get(entity, data.ActorAttack)).attack)]) {
        inline 0...handlers.len - 1 => |index| try handlers[index].publish(world, entity, projections, now),
        else => unreachable,
    }
}
pub fn step(world: *data.World, slots: *Slots, projections: []abi.EntityProjection, now: i64) !void {
    const occupants = slots.occupants;
    for (occupants) |maybe| {
        const entity = maybe orelse continue;
        if (!world.alive(entity)) continue;
        const state = (world.get(entity, data.ActorAttack) catch continue).*;
        switch (handler_of[@intFromEnum(state.attack)]) {
            inline 0...handlers.len - 1 => |index| try handlers[index].step(world, slots, projections, entity, now),
            else => unreachable,
        }
    }
}
/// Restored or transferred entities carrying these components are projected here (projection_classes.zig).
pub const projected = .{data.ActorAttack};
/// Whether a saved attack entity draws without a model (its payload decides).
pub fn modelless(world: *data.World, entity: ecs.Entity) bool {
    return if (world.get(entity, data.ActorAttack) catch null) |attack| attack.modelless() else false;
}
pub fn project(projecting: *const @import("system_context.zig").Project) !bool {
    try publish(projecting.world, projecting.entity, projecting.projections, projecting.now);
    return true;
}
