#version 460
// SPDX-License-Identifier: GPL-2.0-or-later
// One Q3 material stage: vertex pulling, deforms, colour and texture-coordinate generation.
// Behaviour follows renderergl1/tr_shade_calc.c; CPU-time-only terms arrive precomputed.
#include "common.glsl"

layout(location = 0) out vec4 color;
layout(location = 1) out vec2 uv0;
layout(location = 2) out vec2 uv1;
layout(location = 3) out float eyeDepth;
layout(location = 4) out vec3 worldPos;
layout(location = 5) out vec3 worldNormal;
// Motion vectors (FLAG_MOTION): this frame's unjittered and the previous frame's clip position.
layout(location = 6) out vec4 motionCurrent;
layout(location = 7) out vec4 motionPrevious;
out gl_PerVertex { vec4 gl_Position; float gl_ClipDistance[1]; };
// The depth pre-pass and the shading pass must produce bit-identical depth (equal test).
invariant gl_Position;

const float TAU = 6.283185307179586;

float wave(float func, float x) {
    x = fract(x);
    if (func == 2.0) return x < 0.5 ? 1.0 : -1.0;
    if (func == 3.0) return x < 0.25 ? 4.0 * x : (x < 0.75 ? 2.0 - 4.0 * x : 4.0 * x - 4.0);
    if (func == 4.0) return x;
    if (func == 5.0) return 1.0 - x;
    return sin(x * TAU);
}

Vtx fetch(Record r, uint index) {
    Vtx v;
    uint kind = r.mode.x;
    if (kind == 1u) {
        // MD3: two frames of (position, normal), linear blend; separate texture coordinates.
        Floats a = Floats(r.vertices), b = Floats(r.frameB), st = Floats(r.extra);
        uint o = index * 6u;
        vec3 pa = vec3(a.v[o], a.v[o + 1u], a.v[o + 2u]), na = vec3(a.v[o + 3u], a.v[o + 4u], a.v[o + 5u]);
        vec3 pb = vec3(b.v[o], b.v[o + 1u], b.v[o + 2u]), nb = vec3(b.v[o + 3u], b.v[o + 4u], b.v[o + 5u]);
        float back = r.misc.x;
        v.pos = mix(pa, pb, back);
        v.normal = normalize(mix(na, nb, back));
        v.st = vec2(st.v[index * 2u], st.v[index * 2u + 1u]);
        v.lm = vec2(0.0);
        v.color = vec4(1.0);
    } else if (kind == 2u) {
        // IQM: linear-blend skinning with row-major 3x4 bone matrices.
        Floats f = Floats(r.vertices);
        Uints u = Uints(r.vertices);
        Floats bones = Floats(r.extra);
        uint o = index * 12u;
        vec4 p = vec4(f.v[o], f.v[o + 1u], f.v[o + 2u], 1.0);
        vec3 n = vec3(f.v[o + 3u], f.v[o + 4u], f.v[o + 5u]);
        v.st = vec2(f.v[o + 6u], f.v[o + 7u]);
        uvec4 bi = (uvec4(u.v[o + 8u]) >> uvec4(0, 8, 16, 24)) & 255u;
        vec4 bw = vec4((uvec4(u.v[o + 9u]) >> uvec4(0, 8, 16, 24)) & 255u) / 255.0;
        v.color = unpackUnorm4x8(u.v[o + 10u]);
        if (r.extra != uvec2(0u) && bw.x > 0.0) {
            vec3 sp = vec3(0.0), sn = vec3(0.0);
            for (int k = 0; k < 4; ++k) {
                if (bw[k] == 0.0) continue;
                uint m = bi[k] * 12u;
                vec4 r0 = vec4(bones.v[m], bones.v[m + 1u], bones.v[m + 2u], bones.v[m + 3u]);
                vec4 r1 = vec4(bones.v[m + 4u], bones.v[m + 5u], bones.v[m + 6u], bones.v[m + 7u]);
                vec4 r2 = vec4(bones.v[m + 8u], bones.v[m + 9u], bones.v[m + 10u], bones.v[m + 11u]);
                sp += bw[k] * vec3(dot(r0, p), dot(r1, p), dot(r2, p));
                sn += bw[k] * vec3(dot(r0.xyz, n), dot(r1.xyz, n), dot(r2.xyz, n));
            }
            v.pos = sp;
            v.normal = length(sn) > 0.0 ? normalize(sn) : n;
        } else {
            v.pos = p.xyz;
            v.normal = n;
        }
        v.lm = vec2(0.0);
    } else {
        Floats f = Floats(r.vertices);
        Uints u = Uints(r.vertices);
        uint o = index * 12u;
        v.pos = vec3(f.v[o], f.v[o + 1u], f.v[o + 2u]);
        v.st = vec2(f.v[o + 3u], f.v[o + 4u]);
        v.lm = vec2(f.v[o + 5u], f.v[o + 6u]);
        v.normal = vec3(f.v[o + 7u], f.v[o + 8u], f.v[o + 9u]);
        v.color = unpackUnorm4x8(u.v[o + 10u]);
    }
    return v;
}

// The vertex in the previous frame's pose: the previous MD3 frames and blend, or the previous
// skeleton; other meshes do not change shape.
vec3 previousPosition(Record r, uint index, vec3 current) {
    uint kind = r.mode.x;
    if (kind == 1u) {
        Floats a = Floats(r.prevVertices), b = Floats(r.prevFrameB);
        uint o = index * 6u;
        return mix(vec3(a.v[o], a.v[o + 1u], a.v[o + 2u]), vec3(b.v[o], b.v[o + 1u], b.v[o + 2u]), r.motion2.x);
    }
    if (kind == 2u && r.prevExtra != uvec2(0u)) {
        Floats f = Floats(r.vertices);
        Uints u = Uints(r.vertices);
        Floats bones = Floats(r.prevExtra);
        uint o = index * 12u;
        vec4 p = vec4(f.v[o], f.v[o + 1u], f.v[o + 2u], 1.0);
        uvec4 bi = (uvec4(u.v[o + 8u]) >> uvec4(0, 8, 16, 24)) & 255u;
        vec4 bw = vec4((uvec4(u.v[o + 9u]) >> uvec4(0, 8, 16, 24)) & 255u) / 255.0;
        if (bw.x == 0.0) return p.xyz;
        vec3 sp = vec3(0.0);
        for (int k = 0; k < 4; ++k) {
            if (bw[k] == 0.0) continue;
            uint m = bi[k] * 12u;
            vec4 r0 = vec4(bones.v[m], bones.v[m + 1u], bones.v[m + 2u], bones.v[m + 3u]);
            vec4 r1 = vec4(bones.v[m + 4u], bones.v[m + 5u], bones.v[m + 6u], bones.v[m + 7u]);
            vec4 r2 = vec4(bones.v[m + 8u], bones.v[m + 9u], bones.v[m + 10u], bones.v[m + 11u]);
            sp += bw[k] * vec3(dot(r0, p), dot(r1, p), dot(r2, p));
        }
        return sp;
    }
    return current;
}

vec3 deformed(Record r, Vtx v) {
    // deform[2k] = (type + 10 * waveFunc, ...), deform[2k + 1] = wave or move parameters.
    vec3 pos = v.pos;
    float time = r.viewOrigin.w;
    for (uint k = 0u; k < r.counts.y; ++k) {
        vec4 a = r.deform[k * 2u], b = r.deform[k * 2u + 1u];
        float type = mod(a.x, 10.0), func = floor(a.x / 10.0);
        if (type == 1.0) {            // wave: (base, amplitude, phase) | (frequency, spread)
            float off = (pos.x + pos.y + pos.z) * b.y;
            pos += v.normal * (a.y + wave(func, a.w + off + time * b.x) * a.z);
        } else if (type == 3.0) {     // bulge: (width, height, speed)
            pos += v.normal * sin(v.st.x * a.y + time * a.w) * a.z;
        } else if (type == 4.0) {     // move: (vector) | (base, amplitude, phase, frequency)
            pos += a.yzw * (b.x + wave(func, b.z + time * b.w) * b.y);
        }
    }
    return pos;
}

vec2 texgen(Record r, uint gen, Vtx v, vec3 pos) {
    if (gen == 1u) return v.lm;
    if (gen == 2u) {
        vec3 viewer = normalize(r.viewOrigin.xyz - pos);
        float d = dot(v.normal, viewer);
        vec3 reflected = v.normal * 2.0 * d - viewer;
        return vec2(0.5 + reflected.y * 0.5, 0.5 - reflected.z * 0.5);
    }
    if (gen == 3u) return vec2(dot(pos, r.tcGenVector[0].xyz), dot(pos, r.tcGenVector[1].xyz));
    if (gen == 4u) return vec2(0.0);
    return v.st;
}

vec2 texmods(Record r, vec2 st, vec3 pos) {
    for (uint k = 0u; k < r.counts.x; ++k) {
        vec4 a = r.tcmod[k * 2u], b = r.tcmod[k * 2u + 1u];
        if (a.x == 1.0) {
            // turb: amplitude, now (phase + time * frequency)
            vec2 t = st;
            st.x = t.x + sin(((pos.x + pos.z) * (1.0 / 128.0) * 0.125 + a.z) * TAU) * a.y;
            st.y = t.y + sin((pos.y * (1.0 / 128.0) * 0.125 + a.z) * TAU) * a.y;
        } else {
            // affine: s' = a.y*s + a.z*t + b.x ; t' = a.w*s + b.y*t + b.z
            st = vec2(a.y * st.x + a.z * st.y + b.x, a.w * st.x + b.y * st.y + b.z);
        }
    }
    return st;
}

void main() {
    Record r = Record(push.record);
    uint index = Uints(r.indices).v[gl_VertexIndex];
    Vtx v = fetch(r, index);
    vec3 pos = deformed(r, v);
    vec4 p = vec4(pos, 1.0);
    gl_Position = r.clip * p;
    motionCurrent = vec4(0.0);
    motionPrevious = vec4(0.0);
    if ((r.mode2.z & FLAG_MOTION) != 0u) {
        // The projection's sub-pixel jitter shifts NDC by r.motion.xy (taa.zig jitterProjection).
        motionCurrent = gl_Position - vec4(r.motion.xy * gl_Position.w, 0.0, 0.0);
        Vtx previous = v;
        previous.pos = previousPosition(r, index, v.pos);
        motionPrevious = r.prevClip * vec4(deformed(r, previous), 1.0);
    }
    eyeDepth = -dot(r.modelView[2], p);
    worldPos = vec3(dot(r.model[0], p), dot(r.model[1], p), dot(r.model[2], p));
    vec3 wn = vec3(dot(r.model[0].xyz, v.normal), dot(r.model[1].xyz, v.normal), dot(r.model[2].xyz, v.normal));
    worldNormal = dot(wn, wn) > 0.0 ? normalize(wn) : vec3(0.0, 0.0, 1.0);
    gl_ClipDistance[0] = (r.mode2.z & FLAG_CLIP) != 0u ? dot(worldPos, r.clipPlane.xyz) - r.clipPlane.w : 1.0;

    vec4 c = r.constColor;
    uint rgb = r.mode.y, alpha = r.mode.z;
    if (rgb == 1u) c.rgb = v.color.rgb * r.ambient.w;
    else if (rgb == 2u) c.rgb = vec3(1.0) - v.color.rgb * r.ambient.w;
    else if (rgb == 3u) {
        float incoming = dot(v.normal, r.lightDir.xyz);
        c.rgb = min(r.ambient.rgb + max(incoming, 0.0) * r.directed.rgb, vec3(1.0));
    } else if (rgb == 4u) c.rgb = v.color.rgb;
    if (alpha == 1u) c.a = v.color.a;
    else if (alpha == 2u) c.a = 1.0 - v.color.a;
    else if (alpha == 3u) {
        vec3 lightDir = normalize(vec3(-960.0, 1980.0, 96.0) - pos);
        float d = dot(v.normal, lightDir);
        vec3 reflected = v.normal * 2.0 * d - lightDir;
        vec3 viewer = r.viewOrigin.xyz - pos;
        float l = dot(reflected, viewer) / max(length(viewer), 1e-4);
        l = l < 0.0 ? 0.0 : l * l * l * l;
        c.a = min(l, 1.0);
    } else if (alpha == 4u) {
        c.a = clamp(distance(pos, r.viewOrigin.xyz) / max(r.lightDir.w, 1e-4), 0.0, 1.0);
    }
    color = c;
    uv0 = texmods(r, texgen(r, r.mode.w, v, pos), pos);
    uv1 = v.lm;
}
