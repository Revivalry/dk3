// SPDX-License-Identifier: GPL-2.0-or-later
// Shared mechanism: per-particle weather basis and original per-corner expansion.
#include "weather_division.glsl"
struct WeatherState {
    vec3 base;
    vec3 right;
    vec3 up;
    float size;
    vec4 color;
    bool has_position;
};

// Indexed weather: four distinct corner IDs per particle (weather.zig).
// Where the drop of cycle `cycleIndex` lands: the first surface of the rain occlusion map under
// its slanted path (two refinements), or the volume floor; `tHit` is its fall time.
void weatherLanding(WeatherParams w, ViewData view, uint mapSlot, bool mapped, vec2 tileCoord, float local, float cycleIndex, float speed, out vec2 xy, out float z, out float tHit) {
    vec4 h = hash4(vec3(tileCoord + cycleIndex * vec2(0.618, 0.414), local));
    vec2 start = (tileCoord + h.xy) * WEATHER_TILE;
    float height = w.maxs.z - w.mins.z;
    xy = start + w.velocity.xy * (height / speed);
    z = w.mins.z;
    if (mapped) {
        float s0 = clamp(rainSurface(view, mapSlot, xy), w.mins.z, w.maxs.z);
        xy = start + w.velocity.xy * ((w.maxs.z - s0) / speed);
        z = clamp(rainSurface(view, mapSlot, xy), w.mins.z, w.maxs.z);
    }
    tHit = (w.maxs.z - z) / speed;
}

// Light reaching a drop or flake at `pos` seen from `toEye`: the light grid (ambient plus its
// dominant direction), the open sky, and dynamic lights. Drops act as tiny wide-angle lenses
// that send most light forward, so lights behind a drop make it glint (Garg & Nayar 2006).
vec3 weatherLight(Record r, WeatherParams w, vec3 pos, vec3 toEye, bool snow) {
    float g = snow ? 0.2 : 0.75;
    vec3 light = vec3(0.12);
    if (w.grid0.w > 0.5) {
        vec3 uvw = (pos - w.grid0.xyz) * w.grid1.xyz;
        // Grid sampler indices come from immutable, draw-wide weather parameters.
        vec3 grid = toLinear(texture(volumes[uint(w.grid0.w) - 1u], uvw).rgb);
        // A drop refracts its bright surroundings (165 degree field), so it reads a little
        // brighter than the scene's ambient light.
        light = grid * 0.45;
        if (w.grid1.w > 0.5) {
            vec4 d = texture(volumes[uint(w.grid1.w) - 1u], uvw);
            vec3 l = normalize(d.xyz * 2.0 - 1.0);
            light += grid * d.a * 0.1 * phaseHG4pi(dot(-l, toEye), g);
        }
    }
    light += w.sky.rgb * 0.3;
    Lights lights = Lights(r.lights);
    uint count = min(r.counts.z, 32u);
    for (uint k = 0u; k < count; ++k) {
        vec4 a = lights.v[k * 2u], b = lights.v[k * 2u + 1u];
        vec3 toLight = a.xyz - pos;
        float dist = length(toLight);
        if (dist >= a.w) continue;
        float fall = 1.0 - dist / a.w;
        light += toLinear(b.rgb) * fall * fall * 0.15 * phaseHG4pi(dot(-toLight / max(dist, 1e-3), toEye), g);
    }
    return light;
}

// Rain gusts: large drifting cells of denser and thinner rain.
float weatherGust(WeatherParams w, vec2 xy, float time) {
    vec2 drift = w.velocity.xy * 0.25 * time + vec2(time * 40.0, time * 23.0);
    return mix(0.4, 1.0, valueNoise((xy - drift) / 1500.0));
}

WeatherState weatherState(Record r, uint particle) {
    WeatherParams w = WeatherParams(r.vertices);
    WeatherState state;
    state.base = w.eye.xyz;
    state.right = vec3(0.0);
    state.up = vec3(0.0);
    state.size = 1.0;
    state.color = vec4(0.0);
    state.has_position = false;
    uint perTile = max(uint(w.tiles.w), 1u);
    uint tile = weatherQuotient(particle, perTile, w.divisions.x);
    uint row = uint(w.tiles.z);
    uint tileRow = weatherQuotient(tile, row, w.divisions.y);
    vec2 tileCoord = w.tiles.xy + vec2(float(tile - tileRow * row), float(tileRow));
    float local = float(particle - tile * perTile);
    bool snow = WEATHER_IS_SNOW;
    float time = w.maxs.w;
    float height = w.maxs.z - w.mins.z;
    vec4 h0 = hash4(vec3(tileCoord, local + w.velocity.w * 0.37));
    // Rejected splash seeds keep the same empty vertex without evaluating terminal speed.
    if (WEATHER_IS_SPLASH && h0.x > 0.7) return state;
    // Rain: drop diameter 1-3 mm (inches here), skewed small; terminal velocity from the
    // Gunn-Kinzer fit v = 9.65 - 10.3 exp(-0.6 D[mm]) m/s, 160-310 in/s.
    float diameter = mix(0.04, 0.12, h0.w * h0.w);
    float speed = snow ? max(-w.velocity.z, 1.0) * (0.75 + 0.5 * h0.w)
                       : (9.65 - 10.3 * exp(-0.6 * diameter * 25.4)) * 39.37;
    float cycle = time * speed / height + h0.z;
    float f = fract(cycle);
    float cycleIndex = floor(cycle);
    bool splash = WEATHER_IS_SPLASH;
    // Rain occlusion map (shadows.zig rainCamera): nothing falls under a roof.
    ViewData view = ViewData(r.view);
    bool mapped = false;
    uint mapSlot = 0u;
    if (r.view != uvec2(0u)) {
        mapped = view.rain.w > 0.5;
        mapSlot = view.shadows.y;
    }
    if (splash) {
        // The landing of this cycle's drop, or of the previous one just after a cycle wrap.
        float elapsed = f * height / speed;
        vec2 xy;
        float z, tHit;
        weatherLanding(w, view, mapSlot, mapped, tileCoord, local, cycleIndex, speed, xy, z, tHit);
        float age = elapsed - tHit;
        if (age < 0.0) {
            weatherLanding(w, view, mapSlot, mapped, tileCoord, local, cycleIndex - 1.0, speed, xy, z, tHit);
            age = elapsed + height / speed - tHit;
        }
        // A crown 0.5-1.5 in across lasting 60-120 ms; drops landing in puddles only ripple.
        float life = mix(0.06, 0.12, h0.y);
        if (age < 0.0 || age > life) return state;
        if (any(lessThan(xy, w.mins.xy)) || any(greaterThan(xy, w.maxs.xy))) return state;
        if (puddleNoise(xy) > 0.5) return state;
        vec3 base = vec3(xy, z + 0.1);
        vec3 toEye = w.eye.xyz - base;
        float dist = length(toEye);
        toEye /= max(dist, 1e-3);
        float t = age / life;
        float radius = mix(0.5, 1.5, h0.x / 0.7) * (0.4 + 0.6 * sqrt(t));
        float pixel = w.shape.y * dist;
        float coverage = clamp(2.0 * radius / max(pixel, 1e-4), 0.0, 1.0);
        vec3 right = normalize(cross(vec3(0.0, 0.0, 1.0), toEye) + vec3(1e-4, 0.0, 0.0)) * max(radius, pixel * 0.5);
        vec3 up = vec3(0.0, 0.0, max(radius * 1.2, pixel));
        state.base = base;
        state.right = right;
        state.up = up;
        state.has_position = true;
        state.color.rgb = weatherLight(r, w, base, toEye, false);
        state.color.a = w.shape.z * 1.5 * coverage * (1.0 - t) * (1.0 - smoothstep(600.0, 800.0, dist));
        return state;
    }
    vec4 h = hash4(vec3(tileCoord + cycleIndex * vec2(0.618, 0.414), local));
    float fallTime = f * height / speed;
    vec2 start = (tileCoord + h.xy) * WEATHER_TILE;
    vec3 pos = vec3(start + w.velocity.xy * fallTime, w.maxs.z - f * height);
    if (snow) pos.xy += vec2(sin(time * 0.9 + h.z * 6.283), cos(time * 0.7 + h.w * 6.283)) * (10.0 + 8.0 * h.z);
    if (any(lessThan(pos.xy, w.mins.xy)) || any(greaterThan(pos.xy, w.maxs.xy))) return state;
    if (mapped && pos.z < rainSurface(view, mapSlot, pos.xy) - 1.0) return state;
    vec3 toEye = w.eye.xyz - pos;
    float dist = length(toEye);
    toEye /= max(dist, 1e-3);
    float gust = weatherGust(w, pos.xy, time);
    state.color.rgb = weatherLight(r, w, pos, toEye, snow);
    if (snow) {
        float alpha = w.shape.z * smoothstep(8.0, 48.0, dist) * (1.0 - smoothstep(1400.0, 2000.0, dist));
        vec3 right = normalize(cross(vec3(0.0, 0.0, 1.0), toEye) + vec3(1e-4, 0.0, 0.0));
        vec3 up = cross(toEye, right);
        float size = 2.2 * (0.7 + 0.6 * h.w) * (1.0 + dist * 0.0015);
        state.base = pos;
        state.right = right;
        state.up = up;
        state.size = size;
        state.has_position = true;
        state.color.a = alpha * gust;
        return state;
    }
    // Streak: the drop's path during the exposure, at least one pixel wide. Coverage-preserving
    // alpha keeps a far streak as faint as the drop really is, instead of a widening grey bar.
    vec3 dir = normalize(vec3(w.velocity.xy, -speed));
    float pixel = w.shape.y * dist;
    float width = max(diameter, pixel);
    float len = max(speed * w.shape.x, pixel * 2.0);
    vec3 right = normalize(cross(dir, toEye) + vec3(1e-4, 0.0, 0.0)) * width;
    state.base = pos;
    state.right = right;
    state.up = dir * len;
    state.has_position = true;
    float near = smoothstep(4.0, 24.0, dist);
    float far = 1.0 - smoothstep(600.0, 800.0, dist);
    // Coverage falls off a little slower than the true drop/pixel ratio: heavy rain reads as
    // a dense field of fine streaks, as it does on camera.
    state.color.a = w.shape.z * pow(diameter / width, 0.6) * near * far * gust;
    return state;
}

vec3 weatherPosition(WeatherState state, vec2 q) {
    if (!state.has_position) return state.base;
    if (WEATHER_IS_SPLASH) return state.base + state.right * (q.x * 2.0 - 1.0) + state.up * q.y;
    if (WEATHER_IS_SNOW) return state.base + (state.right * (q.x * 2.0 - 1.0) + state.up * (q.y * 2.0 - 1.0)) * state.size;
    return state.base + state.right * (q.x * 2.0 - 1.0) - state.up * q.y;
}
