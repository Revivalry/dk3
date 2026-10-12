// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: classes answering a target use, per stage of the router's fixed order
//! (targets.zig). A stage's hook `useTarget(*Use) !bool` returns true when the class handled the
//! use. Data only; targets.zig runs the stages.
/// After world controls, before actors answer.
pub const before_actors = .{@import("../../classes/actors/companions/server/companion_triggers.zig")};
/// After authored scripts.
pub const after_scripts = .{@import("../../classes/entities/monitor/server/monitors.zig")};
/// After the authored entity classes (entity_classes `useAuthored`).
pub const after_authored = .{@import("../../classes/entities/healthtree/server/healthtrees.zig")};
/// After actors that answer once scripts ran.
pub const after_actors = .{ @import("../../classes/entities/mover/server/movers.zig"), @import("../../classes/entities/special_mover/server/special_movers.zig"), @import("../../classes/entities/train/server/trains.zig") };
/// `killed(*World, Entity) !void`: before a killtarget removes the entity.
pub const killed = .{@import("../../classes/entities/monitor/server/monitors.zig")};
