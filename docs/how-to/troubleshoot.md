# Troubleshoot build and startup

## Zig reports a version mismatch

Run `zig version`. Use Zig 0.16.x; a compiler from a different minor release is
rejected by the build. Check which executable your shell finds with `command -v zig`.

## SDL2, Vulkan or SQLite3 cannot be found

Check the development packages through pkg-config:

```sh
pkg-config --modversion sdl2 vulkan sqlite3
glslc --version
```

Install missing development packages and `glslc`, then rebuild. Runtime libraries
alone do not provide the headers needed to compile the engine.

## A Python module is missing

Install the tools into the interpreter you pass to the build:

```sh
.venv/bin/python -m pip install -r dkq3/tools/requirements-test.txt
zig build play -Dpython=.venv/bin/python
```

Activating one environment and passing a different Python executable can leave
the selected interpreter without the required modules.

## Conversion reports a missing PAK file

Check that `-DDK_DATA` points to the directory containing the PAK files, rather
than its parent. Check the selected [asset profile](../reference/assets.md#input-profiles).
Retail needs `pak1.pak` through `pak3.pak`; `pak4.pak` is optional. The 1.3 profile
also needs `pak4.pak`, `pak6.pak`, and either `pak5.pak` or `pak5.zip`.

## There is no completed asset generation

Run the `assets` target and allow it to complete before using `play`:

```sh
zig build assets -Dpython=.venv/bin/python -DDK_DATA=/path/to/daikatana/data -Dasset-profile=retail
```

A partially converted directory is not selected as `zig-out/assets/current`.
Repeat the same conversion command to resume completed work.

## Vulkan startup fails

Try an explicit OpenGL2 launch:

```sh
zig build play -- +set cl_renderer opengl2
```

If that works, keep the Vulkan error from the console when reporting the problem.
Include the GPU, driver, selected renderer and resolution. See
[Choose a renderer](select-renderer.md) for the fallback behavior.

## Save/load reports `RegionAdmissionInProgress`

Wait for the loading screen to finish, return to normal play and retry the save.
The game refuses to save while a connected region is still being admitted.

For automated drivers, wait for `dk3 region: initial admission committed` and
processed player input. Receiving the first snapshot alone is insufficient.

## A save refuses a changed map

Saves record map identities. A save may no longer match after reconverting map
geometry. Use its matching installation, or start a new game with the new data.
Original Daikatana saves cannot be loaded as dk3 saves.

## Report another problem

Open an [issue](https://github.com/dmytrogajewski/dk3/issues) with the command, error
message, `zig version`, operating system and relevant graphics settings. Include
the smallest useful log excerpt. Do not attach proprietary data, credentials or saves.
