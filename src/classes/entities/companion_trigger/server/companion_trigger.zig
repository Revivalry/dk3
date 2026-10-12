// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: companion_trigger. Party trigger volumes (sidekick spawn, follow, stop and
//! teleport). Their effect is the companions class's (companion_triggers.zig).
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const owns = @import("../../../actors/companions/server/companion_triggers.zig").owns;
pub const traits: context.Traits = .{ .touch_once = true };
