# Configure resolution and upscaling

Use the Video menu for common settings. The console gives access to the Vulkan
upscaler, render scale and lighting controls described below.

## Use desktop resolution

```text
r_mode -2
r_fullscreen 1
vid_restart
```

Fullscreen uses a borderless window at the desktop's drawable resolution.

For a fixed-size window, use:

```text
r_fullscreen 0
r_mode -1
r_customwidth 1920
r_customheight 1080
vid_restart
```

## Enable FSR upscaling

Select the Vulkan renderer first, then enter:

```text
r_vkRemaster 1
r_vkUpscaler 1
r_vkUpscaleQuality 2
vid_restart
```

Quality mode renders the world at 0.67 of each output dimension and reconstructs
the output image with FSR 3.1. Menus and HUD stay at output resolution.

Try `r_vkUpscaleQuality 3` for Balanced or `4` for Performance. To render at native
resolution, set `r_vkUpscaleQuality 1` and run `vid_restart`.

## Set a custom render scale

```text
r_vkUpscaleQuality 6
r_vkRenderScale 0.75
vid_restart
```

The custom scale ranges from 0.33 to 1. It applies to each image dimension, so a
scale of 0.5 renders one quarter as many pixels as native resolution.

## Disable ray tracing

```text
r_vkRayTracing 0
vid_restart
```

This keeps Vulkan rendering and disables its optional ray-query features. Use it
when comparing performance or diagnosing an RT-specific rendering problem.

## Adjust brightness

Open **Video**, change **Brightness**, and choose **Apply**. The setting reloads
the renderer. The console equivalent is:

```text
r_gamma 1.3
vid_restart
```

Values above 1 brighten the image. See the [renderer reference](../reference/rendering.md)
for exposure, bloom and tone-mapping controls.

## Adjust the crosshair

The crosshair uses the supplied 16×16 artwork at native size. Its size is measured
in output pixels, independently of resolution, HUD scaling and FSR render scale.
To change it, enter this in the console (no restart required):

```text
cg_crosshairSize 16
```

Values range from 0 to 64 pixels; 0 hides it. The setting is saved with your profile.
