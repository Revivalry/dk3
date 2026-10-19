// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: speaker. Client render class: authored sound emitters.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("../../../../core/domain/audio.zig").parameter_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    try @import("../../../../mechanics/client/events.zig").loop(draw.game, draw.entity, trajectory.evaluate(draw.entity.pos, draw.now));
    return true;
}
