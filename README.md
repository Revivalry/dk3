# dk3

dk3 brings Daikatana to a modified ioquake3 engine with a native Zig runtime.
It includes Vulkan and OpenGL renderers, single-player systems, multiplayer,
and tools for converting your own game data.

**Development build:** campaign completion and multiplayer still have limitations.
See [Development status](docs/project/status.md) before playing.

[Documentation](https://dmytrogajewski.github.io/dk3/) ·
[Build tutorial](docs/tutorials/build-engine.md) ·
[Engine architecture](docs/explanation/architecture.md)

## Build

Use Linux x86-64, Zig 0.16.x, Make, `pkg-config`, SDL2, SQLite3 and Vulkan
development files, and `glslc`. See the [build tutorial](docs/tutorials/build-engine.md)
for distribution packages and troubleshooting.

```sh
git clone https://github.com/dmytrogajewski/dk3.git
cd dk3
python3 -m venv .venv
.venv/bin/python -m pip install -r dkq3/tools/requirements-test.txt
zig build -Dpython=.venv/bin/python
./zig-out/native-dev/bin/dkguard --mem 512M --timeout 30s -- .venv/bin/python --version
```

The client, dedicated server and tools are in `zig-out/native-dev/bin/`.
Game modules are in `zig-out/native-dev/lib/dk3/`. The checkout includes the
engine; you do not need a separate ioquake3 repository or game data to build it.

## Play

You need legally acquired Daikatana data and FFmpeg 7 on your `PATH`.
Replace the example path with the directory containing `pak1.pak` through `pak4.pak`:

```sh
zig build assets -Dpython=.venv/bin/python -DDK_DATA=/path/to/daikatana/data -Dasset-profile=retail
zig build play -Dpython=.venv/bin/python
```

Choose **Single Player**, then a difficulty. Subsequent `zig build play` commands
reuse the converted assets. Settings and saves are in the build prefix's
`play/home/` and `play/state/` directories.

For the 1.3 input profile, save/load instructions and the first launch, follow
[Start your first game](docs/tutorials/first-game.md). To change graphics, see
[Choose a renderer](docs/how-to/select-renderer.md) and
[Configure video](docs/how-to/configure-video.md).

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, checks and submission requirements.
The [architecture guide](docs/explanation/architecture.md) describes the source
layout; [Add or change a class](docs/how-to/extend-class.md) covers gameplay work.
Report reproducible problems in the [issue tracker](https://github.com/dmytrogajewski/dk3/issues).

Maintained by [@dmytrogajewski](https://github.com/dmytrogajewski).

## License

Original project code is **GPL-2.0-or-later**. See [LICENSE](LICENSE),
[COPYRIGHT.md](COPYRIGHT.md) and the [licensing guide](docs/project/licensing.md)
for bundled components and their notices. Original and converted game assets
are supplied locally and are not distributed under the source-code license.
This independent community project is unaffiliated with the original game's
rights holders.
