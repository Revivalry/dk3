// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: button. Buttons: bound from their unrotated pose; movers.zig presses them.
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{"func_button"};
pub const brush: context.Brush = .{ .angles = .zeroed };
pub const traits: context.Traits = .{ .button = true, .relays = true };
