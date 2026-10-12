// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: timer. Authored timers firing their targets.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const ecs = @import("../../../../core/ecs/world.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const v = @import("../../../../core/domain/vector.zig");
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
const Control = context.Control;
pub const tag = .timer;
pub const classnames = [_][]const u8{"func_timer"};
const rules = @import("../../../../mechanics/domain/world_controls.zig");
pub fn spawn(spawning: *context.Spawn) !context.Spawned {
    const object = spawning.object;
    const wait = try prop.milliseconds(object, "wait", 1);
    if (wait < 100) return error.InvalidTimerWait;
    var timer: @import("../domain/controls/timer.zig").State = .{ .wait_ms = wait, .variance_ms = @min(@max(0, try prop.milliseconds(object, "random", 0)), wait - 100), .delay_ms = try prop.milliseconds(object, "delay", 0), .random = try spawning.world.persistentId(spawning.entity), .once = object.flags & 2 != 0 };
    if (timer.delay_ms < 0) return error.InvalidTimerDelay;
    if (object.flags & 1 != 0) {
        timer.activator = try spawning.world.persistentId(spawning.entity);
        timer.next_ms = spawning.now + 1000 + try prop.milliseconds(object, "pausetime", 0) + timer.delay_ms + timer.interval();
    }
    return .{ .control = .{ .timer = timer } };
}
/// Use starts or stops the timer; a due start fires at once.
pub fn use(control: *Control, activator: u32) !void {
    const timer = &control.control.action.timer;
    if (timer.once and control.control.uses > 0) return;
    timer.activator = activator;
    timer.next_ms = if (timer.next_ms != null) null else control.now + timer.delay_ms;
    if (timer.next_ms != null and timer.next_ms.? <= control.now) try fire(control);
}
pub fn step(control: *Control) !void {
    const at = control.control.action.timer.next_ms orelse return;
    if (control.now < at) return;
    try fire(control);
}
fn fire(control: *Control) !void {
    const timer = &control.control.action.timer;
    const activator = timer.activator;
    timer.next_ms = if (timer.once) null else control.now + timer.interval();
    control.control.uses += 1;
    // Initial delay belongs to activation, not every target firing.
    try control.router.fireImmediate(control.world, control.slots, control.projections, control.entity, activator, control.now);
}
/// Rejects restored state this class could never hold.
pub fn validateSaved(_: *const context.Saved, action: context.Action) !void {
    const timer = action.timer;
    if (timer.wait_ms < 100 or timer.wait_ms > 3600000 or timer.variance_ms < 0 or timer.variance_ms >= timer.wait_ms or timer.delay_ms < 0 or timer.delay_ms > 3600000) return error.InvalidSavedTimer;
}
