// SPDX-License-Identifier: GPL-2.0-or-later
// Ray traced lighting (r_vkLighting 1, rt.zig `buildLights`): direct light from the map's light
// entities, emitting faces and sun instead of the baked lightmaps. Lights use the original
// radiosity tool's models (rt_common.glsl rtLightRaw) so levels stay close to the original;
// visibility is traced. Needs rt_common.glsl.
//
// Per receiver, the up to 63 lights of its 256-unit cell are evaluated; the four strongest get
// an exact shadow ray and the rest two importance-sampled ones, at most six rays.

const uint RT_LIGHT_SHADOWS = 4u;
const uint RT_LIGHT_SAMPLES = 2u;

// Profiling (r_vkRtCost 16): skip the importance-sampled shadow rays.
bool rtCostSkipSampled = false;
// r_vkDebugView 17-19 fill the shadow probe values below; off, they cost nothing.
bool rtDebugShadows = false;
// Per-sample randomness for area light shadow rays; callers set it (frame-varying).
vec2 rtLightJitter = vec2(0.5);
// r_vkDebugView 17: the strongest light's shadow ray: green clear; blocked red near the
// receiver (< 10%), yellow on the way, blue near the light (> 90%).
vec3 rtShadowDebug = vec3(0.0);
// r_vkDebugView 18: the albedo of what blocks that ray (black: nothing).
vec3 rtShadowBlocker = vec3(0.0);
// r_vkDebugView 19: the four shadow-tested lights (index, luminance, distance, blocked, hit fraction).
uint rtProbeIndex[4] = uint[](0u, 0u, 0u, 0u);
vec4 rtProbeLight[4] = vec4[](vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0));

// Summed light in the radiosity tool's units (255 = a fully lit lightmap texel).
// The four strongest lights live in plain variables (fixed-position compare and swap): array
// slots picked at run time would spill to local memory on the GPU. They keep only weight and
// index; the few lights that get a ray recompute their light afterwards (registers are what
// limit how many fragments the GPU keeps in flight).
struct RtTop { float w; uint index; };

void rtTopSwap(inout RtTop a, inout RtTop b) {
    if (b.w > a.w) { RtTop t = a; a = b; b = t; }
}

// Streams one light into the two weighted reservoirs (one uniform number each, rescaled).
void rtReservoirFeed(RtTop x, inout float weightSum, inout float u0, inout float u1, inout RtTop s0, inout RtTop s1) {
    weightSum += x.w;
    float keep = x.w / weightSum;
    if (u0 < keep) { s0 = x; u0 = u0 / keep; } else u0 = (u0 - keep) / (1.0 - keep);
    if (u1 < keep) { s1 = x; u1 = u1 / keep; } else u1 = (u1 - keep) / (1.0 - keep);
}

// Shadow ray to one light; true when it reaches it.
bool rtLightVisible(uvec2 tableAddress, RtFloats lights, uint index, vec2 jitter, vec3 rayOrigin, out float dist) {
    vec3 origin = rtLightPoint(lights, index, jitter, rayOrigin);
    vec3 d = origin - rayOrigin;
    dist = length(d);
    // Stop short of the light: map lights often sit just inside their fixture.
    return !rtOccluded(tableAddress, rayOrigin, d / max(dist, 1e-3), dist - 12.0);
}

void rtShadowProbe(uvec2 tableAddress, RtFloats lights, uint slot, RtTop top, vec3 raw, vec2 jitter, vec3 rayOrigin, bool reached, float dist) {
    if (!rtDebugShadows) return;
    vec3 origin = rtLightPoint(lights, top.index, jitter, rayOrigin);
    vec3 dir = (origin - rayOrigin) / max(dist, 1e-3);
    rtProbeIndex[slot] = top.index;
    rtProbeLight[slot] = vec4(dot(raw, vec3(0.2126, 0.7152, 0.0722)), dist, reached ? 0.0 : 1.0,
                              rtHitDistance(tableAddress, rayOrigin, dir, max(dist - 12.0, 0.0)) / max(dist - 12.0, 1e-3));
    if (slot == 0u) {
        float f = rtProbeLight[0].w;
        rtShadowDebug = reached ? vec3(0.0, 1.0, 0.0) : f < 0.1 ? vec3(1.0, 0.0, 0.0) : f > 0.9 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 1.0, 0.0);
        RtHit h = rtTrace(tableAddress, rayOrigin, dir, dist - 12.0, 0.0);
        rtShadowBlocker = h.hit ? h.albedo + vec3(0.05) : vec3(0.0);
    }
}

vec3 rtMapLightRaw(uvec2 tableAddress, uvec2 lightsAddress, uvec2 cellsAddress, vec4 cellOrigin, uvec3 cellDims,
                   vec3 pos, vec3 n, vec3 rayOrigin, uint shadowRays) {
    if (cellsAddress == uvec2(0u) || cellDims.x == 0u) return vec3(0.0);
    ivec3 cell = clamp(ivec3(floor((pos - cellOrigin.xyz) / cellOrigin.w)), ivec3(0), ivec3(cellDims) - 1);
    uint base = uint((cell.z * int(cellDims.y) + cell.y) * int(cellDims.x) + cell.x) * RT_CELL_STRIDE;
    RtWords list = RtWords(cellsAddress);
    RtFloats lights = RtFloats(lightsAddress);
    uint count = min(list.v[base], RT_LIGHTS_PER_CELL);
    uint visBase = cellDims.x * cellDims.y * cellDims.z * RT_CELL_STRIDE + base + 1u;
    vec3 total = vec3(0.0);
    RtTop t0 = RtTop(0.0, 0xffffffffu), t1 = t0, t2 = t0, t3 = t0;
    // One pass: the sum, the four strongest (exact shadow rays) and two weighted reservoirs over
    // the other lights only: a light enters the reservoirs when it misses the top four or is
    // pushed out of them, so each sample estimates the rest without bias and with the variance
    // of sampling the rest alone (sampling every light and discarding the top ones speckled).
    float seed = fract(dot(pos, vec3(0.1031, 0.1030, 0.0973)) * 43.7585 + rtLightJitter.x * 7.31 + rtLightJitter.y * 3.17);
    float u0 = seed, u1 = fract(seed + 0.618034);
    RtTop s0 = RtTop(0.0, 0xffffffffu), s1 = s0;
    float weightSum = 0.0;
    for (uint k = 0u; k < count; ++k) {
        // No ray from this cell reached the light: it cannot light the receiver.
        uint seen = list.v[visBase + k];
        if (seen == 0u) continue;
        uint index = list.v[base + 1u + k];
        vec3 raw = rtLightRaw(lights, index, pos, n);
        float weight = dot(raw, vec3(0.2126, 0.7152, 0.0722)) * float(seen) * (1.0 / float(RT_VISIBILITY_RAYS));
        if (weight <= 0.0) continue;
        total += raw;
        RtTop light = RtTop(weight, index);
        if (weight > t3.w) {
            RtTop evicted = t3;
            t3 = light;
            rtTopSwap(t2, t3);
            rtTopSwap(t1, t2);
            rtTopSwap(t0, t1);
            light = evicted;
        }
        if (light.w > 0.0) rtReservoirFeed(light, weightSum, u0, u1, s0, s1);
    }
    uint exact = min(shadowRays, RT_LIGHT_SHADOWS);
    if (exact == 0u) return total;
    // Top lights without an exact ray of their own (fewer shadow rays) join the sampled rest.
    if (exact < 4u && t3.w > 0.0) rtReservoirFeed(t3, weightSum, u0, u1, s0, s1);
    if (exact < 3u && t2.w > 0.0) rtReservoirFeed(t2, weightSum, u0, u1, s0, s1);
    if (exact < 2u && t1.w > 0.0) rtReservoirFeed(t1, weightSum, u0, u1, s0, s1);
    // Up to six shadow rays in one loop (the exact top lights, then the two reservoir picks):
    // one copy of the ray query code instead of six keeps the shader small enough to run more
    // fragments at once. The light is picked by conditional selects, not an indexed array.
    vec3 tested = vec3(0.0), visible = vec3(0.0), estimate = vec3(0.0);
    bool sampleRest = true;
    for (uint j = 0u; j < RT_LIGHT_SHADOWS + RT_LIGHT_SAMPLES; ++j) {
        bool sampled = j >= RT_LIGHT_SHADOWS;
        if (j == RT_LIGHT_SHADOWS) {
            if (rtCostSkipSampled) return visible + (total - tested);
            // The other lights: the reservoirs' picks, each standing for weightSum / its weight.
            sampleRest = dot(total - tested, vec3(0.2126, 0.7152, 0.0722)) > 1e-3;
        }
        if (sampled ? !sampleRest : j >= exact) continue;
        RtTop t = j == 0u ? t0 : j == 1u ? t1 : j == 2u ? t2 : j == 3u ? t3 : j == 4u ? s0 : s1;
        if (t.w <= 0.0) continue;
        vec2 jitter = sampled ? fract(rtLightJitter.yx + vec2(0.382, 0.618) * float(j - RT_LIGHT_SHADOWS + 1u))
                              : fract(rtLightJitter + vec2(0.618, 0.382) * float(j));
        float dist;
        bool reached = rtLightVisible(tableAddress, lights, t.index, jitter, rayOrigin, dist);
        vec3 raw = rtLightRaw(lights, t.index, pos, n);
        if (sampled) {
            if (reached) estimate += raw * (weightSum / t.w);
        } else {
            tested += raw;
            if (reached) visible += raw;
            rtShadowProbe(tableAddress, lights, j, t, raw, jitter, rayOrigin, reached, dist);
        }
    }
    return visible + estimate * (1.0 / float(RT_LIGHT_SAMPLES));
}

// The same for a point in the air (light shafts): no surface, so no cosine; lights are only
// visibility-tested, not shaded.
vec3 rtMapLightRawIsotropic(uvec2 tableAddress, uvec2 lightsAddress, uvec2 cellsAddress, vec4 cellOrigin, uvec3 cellDims,
                            vec3 pos, uint shadowRays) {
    if (cellsAddress == uvec2(0u) || cellDims.x == 0u) return vec3(0.0);
    ivec3 cell = clamp(ivec3(floor((pos - cellOrigin.xyz) / cellOrigin.w)), ivec3(0), ivec3(cellDims) - 1);
    uint base = uint((cell.z * int(cellDims.y) + cell.y) * int(cellDims.x) + cell.x) * RT_CELL_STRIDE;
    RtWords list = RtWords(cellsAddress);
    RtFloats lights = RtFloats(lightsAddress);
    uint count = min(list.v[base], RT_LIGHTS_PER_CELL);
    vec3 total = vec3(0.0), tested = vec3(0.0), visible = vec3(0.0);
    float strongest[2] = float[](0.0, 0.0);
    uint strongestIndex[2] = uint[](0u, 0u);
    vec3 strongestRaw[2] = vec3[](vec3(0.0), vec3(0.0));
    for (uint k = 0u; k < count; ++k) {
        uint index = list.v[base + 1u + k];
        if (rtVisibility(list, cellDims, base + 1u + k) == 0u) continue;
        vec3 raw = rtLightRaw(lights, index, pos, vec3(0.0));
        if (raw == vec3(0.0)) continue;
        total += raw;
        float weight = dot(raw, vec3(0.2126, 0.7152, 0.0722));
        if (weight > strongest[0]) {
            strongest[1] = strongest[0]; strongestIndex[1] = strongestIndex[0]; strongestRaw[1] = strongestRaw[0];
            strongest[0] = weight; strongestIndex[0] = index; strongestRaw[0] = raw;
        } else if (weight > strongest[1]) {
            strongest[1] = weight; strongestIndex[1] = index; strongestRaw[1] = raw;
        }
    }
    for (uint j = 0u; j < min(shadowRays, 2u); ++j) {
        if (strongest[j] <= 0.0) break;
        uint index = strongestIndex[j];
        vec3 d = rtLightPoint(lights, index, vec2(0.5), pos) - pos;
        float dist = length(d);
        tested += strongestRaw[j];
        if (!rtOccluded(tableAddress, pos, d / max(dist, 1e-3), dist - 12.0)) visible += strongestRaw[j];
    }
    float testedWeight = dot(tested, vec3(0.2126, 0.7152, 0.0722));
    float fraction = testedWeight > 0.0 ? dot(visible, vec3(0.2126, 0.7152, 0.0722)) / testedWeight : 1.0;
    return visible + (total - tested) * fraction;
}

// Radiosity units to linear radiance, as world.zig `linearLight` converts baked lightmaps: the
// lightmap scale, the overbright shift, each texel normalised so its brightest channel keeps a
// quarter stop of headroom above white, then display gamma removed.
// The inverse (without the headroom curve): linear light back to radiosity units, so light
// computed in linear space (probe bounce) joins the sum before the conversion.
vec3 rtLinearToRaw(vec3 linear, float scale, float overbright) {
    return pow(max(linear, vec3(0.0)), vec3(1.0 / 2.2)) / max(overbright, 1e-3) / max(scale, 1e-3) * 255.0;
}

vec3 rtRawToLinear(vec3 raw, float scale, float overbright) {
    vec3 v = min(raw / 255.0 * scale, vec3(1.0)) * overbright;
    float peak = max(v.r, max(v.g, v.b));
    if (peak > 1.0) v *= (1.0 + 0.25 * (1.0 - exp(-(peak - 1.0)))) / peak;
    return pow(v, vec3(2.2));
}
