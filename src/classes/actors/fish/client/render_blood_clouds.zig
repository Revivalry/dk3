// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: fish. Render class: the dopefish's blood cloud particle emitters.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("../domain/blood_cloud.zig").render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    @import("blood_clouds.zig").emit(draw.entity, draw.now);
    return true;
}
