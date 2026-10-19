// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: maps authored classnames and world-control states to their map-entity class
//! adapters, and dispatches the hooks.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
//!
//! An adapter declares `pub const tag`, the `WorldControl.action` variant it owns (every variant
//! has exactly one adapter), and the classnames it spawns from (`classnames`, or `owns(name)`;
//! classes spawned at run time declare neither). Hooks, all optional:
//!
//! | Hook | Default |
//! |---|---|
//! | `spawn(*Spawn) !Spawned` | required for authored classes |
//! | `bind(*Publish) !void` | none: the control has no projection |
//! | `use(*Control, u32) !void` | nothing |
//! | `touches(Contact) !bool` / `touch(*Control, Entity) !void` | no contact; contact uses it |
//! | `step(*Control) !void` | nothing |
//! | `publish(*Publish) !void` | none: the control is not projected |
//! | `savedModel(Action) ?[]const u8` | a projected control saves no model |
//! | `passage(*World, Entity) !?Transform` | touching it takes nobody anywhere |
//! | `soundtrack(Action) ?Soundtrack` | it sets no music |
//! | `current(Action) ?Current` | it pushes nothing |
//! | `touchesWithBody(Action) bool` | it touches only through a trigger volume |
//! | `brush_model: bool` | false: the control is not an authored brush |
//! | `prepareStep` / `finishStep(*World, i64)` | once per step, before / after the controls |
//! | `validateSaved(*const Saved, Action) !void` | no class invariants |
//! | `savedAs(Action, []const u8) bool` / `saved_classnames` | its spawn classnames |
//!
//! Authored classes that are not world controls declare `classnames` (or `owns`) and any of:
//!
//! | Hook | Default |
//! |---|---|
//! | `brush: Brush` | bound, solid, visible, authored angles |
//! | `pass: Pass`, `prepare(*Prepare) !void` | nothing prepared |
//! | `useAuthored(*Use) !void` | the router's generic handling |
//! | `openForParty(*World, *Slots, []EntityProjection, Entity, u32, i64) !bool` | a party member pushing into it does not open it |
//! | `traits: Traits` (or `fn([]const u8) Traits`) | no traits |
const std = @import("std");
const data = @import("../../../game/domain/components.zig");
const ecs = @import("../../../core/ecs/world.zig");
const context = @import("context.zig");
pub const Spawn = context.Spawn;
pub const Spawned = context.Spawned;
pub const Control = context.Control;
pub const Contact = context.Contact;
pub const Publish = context.Publish;
pub const Action = context.Action;
pub const Brush = context.Brush;
pub const Pass = context.Pass;
pub const Prepare = context.Prepare;
pub const Use = context.Use;
pub const Saved = context.Saved;
pub const Traits = context.Traits;
pub const Soundtrack = context.Soundtrack;
pub const Current = context.Current;
const Tag = std.meta.Tag(Action);

const adapters = @import("../../../game/server/entity_classes/classes.zig").adapters;
const tag_count = @typeInfo(Tag).@"enum".fields.len;
/// Adapter index for each control variant.
const owner: [tag_count]u8 = blk: {
    @setEvalBranchQuota(100_000);
    var table: [tag_count]?u8 = @splat(null);
    for (adapters, 0..) |A, index| if (@hasDecl(A, "tag")) {
        const at = @intFromEnum(@as(Tag, A.tag));
        if (table[at] != null) @compileError("world control adapted twice: " ++ @tagName(A.tag));
        table[at] = index;
    };
    var result: [tag_count]u8 = undefined;
    for (table, 0..) |entry, index| result[index] = entry orelse @compileError("world control without a class adapter: " ++ @tagName(@as(Tag, @enumFromInt(index))));
    break :blk result;
};
fn adapterOf(tag: Tag) u8 {
    return owner[@intFromEnum(tag)];
}

/// The adapter of an authored classname, or null.
fn adapterNamed(name: []const u8) ?u8 {
    inline for (adapters, 0..) |A, index| {
        if (@hasDecl(A, "owns")) {
            if (A.owns(name)) return index;
        } else if (@hasDecl(A, "classnames")) {
            for (A.classnames) |classname| if (std.mem.eql(u8, classname, name)) return index;
        }
    }
    return null;
}
/// The world-control class spawning an authored classname, or null.
pub fn classOf(name: []const u8) ?u8 {
    const index = adapterNamed(name) orelse return null;
    switch (index) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "spawn")) i else null,
        else => unreachable,
    }
}
/// What shared systems may ask about an authored classname (`traits`, a value or a function of
/// the classname for classes of several names).
pub fn traitsOf(name: []const u8) Traits {
    switch (adapterNamed(name) orelse return .{}) {
        inline 0...adapters.len - 1 => |i| {
            const A = adapters[i];
            if (!@hasDecl(A, "traits")) return .{};
            return if (@typeInfo(@TypeOf(A.traits)) == .@"fn") A.traits(name) else A.traits;
        },
        else => unreachable,
    }
}
/// How an authored brush of this classname is bound.
pub fn brushOf(name: []const u8) Brush {
    switch (adapterNamed(name) orelse return .{}) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "brush")) adapters[i].brush else .{},
        else => unreachable,
    }
}
/// Prepares every authored entity whose class prepares in `pass`.
pub fn prepareAll(pass: Pass, allocator: std.mem.Allocator, world: *data.World, projections: []@import("../../../engine/abi.zig").EntityProjection) !void {
    var entities: [ecs.max_entities]ecs.Entity = undefined;
    var classes: [ecs.max_entities]u8 = undefined;
    var count: usize = 0;
    {
        var query = world.queryAccess(data.World.mask(.{data.MapObject}), 0, 0);
        defer query.deinit();
        while (query.next()) |view| for (view.entities(), view.read(data.MapObject)) |entity, object| {
            const index = adapterNamed(object.classname) orelse continue;
            if (!preparesIn(index, pass)) continue;
            entities[count] = entity;
            classes[count] = index;
            count += 1;
        };
    }
    for (entities[0..count], classes[0..count]) |entity, index| {
        var preparing: Prepare = .{ .allocator = allocator, .world = world, .projections = projections, .entity = entity, .object = (try world.get(entity, data.MapObject)).* };
        switch (index) {
            inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], "prepare")) try adapters[i].prepare(&preparing),
            else => unreachable,
        }
    }
}
fn preparesIn(index: u8, pass: Pass) bool {
    switch (index) {
        inline 0...adapters.len - 1 => |i| return @hasDecl(adapters[i], "prepare") and adapters[i].pass == pass,
        else => unreachable,
    }
}
/// Whether a party member (`activator`) pushing into this authored entity opened it.
pub fn openForParty(world: *data.World, slots: *@import("../../../engine/slots.zig").Slots, projections: []@import("../../../engine/abi.zig").EntityProjection, entity: ecs.Entity, activator: u32, now: i64) !bool {
    const object = world.get(entity, data.MapObject) catch return false;
    switch (adapterNamed(object.classname) orelse return false) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "openForParty")) adapters[i].openForParty(world, slots, projections, entity, activator, now) else false,
        else => unreachable,
    }
}
/// A class's own response to an authored use; false when the router's generic handling applies.
pub fn useAuthored(using: *Use) !bool {
    switch (adapterNamed(using.object.classname) orelse return false) {
        inline 0...adapters.len - 1 => |i| {
            if (!@hasDecl(adapters[i], "useAuthored")) return false;
            try adapters[i].useAuthored(using);
            return true;
        },
        else => unreachable,
    }
}
pub fn spawn(class: u8, spawning: *Spawn) !Spawned {
    switch (class) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "spawn")) adapters[i].spawn(spawning) else unreachable,
        else => unreachable,
    }
}
pub fn bind(tag: Tag, publishing: *Publish) !void {
    switch (adapterOf(tag)) {
        inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], "bind")) try adapters[i].bind(publishing),
        else => unreachable,
    }
}
pub fn use(control: *Control, activator: u32) !void {
    switch (adapterOf(control.control.action)) {
        inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], "use")) try adapters[i].use(control, activator),
        else => unreachable,
    }
}
pub fn touches(contact: Contact) !bool {
    switch (adapterOf(contact.control.action)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "touches")) adapters[i].touches(contact) else false,
        else => unreachable,
    }
}
/// Whether a control touches with its own body rather than a trigger volume.
pub fn touchesWithBody(action: Action) bool {
    switch (adapterOf(action)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "touchesWithBody")) adapters[i].touchesWithBody(action) else false,
        else => unreachable,
    }
}
/// The music a control set, when its class sets music.
pub fn soundtrack(action: Action) ?Soundtrack {
    switch (adapterOf(action)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "soundtrack")) adapters[i].soundtrack(action) else null,
        else => unreachable,
    }
}
/// The current a control pushes with, when its class pushes.
pub fn current(action: Action) ?Current {
    switch (adapterOf(action)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "current")) adapters[i].current(action) else null,
        else => unreachable,
    }
}
/// Whether a control's class declares `passage` (it may send actors somewhere).
pub fn isPassage(action: Action) bool {
    switch (adapterOf(action)) {
        inline 0...adapters.len - 1 => |i| return @hasDecl(adapters[i], "passage"),
        else => unreachable,
    }
}
/// Where touching a control sends an actor, for route planning; null when it sends nobody.
pub fn passage(action: Action, world: *data.World, entity: ecs.Entity) !?data.Transform {
    switch (adapterOf(action)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "passage")) try adapters[i].passage(world, entity) else null,
        else => unreachable,
    }
}
pub fn touch(control: *Control, other: ecs.Entity) !void {
    switch (adapterOf(control.control.action)) {
        inline 0...adapters.len - 1 => |i| {
            if (@hasDecl(adapters[i], "touch")) return adapters[i].touch(control, other);
            return use(control, try control.world.persistentId(other));
        },
        else => unreachable,
    }
}
pub fn step(control: *Control) !void {
    switch (adapterOf(control.control.action)) {
        inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], "step")) try adapters[i].step(control),
        else => unreachable,
    }
}
/// Projects a control; false when its class has no projection.
pub fn publish(tag: Tag, publishing: *Publish) !bool {
    switch (adapterOf(tag)) {
        inline 0...adapters.len - 1 => |i| {
            if (!@hasDecl(adapters[i], "publish")) return false;
            try adapters[i].publish(publishing);
            return true;
        },
        else => unreachable,
    }
}
/// Whether a restored control's binding must match `savedModel`: projected controls that are not
/// authored brushes (`brush_model`; brushes are checked with the other brush entities).
pub fn modelChecked(tag: Tag) bool {
    switch (adapterOf(tag)) {
        inline 0...adapters.len - 1 => |i| {
            const A = adapters[i];
            return @hasDecl(A, "publish") and !(@hasDecl(A, "brush_model") and A.brush_model);
        },
        else => unreachable,
    }
}
/// The model a restored projected control must be bound to, or null for none.
pub fn savedModel(action: Action) ?[]const u8 {
    switch (adapterOf(action)) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "savedModel")) adapters[i].savedModel(action) else null,
        else => unreachable,
    }
}
/// Validates a restored control: its entity's classname is one its class spawns (or `savedAs`
/// accepts for the state), and the class's `validateSaved` invariants hold.
pub fn validateSaved(saved: *const Saved, action: Action) !void {
    const classname = try saved.classname();
    switch (adapterOf(action)) {
        inline 0...adapters.len - 1 => |i| {
            const A = adapters[i];
            const named = if (@hasDecl(A, "savedAs")) A.savedAs(action, classname) else listed(A, classname);
            if (!named) return error.InvalidSavedWorldControl;
            if (@hasDecl(A, "validateSaved")) try A.validateSaved(saved, action);
        },
        else => unreachable,
    }
}
fn listed(comptime A: type, classname: []const u8) bool {
    if (@hasDecl(A, "owns")) return A.owns(classname);
    if (@hasDecl(A, "classnames")) for (A.classnames) |name| if (std.mem.eql(u8, name, classname)) return true;
    if (@hasDecl(A, "saved_classnames")) for (A.saved_classnames) |name| if (std.mem.eql(u8, name, classname)) return true;
    return false;
}
pub fn prepareStep(world: *data.World, now: i64) !void {
    inline for (adapters) |A| if (@hasDecl(A, "prepareStep")) try A.prepareStep(world, now);
}
pub fn finishStep(world: *data.World, now: i64) void {
    inline for (adapters) |A| if (@hasDecl(A, "finishStep")) A.finishStep(world, now);
}

test "authored classnames reach their classes: controls, brushes, traits" {
    const t = std.testing;
    try t.expect(classOf("trigger_push") != null and classOf("func_timer") != null and classOf("light") != null);
    try t.expect(classOf("func_door") == null and classOf("trigger_once") == null);
    try t.expect(brushOf("func_clip").hidden and brushOf("func_event_generator").hidden and !brushOf("func_wall").hidden);
    try t.expect(brushOf("func_door").angles == .zeroed and brushOf("func_door_rotate").angles == .authored);
    try t.expect(!brushOf("func_areaportal").bound and brushOf("func_illusionary").contents == .none);
    try t.expect(traitsOf("func_button").button and traitsOf("func_button").relays);
    try t.expect(traitsOf("trigger_once").touch_volume and !traitsOf("trigger_relay").touch_volume);
    try t.expect(traitsOf("trigger_counter").counter and traitsOf("func_explosive").breakable and !traitsOf("func_breakable").breakable);
    try t.expect(traitsOf("func_door").door == .sliding and traitsOf("func_door_rotate").door == .rotating);
    try t.expect(traitsOf("trigger_capture").capture_zone and traitsOf("trigger_changelevel").level_exit);
    try t.expect(traitsOf("item_flag_team1").team_flag == 1 and traitsOf("item_flag_team2").team_flag == 2);
    try t.expectEqual(@as(u32, 2), traitsOf("trigger_script").use_only_flag);
}
