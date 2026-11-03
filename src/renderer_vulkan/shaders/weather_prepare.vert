#version 460
// SPDX-License-Identifier: GPL-2.0-or-later
// Shared mechanism: one vertex-stage basis calculation for all four splash corners.
#include "common.glsl"
#include "weather_style.glsl"
#include "weather_state.glsl"
layout(buffer_reference, std430, buffer_reference_align = 16) writeonly buffer PreparedOutput {
    vec4 data[];
};
out gl_PerVertex { vec4 gl_Position; float gl_PointSize; };
invariant gl_Position;

void main() {
    gl_Position = vec4(0.0);
    gl_PointSize = 1.0;
    Record r = Record(push.record);
    uint particle = uint(gl_VertexIndex);
    if (particle >= r.counts.w) return;
    WeatherState state = weatherState(r, particle);
    PreparedOutput prepared = PreparedOutput(r.extra);
    uint base = particle * 5u;
    for (uint corner = 0u; corner < 4u; ++corner) {
        vec2 q = vec2(float(corner & 1u), float(corner >> 1u));
        vec4 p = vec4(weatherPosition(state, q), 1.0);
        prepared.data[base + corner] = vec4(p.xyz, 0.0);
        gl_Position = r.clip * p;
    }
    prepared.data[base + 4u] = state.color;
}
