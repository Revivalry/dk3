# Rendering pipeline

The client submits the world, models, lights, weather and interface to a renderer
through the engine's export API. Vulkan and the two OpenGL renderers consume the same
game scene, but use different rendering pipelines.

## Vulkan and OpenGL

Vulkan is the default renderer and requires Vulkan 1.3. Its remaster pipeline adds
HDR processing, material response, volumetric effects and temporal reconstruction.
Ray queries are an optional device capability.

OpenGL1 follows the classic fixed-function presentation. OpenGL2 provides the
bundled shader-based alternative. Selecting an OpenGL renderer does not change
simulation, saves or multiplayer rules.

## The world image

With the remaster enabled, Vulkan draws the world into a linear HDR target. The
pipeline combines surface materials, lighting, liquids, volumetrics and weather,
then resolves the image temporally. Exposure, bloom and tone mapping prepare it
for display. A separate overlay keeps the menu and HUD at output resolution.

Materials can use generated normal/specular maps. Without those maps, the renderer
can use its procedural material response. Authored fog, lightstyles and weather
remain inputs from the map.

The classic Vulkan path selected by `r_vkRemaster=0` bypasses the remaster pipeline.
It is useful when you want classic presentation while retaining Vulkan as the backend.

## Lightmaps and ray queries

The raster path can use baked map lighting and shadow-mapped model shadows. On an
RT-capable device, the renderer can trace visibility from map lights, shadows and
reflections. Irradiance probes provide ambient lighting, while optional path tracing
computes a more expensive world-lighting result.

Alpha-tested world surfaces can block rays. GPU-skinned characters participate in
shadow rays, but do not have a complete reflected-hit shading implementation.

Disabling ray tracing keeps the Vulkan raster path. Device support and scene workload
determine the cost of RT; changing it does not require changing the game simulation.

## Temporal reconstruction

The renderer can draw the world below output resolution, then reconstruct the output
using motion, depth and prior frames. FSR 3.1 shaders are included. DLSS uses an
external runtime installed by the user; automatic selection falls back to FSR when
that runtime is unavailable.

Reducing each dimension to one half reduces the world pixel count to one quarter.
This can lower rendering cost, while reconstruction and history management add
their own work. The HUD and menu are composed at output resolution.

Motion history matches an entity to the nearest previous entity with the same model.
Scenes with several identical models can therefore expose reconstruction artifacts.

For commands and defaults, use the [renderer reference](../reference/rendering.md).
For a settings walkthrough, see [Configure resolution and upscaling](../how-to/configure-video.md).
