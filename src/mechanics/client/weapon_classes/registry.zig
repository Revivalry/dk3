// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: maps weapon ids to their client class adapters for drawing.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
//!
//! An adapter declares `pub const description` and only the hooks it needs:
//!
//! | Hook | Default |
//! |---|---|
//! | `drawEffect(Effect) !void` | the shared area effect |
//! | `drawSprite(Sprite) !void` | nothing beyond the projectile sprite |
//! | `decorateMissile(Missile) !void` | nothing beyond the shared missile look |
//! | `drawMissile(Effect) !void` | nothing beyond the missile model or sprite |
//! | `viewEnd(c.entityState_t) ?i64` | its effect never ends the first-person weapon view |
const catalog = @import("weapon_catalog");
const c = @import("../../../engine/abi.zig").c;

/// A weapon effect entity being drawn.
pub const Effect = struct { entity: c.entityState_t, entities: []const c.entityState_t = &.{}, now: i32, ref: *const c.refdef_t, client: i32 };
/// A projectile drawn as a sprite, at `origin`.
pub const Sprite = struct { entity: c.entityState_t, origin: [3]f32, now: i32, ref: *const c.refdef_t, counters: *@import("../render_classes/context.zig").Counters };
/// A projectile model being drawn.
pub const Missile = struct { rendered: *c.refEntity_t, entity: c.entityState_t, now: i64 };

const adapters = @import("../../../game/client/weapon_classes/classes.zig").adapters;
const owner: [@as(usize, catalog.count) + 1]?u8 = blk: {
    var table: [@as(usize, catalog.count) + 1]?u8 = @splat(null);
    for (adapters, 0..) |A, index| {
        if (table[A.description.id] != null) @compileError("weapon drawn by two client adapters: " ++ @typeName(A));
        table[A.description.id] = index;
    }
    break :blk table;
};
fn adapterOf(weapon: i32) ?u8 {
    if (weapon <= 0 or weapon > catalog.count) return null;
    return owner[@intCast(weapon)];
}
pub fn drawEffect(effect: Effect) !void {
    switch (adapterOf(effect.entity.weapon) orelse return @import("../area_effects.zig").draw(effect.entity, effect.now)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "drawEffect")) adapters[i].drawEffect(effect) else @import("../area_effects.zig").draw(effect.entity, effect.now),
        else => unreachable,
    }
}
pub fn drawSprite(sprite: Sprite) !void {
    switch (adapterOf(sprite.entity.weapon) orelse return) {
        inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], "drawSprite")) try adapters[i].drawSprite(sprite),
        else => unreachable,
    }
}
pub fn drawMissile(effect: Effect) !void {
    switch (adapterOf(effect.entity.weapon) orelse return) {
        inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], "drawMissile")) try adapters[i].drawMissile(effect),
        else => unreachable,
    }
}
/// When the holder's own effect ends the first-person weapon view, if it does.
pub fn viewEnd(entity: c.entityState_t) ?i64 {
    switch (adapterOf(entity.weapon) orelse return null) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "viewEnd")) adapters[i].viewEnd(entity) else null,
        else => unreachable,
    }
}
pub fn decorateMissile(missile: Missile) !void {
    switch (adapterOf(missile.entity.weapon) orelse return) {
        inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], "decorateMissile")) try adapters[i].decorateMissile(missile),
        else => unreachable,
    }
}
