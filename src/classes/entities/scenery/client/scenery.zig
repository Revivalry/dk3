// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: scenery. Client render class: props, corpses, gibs and chunks: they fade and gibs bleed.
const std = @import("std");
const c = @import("../../../../engine/abi.zig").c;
const engine = @import("../../../../engine/client.zig");
const v = @import("../../../../core/domain/vector.zig");
const sprites = @import("../../../../core/client/sprites.zig");
const trajectory = @import("../../../../engine/trajectory.zig");
const context = @import("../../../../mechanics/client/render_classes/context.zig");
pub const body_tag = @import("../../../../mechanics/domain/props.zig").render_tag;
pub fn decorate(model: *context.Model) !void {
    const entity = model.draw.entity;
    if (entity.weapon & 1 != 0) model.draw.counters.gibs += 1;
    if (entity.weapon & 8 != 0) model.draw.counters.chunks += 1;
    if (entity.weapon & 1 != 0) @import("../../../../mechanics/client/gibs.zig").emit(entity, model.rendered.origin, model.draw.now);
    model.rendered.shaderRGBA[3] = @intCast(std.math.clamp(entity.time2, 0, 255));
    if (entity.clientNum > 0) model.rendered.customShader = try @import("../../../../mechanics/client/models.zig").firstMaterial(model.draw.game, entity.clientNum);
}
