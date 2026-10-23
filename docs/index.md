# dk3 documentation

dk3 brings Daikatana to a modified ioquake3 engine with a native Zig runtime.
It includes Vulkan and OpenGL renderers, game and menu modules, multiplayer
services, and tools for converting your own game data.

dk3 is under development. See [Development status](project/status.md) for supported
setups and current limitations.

## Get started

Use the [release installer](how-to/release-installer.md) with your own Daikatana
data, or follow [Build the engine](tutorials/build-engine.md) to compile the
client and tools. [Start your first game](tutorials/first-game.md) covers local
asset conversion and launch.

## Use the engine

- [Choose a renderer](how-to/select-renderer.md) or [configure video](how-to/configure-video.md).
- [Update your installation](how-to/update-installation.md) after rebuilding or converting new data.
- [Host a multiplayer game](how-to/host-multiplayer.md).
- [Run without a display](how-to/headless.md).
- [Troubleshoot startup and loading](how-to/troubleshoot.md).

## Look up a setting or format

The reference covers [build commands](reference/build.md), [renderer settings](reference/rendering.md),
[console commands](reference/console.md), [file locations](reference/paths.md),
[asset conversion](reference/assets.md), [networking](reference/network.md) and
the [save format](reference/saves.md).

## Understand and extend dk3

Read [Engine architecture](explanation/architecture.md) for the module layout and
frame flow. The explanations of [rendering](explanation/rendering.md),
[connected worlds](explanation/worlds.md) and [asset installations](explanation/assets.md)
describe how those systems fit together.

To change gameplay, start with [Add or change a class](how-to/extend-class.md).
For the development workflow and documentation commands, see
[Contributing](project/development.md).
