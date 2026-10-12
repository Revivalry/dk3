// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: area_portal. Editor area portals: no spawn function in the reference, so no brush of their own (e1m2b keeps a misspelled one as *40).
const std = @import("std");
const data = @import("../../../../game/domain/components.zig");
const engine = @import("../../../../engine/server.zig");
const c = @import("../../../../engine/abi.zig").c;
const prop = @import("../../../../mechanics/server/properties.zig");
const context = @import("../../../../mechanics/server/entity_classes/context.zig");
pub const classnames = [_][]const u8{ "func_areaportal", "func_areaportalass" };
pub const brush: context.Brush = .{ .bound = false };
