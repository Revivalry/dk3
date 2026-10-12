// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: clip. Player and monster clips: invisible blockers (Gold sends them to no client).
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{ "func_clip", "func_monsterclip" };
pub const brush: context.Brush = .{ .hidden = true };
