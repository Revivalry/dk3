# Choose a renderer

dk3 provides Vulkan, OpenGL2 and OpenGL1 renderers. You can select one at launch
or switch from the console.

## Select at launch

Run one of these commands from a checkout with converted assets:

```sh
zig build play -- +set cl_renderer vulkan
zig build play -- +set cl_renderer opengl2
zig build play -- +set cl_renderer opengl1
```

Vulkan is the default, with classic presentation and ray tracing off. The remaster
effects and upscalers are available as options. OpenGL2 and OpenGL1 provide
alternative rendering paths.

If you use a virtual environment, add `-Dpython=.venv/bin/python` before `--`.

## Switch while running

Open the console and enter:

```text
cl_renderer opengl2
vid_restart
```

Replace `opengl2` with the renderer you want. `vid_restart` reloads the renderer
without restarting the game process.

## Enable remaster presentation in Vulkan

```text
r_vkRemaster 1
vid_restart
```

To return to the default classic pipeline, set `r_vkRemaster 0` and run
`vid_restart` again. Ray tracing remains off until `r_vkRayTracing 1` is set.

## If Vulkan fails

The client falls back to OpenGL2 when the Vulkan module is unavailable or its
capability probe rejects the system. Some later window or device initialization
failures terminate startup instead. In that case, launch explicitly with OpenGL2.

See [Renderer settings](../reference/rendering.md) for settings and restart requirements.
