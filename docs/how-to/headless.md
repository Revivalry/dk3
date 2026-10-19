# Run with a virtual display

Headless runs use software rendering, dummy audio and an Xvfb display. They are
useful for reproducing a map or capturing output without opening a desktop window.

Install Xvfb and xauth, then use the existing converted asset cache:

```sh
zig build play -Dheadless=true -- +set cl_renderer opengl1 +map e1m1a
```

Add `-Dpython=.venv/bin/python` if you use the tutorial's virtual environment.
The normal `play` launcher runs the engine through `dkguard`.

## Guard another command

```sh
./zig-out/native-dev/bin/dkguard --headless --screen 1280x720 --mem 8G --timeout 90s -- your-command
```

Replace `your-command` with the executable and arguments to run. `--screen` sets
the virtual display size; engine resolution is configured separately.

Do not combine `--headless` with `--gpu`. The former selects software rendering;
the latter serializes access to the physical GPU.

Memory limits require `prlimit` or a working systemd user session. If Vulkan is
selected, install a software Vulkan driver such as Mesa lavapipe.

See [dkguard reference](../reference/guard.md) for flags and exit statuses.
