// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: laser_beam. Client render class: authored laser beams and their hum.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("../../../../mechanics/domain/laser.zig").render_tag;
pub fn drawEffect(draw: *context.Draw) !bool {
    try @import("../../../../mechanics/client/events.zig").loop(draw.game, draw.entity, trajectory.evaluate(draw.entity.pos, draw.now));
    @import("lasers.zig").draw(draw.entity, draw.now, draw.ref);
    return true;
}
