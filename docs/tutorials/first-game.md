# Start your first game

This tutorial converts Daikatana data, creates a dk3 installation and opens a
single-player game.

## Before you start

Complete [Build the engine](build-engine.md). You also need:

- A legally acquired Daikatana data directory containing `pak1.pak` through `pak3.pak` (standard Steam data).
- FFmpeg 7 on your `PATH`, with PCM and Vorbis support.
- A graphical session with a Vulkan 1.3 or OpenGL-capable driver.

The steps below use retail data. If your data includes the 1.3 update, use the
`1.3` profile described in the [asset reference](../reference/assets.md#input-profiles).

## Convert the game data

From the dk3 checkout, run the following command. Replace `/path/to/daikatana/data`
with the directory containing your PAK files.

```sh
zig build assets -Dpython=.venv/bin/python -DDK_DATA=/path/to/daikatana/data -Dasset-profile=retail
```

Conversion creates packages and navigation data under `zig-out/assets/`. It keeps
completed stages so you can repeat an interrupted command without starting over.
Wait for the command to finish before continuing.

## Create the installation

```sh
zig build play-install -Dpython=.venv/bin/python
```

The command prints an installation path beneath `zig-out/native-dev/play/`.
The `current` link in that directory selects the installation that will run.

## Launch dk3

```sh
zig build play -Dpython=.venv/bin/python
```

Choose **Single Player**, then a difficulty. The game opens its introduction and
continues into the opening map. Press **Escape** to skip a cinematic or open the
pause menu during play.

If you need to change controls, use the Keyboard and Mouse pages in the options
menu. Use the Video page for resolution, fullscreen and brightness.

## Save and resume

Open the save menu, choose a slot and save. Return to the main menu and load that
slot to resume. You can also use `save quick` and `load quick` in the console.

Settings and saves remain in the native play profile when you rebuild the code.
See [Files and directories](../reference/paths.md) for their locations.

## Next steps

- [Choose a renderer](../how-to/select-renderer.md).
- [Configure resolution and upscaling](../how-to/configure-video.md).
- [Update an installation](../how-to/update-installation.md).
- [Troubleshoot startup](../how-to/troubleshoot.md) if the game does not reach the menu.
