# Renderer settings

Console variables below use their registration defaults. Existing profiles, menus
and launch arguments can override them. Vulkan-specific settings use the `r_vk`
prefix and have no effect in the OpenGL renderers.

Use `vid_restart` after changing a setting marked **Restart**. Other settings can
be changed while the renderer is running.

## Renderer and display

| Variable | Default | Meaning | Restart |
| --- | --- | --- | --- |
| `cl_renderer` | `vulkan` | `vulkan`, `opengl2` or `opengl1` | Yes |
| `r_mode` | `-2` | `-2`: desktop drawable; `-1`: custom dimensions; nonnegative: indexed video mode | Yes |
| `r_fullscreen` | `1` | Fullscreen rather than windowed display | Use `vid_restart` when changing display setup |
| `r_customwidth` | `1600` | Width when `r_mode=-1` | Yes |
| `r_customheight` | `1024` | Height when `r_mode=-1` | Yes |
| `r_customPixelAspect` | `1` | Custom pixel aspect ratio | Yes |
| `r_noborder` | `0` | Borderless window | Yes |
| `r_allowResize` | `0` | Allow window resizing | Yes |
| `r_centerWindow` | `0` | Center the window | Yes |
| `r_swapInterval` | `0` | Presentation synchronization interval | No |
| `r_vkDevice` | `-1` | Automatic Vulkan device selection; nonnegative values select a device index | Yes |

Vulkan requires version 1.3. Ray-query support is detected separately.

## Render scale and upscalers

| Variable | Default | Meaning | Restart |
| --- | --- | --- | --- |
| `r_vkUpscaler` | `-1` | `-1` automatic, `0` built-in, `1` FSR 3.1, `2` external DLSS | No |
| `r_vkUpscaleQuality` | `0` | Render-resolution preset; values below | Yes |
| `r_vkRenderScale` | `1` | Custom world scale, from 0.33 through 1 | Yes |
| `r_vkTAA` | `1` | Temporal anti-aliasing | No |
| `r_vkSharpen` | `0.3` | Contrast-adaptive sharpening; `0` disables it | No |
| `r_vkDlssPath` | Empty | Directory containing the user-installed DLSS runtime | Yes |
| `r_vkDlssPreset` | `5` | NGX model preset: `5` E, `11` K, `13` M, `0` runtime default | No |

`r_vkUpscaleQuality` values:

| Value | Preset | Scale per dimension |
| --- | --- | --- |
| `0` | Automatic for the display | Selected by the renderer |
| `1` | Native | 1 |
| `2` | Quality | 0.67 |
| `3` | Balanced | 0.58 |
| `4` | Performance | 0.5 |
| `5` | Ultra performance | 0.33 |
| `6` | Custom | `r_vkRenderScale` |

The scale applies to the world image, not the HUD or menu resolution. Automatic
upscaler selection uses DLSS when available, otherwise FSR, when rendering below
native resolution. A requested unavailable DLSS path falls back to FSR.

An empty `r_vkDlssPath` checks `DK3_DLSS_PATH`, then `dlss/` in the game's home
directory. The expected library is `libnvidia-ngx-dlss.so.*`. DLSS binaries are not
included with dk3.

## Image and material settings

| Variable | Default | Meaning | Restart |
| --- | --- | --- | --- |
| `r_vkRemaster` | `0` | HDR/material/post-processing pipeline; `0` selects classic presentation | Yes |
| `r_gamma` | `1` | Display brightness curve | Reload textures with `vid_restart` |
| `r_picmip` | `1` | Texture mip reduction; lower values retain more detail | Yes |
| `r_textureMode` | `GL_LINEAR_MIPMAP_LINEAR` | Texture filtering mode | No |
| `r_vkExposure` | `0` | Exposure compensation in EV | No |
| `r_vkAutoExposure` | `1` | Automatic exposure adaptation | No |
| `r_vkBloom` | `0.05` | Bloom strength | No |
| `r_vkSaturation` | `1` | Color saturation | No |
| `r_vkTonemap` | `0` | `0` PBR Neutral; `1` AgX | No |
| `r_vkBump` | `1` | Normal/bump material response | No |
| `r_vkSpecular` | `1` | Specular material response | No |

The HD texture installation path selects full-resolution textures when its package
is present. An explicit `r_picmip` launch setting can override that selection.

## Fog, weather and surfaces

| Variable | Default | Meaning |
| --- | --- | --- |
| `r_dk3Fog` | `1` | Authored map distance fog |
| `r_vkVolumetric` | `1` | Volumetric fog with light scattering |
| `r_vkFogDensity` | `0.00005` | Base atmospheric extinction per world unit |
| `r_vkFogScatter` | `1` | Light-scattering strength |
| `r_vkMapFog` | `0.3` | Authored fog strength; `1` uses the original strength |
| `r_vkVolumetricShadows` | `1` | Ray-traced lighting of fog and light shafts |
| `r_vkWeather` | `1` | GPU rain/snow for authored weather volumes; `0` keeps client particles |
| `r_vkWeatherDensity` | `1` | Weather particle density multiplier |
| `r_vkWeatherSplashes` | `1` | Weather contact splashes |
| `r_vkWetness` | `1` | Rain wetness, puddles and ripples |
| `r_vkSnowCover` | `1` | Snow accumulation on upward-facing surfaces |

These settings apply while running and do not require a renderer restart.

## Lighting and ray tracing

| Variable | Default | Meaning | Restart |
| --- | --- | --- | --- |
| `r_vkRayTracing` | `0` | Enable ray-query features when the device supports them | Yes |
| `r_vkLighting` | `1` | `0` baked lightmaps; `1` map lights with traced shadows and probe lighting | No |
| `r_vkRtShadows` | `1` | Ray-traced shadows for dynamic lights | No |
| `r_vkRtReflections` | `1` | Traced reflections on liquid, smooth and wet surfaces | No |
| `r_vkRtCharacters` | `1` | Character ray-traced shadows | No |
| `r_vkModelShadows` | `1` | Shadow-mapped model shadows along baked lighting | No |
| `cg_shadows` | `1` | Model shadow submission | No |
| `r_vkDdgi` | `1` | Irradiance probes for model ambient lighting | No |
| `r_vkDdgiProbes` | `8192` | Probe updates per 60-fps frame, scaled with frame rate | No |
| `r_vkDirectionalBake` | `0` | Bake directional lightmaps from map lights | No |
| `r_vkBakePages` | `4` | Directional lightmap pages baked per frame | No |
| `r_vkPathTracing` | `0` | Path-traced world lighting | No |
| `r_vkPtLightScale` | `0.5` | Path-traced map-light brightness scale | No |
| `r_vkLightVisibility` | `1` | Measure light visibility for lighting cells | No |
| `r_vkDepthPrepass` | `1` | Draw opaque depth before lighting | No |

RT settings need a device with acceleration-structure and ray-query support.
Characters participate in shadow rays; complete character reflected-hit shading
is not provided. Path tracing increases the rendering workload substantially.

## Diagnostics and capture

| Variable | Default | Meaning |
| --- | --- | --- |
| `r_vkValidation` | `0` | Enable the Khronos validation layer when installed; requires restart |
| `r_vkStats` | `0` | Print frame counters every N frames; `0` disables output |
| `r_vkMaterialScan` | `0` | Compile shader scripts and report unsupported keywords |
| `r_vkDebugView` | `0` | Diagnostic output view |
| `r_vkRtCost` | `0` | Profiling bitmask that skips selected lighting work |
| `r_screenshotJpegQuality` | `90` | JPEG screenshot quality |
| `r_aviMotionJpegQuality` | `90` | Motion-JPEG capture quality |

Debug views include `1` path-traced lighting, `2` path-traced pixels, `3` directional
lightmaps, `4` irradiance, `5` without directional lightmaps, `6` texture color,
`7` light only, and `12`–`15` direct/bounce/sky/unshadowed direct lighting.

`r_vkRtCost` bits skip sky/AO rays (`1`), shadow rays (`2`), probes (`4`), the light
loop (`8`) or sampled shadows (`16`). These are diagnostic modes, not image-quality
presets.

See [Configure resolution and upscaling](../how-to/configure-video.md) for worked
settings and [Rendering pipeline](../explanation/rendering.md) for how the passes fit together.
