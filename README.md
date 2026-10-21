# DK3

**Daikatana, rebuilt on ioquake3 with native Zig game modules.**

[Documentation](https://dmytrogajewski.github.io/dk3/) · [Build tutorial](docs/tutorials/build-engine.md) · [Engine architecture](docs/explanation/architecture.md) · [Development status](docs/project/status.md) · [Contributing](CONTRIBUTING.md)

DK3 is an open-source project bringing **Daikatana (2000)** to a modified **ioquake3** engine. Its game simulation, client prediction and UI run in native Zig modules. The project includes Vulkan and OpenGL rendering, single-player systems, multiplayer modes, and tools for converting legally owned Daikatana game data.

**Status: active development, not a finished source port.** The maintainer reports having completed the Japan and Ancient Greece episodes on the new engine. Full campaign completion and broader multiplayer behavior are still in progress; consult the [development status](docs/project/status.md) before playing.

## What is implemented

- **Native Zig game modules:** `qagame.so` (authoritative gameplay), `cgame.so` (prediction and scene presentation), and `ui.so` (menus).
- **Modified ioquake3 runtime:** platform services, filesystem, audio, collision, module loading and networking.
- **Rendering:** Vulkan 1.3, OpenGL2 and OpenGL1.
- **Gameplay foundations:** archetype ECS, job execution, animation, navigation, actor and weapon classes, companions, save/load and world progression.
- **Multiplayer modes:** deathmatch, capture the flag and deathtag (work in progress). Co-op is not supported.
- **Original-data workflow:** local conversion of legally acquired retail or 1.3 game data; original archives are not bundled.

See the [architecture overview](docs/explanation/architecture.md) for subsystem boundaries and implementation details.

## Requirements

Current development target: **Linux x86-64 GNU**. Build requirements include Zig **0.16.x**, Make, `pkg-config`, SDL2, SQLite3, Vulkan development files, `glslc`, Python and the dependencies described in the [build tutorial](docs/tutorials/build-engine.md).

## Build

```sh
git clone https://github.com/Revivalry/dk3.git
cd dk3
python3 -m venv .venv
.venv/bin/python -m pip install -r dkq3/tools/requirements-test.txt
zig build -Dpython=.venv/bin/python
./zig-out/native-dev/bin/dkguard --mem 512M --timeout 30s -- .venv/bin/python --version
```

The client, dedicated server and tools are under `zig-out/native-dev/bin/`. Game modules are under `zig-out/native-dev/lib/dk3/`. The engine is included in the checkout, and game data are **not** required to compile.

## Play with your own game data

To play, supply legally acquired Daikatana data and install **FFmpeg 7** on your `PATH`. Point `DK_DATA` to a directory containing `pak1.pak` through `pak4.pak`:

```sh
zig build assets -Dpython=.venv/bin/python -DDK_DATA=/path/to/daikatana/data -Dasset-profile=retail
zig build play -Dpython=.venv/bin/python
```

Choose **Single Player** and a difficulty. Converted assets are reused on subsequent runs. Settings and saves live under the build prefix's `play/home/` and `play/state/` directories. See [Start your first game](docs/tutorials/first-game.md) and [Choose a renderer](docs/how-to/select-renderer.md) for additional instructions.

## Where DK3 is going

Daikatana is the immediate priority: get the original campaign playable from beginning to end and improve compatibility, tooling and quality. A **longer-term design direction**, not an implemented compatibility guarantee, is to evolve DK3 into a reusable framework for id Tech 3-family games, with shared engine capabilities, game-specific native modules and a richer scripting layer.

## Contribute

Reports, code, tests and documentation contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the [architecture guide](docs/explanation/architecture.md). File reproducible bugs and proposals in the [issue tracker](https://github.com/Revivalry/dk3/issues). Please do not upload copyrighted retail assets or extracted game data.

## License and rights

Original DK3 project code is **GPL-2.0-or-later**. Bundled components retain their own licenses; see [LICENSE](LICENSE), [COPYRIGHT.md](COPYRIGHT.md), and the [licensing guide](docs/project/licensing.md). Original Daikatana assets are **not** included or relicensed. DK3 is an independent community project unaffiliated with the game's rights holders.

Maintained by [@dmytrogajewski](https://github.com/dmytrogajewski) as part of [Revivalry](https://github.com/Revivalry).
