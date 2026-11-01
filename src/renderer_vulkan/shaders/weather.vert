#version 460
// SPDX-License-Identifier: GPL-2.0-or-later
// Shared mechanism: indexed weather corners, with optional per-particle preparation.
#include "common.glsl"
#include "weather_style.glsl"
#include "weather_state.glsl"
layout(location = 0) out vec4 color;
layout(location = 1) out vec2 uv0;
layout(location = 3) out float eyeDepth;
out gl_PerVertex { vec4 gl_Position; float gl_ClipDistance[1]; };
invariant gl_Position;

layout(buffer_reference, std430, buffer_reference_align = 16) readonly buffer PreparedWeather {
    vec4 data[];
};

void main() {
    Record r = Record(push.record);
    uint index = uint(gl_VertexIndex);
    vec2 q = vec2(float(index & 1u), float((index >> 1u) & 1u));
    vec3 position;
    vec4 particleColor;
    if (WEATHER_STYLE == 3u) {
        PreparedWeather prepared = PreparedWeather(r.extra);
        uint base = (index / 4u) * 5u;
        position = prepared.data[base + index % 4u].xyz;
        particleColor = prepared.data[base + 4u];
    } else {
        WeatherState state = weatherState(r, index / 4u);
        position = weatherPosition(state, q);
        particleColor = state.color;
    }
    vec4 p = vec4(position, 1.0);
    gl_Position = r.clip * p;
    eyeDepth = -dot(r.modelView[2], p);
    vec3 worldPos = vec3(dot(r.model[0], p), dot(r.model[1], p), dot(r.model[2], p));
    gl_ClipDistance[0] = (r.mode2.z & FLAG_CLIP) != 0u ? dot(worldPos, r.clipPlane.xyz) - r.clipPlane.w : 1.0;
    color = vec4(particleColor.rgb * r.ambient.w, particleColor.a);
    uv0 = q;
}
