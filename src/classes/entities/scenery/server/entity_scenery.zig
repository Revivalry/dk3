// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: scenery. Authored episode decorations (`deco_e1`..`deco_e4`). They spawn as
//! physical props (scenery.zig, props.zig); the adapter only names the class to shared systems.
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const owns = @import("../domain/scenery.zig").owns;
pub const traits: context.Traits = .{ .decoration = true };
