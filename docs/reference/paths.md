# Files and directories

These paths use the default build prefix. Relative paths are measured from the
repository root.

## Code and asset output

| Path | Contents |
| --- | --- |
| `zig-out/native-dev/bin/` | Built executables and renderer libraries |
| `zig-out/native-dev/lib/dk3/` | Built game, client and UI libraries |
| `zig-out/assets/<key>/` | A converted asset generation, including its manifest and conversion reports |
| `zig-out/assets/current` | Link to the completed asset generation |
| `zig-out/native-dev/play/<key>/` | An installation combining engine, modules and packages |
| `zig-out/native-dev/play/current` | Link to the installation selected for play |
| `.zig-cache/` | Local compiler cache |
| `zig-out/docs-site/` | Generated documentation website |

An installation directory is generated output. Edit source or settings rather
than modifying files inside a content-keyed installation.

## Settings and saves

| Path | Contents |
| --- | --- |
| `zig-out/native-dev/play/home/` | Persistent home/profile directory |
| `zig-out/native-dev/play/home/dk3/` | Game configuration, screenshots and other home files |
| `zig-out/native-dev/play/state/dk3/saves/` | Native saves and save metadata |

Back up `play/home/` and `play/state/` before deleting the play prefix. Rebuilding
or selecting another installation normally leaves these profile directories intact.

## Optional local packages

The installer can discover packages at these fallback locations:

| Path | Package |
| --- | --- |
| `zig-out/hd-textures/dkq3-textures_hd.pk3` | HD textures |
| `zig-out/materials/dk3-materials.pk3` | Remaster material maps |
| `zig-out/neural-assets/dk3-neural.pk3` | Skeletal characters |
| `zig-out/hd-weapons/dk3-hd-weapons.pk3` | HD weapons |

Explicit build options override discovery. See [Build reference](build.md#optional-packages).

## Source layout

| Directory | Contents |
| --- | --- |
| `engine/ioquake3/` | Engine platform, renderer alternatives and bundled libraries |
| `engine/bspc/` | Navigation compiler |
| `engine/lua/` | Lua interpreter used by the campaign driver |
| `engine/fidelityfx/` | FSR upscaler shader subset |
| `src/engine/` | Native engine ABI adapters |
| `src/core/` | Game-independent runtime code |
| `src/mechanics/` | Shared gameplay and presentation mechanisms |
| `src/game/` | Class registries and component declarations |
| `src/classes/` | Actor, weapon, item and entity implementations |
| `src/renderer_vulkan/` | Vulkan renderer and shaders |
| `src/network/`, `src/online/` | Network codec and room services |
| `dkq3/tools/` | Python asset and development tools |

See [Engine architecture](../explanation/architecture.md) for the relationships
between these components.
