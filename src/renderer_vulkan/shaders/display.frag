#version 460
// SPDX-License-Identifier: GPL-2.0-or-later
// Single-texture display stage: no secondary texture, lights, fog or motion.
#include "common.glsl"
layout(location = 0) in vec4 color;
layout(location = 1) in vec2 uv0;
layout(location = 0) out vec4 outColor;
void main() {
    Record r = Record(push.record);
    vec4 c = texture(textures[nonuniformEXT(r.mode2.x)], uv0) * color;
    if (alphaRejected(c.a, r.mode2.w)) discard;
    if ((r.mode2.z & FLAG_OVERLAY_OPAQUE) != 0u) c.a = 1.0;
    outColor = c;
}
