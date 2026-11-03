#version 460
// SPDX-License-Identifier: GPL-2.0-or-later
// Shared mechanism: weather shapes and authored volume fog, without material paths.
#include "common.glsl"
layout(location = 0) in vec4 color;
layout(location = 1) in vec2 uv0;
layout(location = 3) in float eyeDepth;
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec2 outMotion;

// Weather particle shapes (mesh kind 3): streaks, round flakes and splash crowns.
float weatherShape(Record r, vec2 q) {
    WeatherParams w = WeatherParams(r.vertices);
    vec2 p = q * 2.0 - 1.0;
    if (w.eye.w > 0.5) {
        // Crown: a thin rim rising from the impact point (q.y = 0 at the surface).
        float rim = length(vec2(p.x, q.y * 1.6 - 0.15));
        return smoothstep(0.55, 0.8, rim) * (1.0 - smoothstep(0.85, 1.0, rim)) * (1.0 - smoothstep(0.7, 1.0, q.y));
    }
    if (w.mins.w > 0.5) return 1.0 - smoothstep(0.25, 1.0, length(p));
    // Streak: Gaussian across, soft ends, and a faint brightness wobble along the length from
    // the drop's shape oscillation (Garg & Nayar).
    float across = exp(-p.x * p.x * 3.0);
    float ends = smoothstep(0.0, 0.18, q.y) * (1.0 - smoothstep(0.82, 1.0, q.y));
    return across * ends * (0.8 + 0.2 * sin(q.y * 15.0));
}

void main() {
    Record r = Record(push.record);
    uint flags = r.mode2.z;
    bool linear = (flags & FLAG_LINEAR) != 0u;
    // Weather has no depth-writing stage and never writes object motion vectors.
    outMotion = vec2(0.0);
    // Weather particles arrive lit in linear light (stage.vert weatherLight); flakes are white.
    WeatherParams w = WeatherParams(r.vertices);
    vec3 lit = color.rgb * (w.mins.w > 0.5 ? 0.9 : 1.0);
    vec4 c = vec4(lit, color.a * weatherShape(r, uv0));
    if ((flags & FLAG_VOLUME) != 0u && r.view != uvec2(0u)) {
        ViewData view = ViewData(r.view);
        vec2 suv = (gl_FragCoord.xy - view.rect.xy) / view.rect.zw;
        float wz = log(max(eyeDepth, 1e-3) / view.froxel.x) * view.froxel.y;
        vec4 fog = texture(volumes[nonuniformEXT(view.slots.x)], vec3(clamp(suv, 0.0, 1.0), clamp(wz, 0.0, 1.0)));
        c.rgb = c.rgb * pow(clamp(fog.a, 0.0, 1.0), 2.2) + fog.rgb * pow(1.0 - clamp(fog.a, 0.0, 1.0), 1.2);
    }
    if (!linear) c.rgb = pow(min(c.rgb, vec3(1.0)), vec3(1.0 / 2.2));
    outColor = c;
    return;
}
