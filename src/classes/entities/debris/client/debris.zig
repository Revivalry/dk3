// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: debris. Client render class: flying debris draws its brush model.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("../domain/debris.zig").render_tag;
pub const inline_model = true;
