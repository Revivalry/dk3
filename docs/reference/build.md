# Build reference

Run build commands from the repository root. The supported game target is Linux
x86-64 GNU, using Zig 0.16.x.

## Targets

```text
zig build [target] [options] [-- engine-arguments]
```

| Target | Result |
| --- | --- |
| Default | Build and install the client, dedicated server, renderers, native modules, dkguard and online tools |
| `engine` | Build the bundled client, dedicated server and renderers |
| `engine-server` | Build the dedicated server |
| `game` | Build the native server, client and UI modules |
| `online` | Build the coordinator, worker, online client and operator tools |
| `assets` | Convert the data selected by `-DDK_DATA` |
| `play-install` | Build code and prepare an installation using converted assets |
| `play` | Prepare the installation and launch it through dkguard |
| `test` | Run the complete component suite |
| `test-runtime` | Run native runtime and adapter checks |
| `test-codec` | Compare the message codec against its C reference |
| `test-online` | Run online lifecycle and packet-security checks |
| `runtime-audit` | Build the read-only save compatibility inspector |

## Common options

| Option | Default | Meaning |
| --- | --- | --- |
| `-Doptimize` | `ReleaseSafe` | Zig optimization mode |
| `-Dtarget` | `x86_64-linux-gnu` | Game compilation target |
| `--prefix` | `zig-out/native-dev` | Installation prefix |
| `-Dpython` | `python3` | Interpreter for asset and development tools |
| `-Dheadless` | `false` | Launch `play` on a virtual display using software rendering |
| `-DDK_DATA` | Unset | Original game-data directory; setting it explicitly requests conversion |
| `-Dasset-profile` | `retail` | `retail` or `1.3` input rules |
| `-Dassets-dir` | `zig-out/assets` | Converted asset cache |
| `-Dasset-workers` | `4` | Conversion concurrency, from 1 through 12 |
| `-Dffmpeg` | `ffmpeg` | FFmpeg executable |
| `-Dffmpeg-major` | `7` | FFmpeg major recorded in the conversion identity |

The historical prefix `zig-out` is redirected to `zig-out/native-dev`. The play
installer rejects the reserved online prefix.

## Optional packages

These options select local packages when preparing a play installation:

| Option | Content |
| --- | --- |
| `-Dhd-textures=/path/to/file.pk3` | HD texture overlay |
| `-Dmaterials=/path/to/file.pk3` | Generated remaster material maps |
| `-Dneural-assets=/path/to/file.pk3` | Skeletal character package |
| `-Dhd-weapons=/path/to/file.pk3` | HD weapon replacements |
| `-Dhd-weapons-preview=/path/to/file.pk3` | Explicit weapon-art preview package |

When no explicit path is supplied, the installer checks its default local package
locations. See [Files and directories](paths.md).

## Engine feature switches

`USE_VOIP`, `USE_HTTP`, `USE_CODEC_VORBIS`, `USE_CODEC_OPUS`, `USE_MUMBLE` and
`USE_OPENAL` default to `true`. `USE_FREETYPE` defaults to `false` and needs the
FreeType development package when enabled. Set switches with `-DNAME=true` or
`-DNAME=false`.

Game, client and UI behavior are native Zig modules. `-Dgame-runtime` accepts only
`zig`; there is no alternative gameplay backend.

## Make targets

| Command | Equivalent or purpose |
| --- | --- |
| `make build` | `zig build -Doptimize=ReleaseSafe` |
| `make lint` | `zig build test` |
| `make test` | `zig build test` |
| `make fmt` | Format Zig source and build files |
| `make docs-site` | Build and check the documentation site |

Use either `make lint` or `make test` for the complete component suite; they run
the same checks.

## Build products

All paths below are relative to the installation prefix.

| Path | Product |
| --- | --- |
| `bin/dk3` | Client and local game host |
| `bin/dk3ded` | Dedicated server |
| `bin/renderer_vulkan.so` | Vulkan renderer |
| `bin/renderer_opengl1.so` | OpenGL1 renderer |
| `bin/renderer_opengl2.so` | OpenGL2 renderer |
| `lib/dk3/qagame.so` | Server game module |
| `lib/dk3/cgame.so` | Client game module |
| `lib/dk3/ui.so` | Menu module |
| `bin/dkguard` | Process runner |
| `bin/dk3-coordinator`, `bin/dk3-worker` | Internet-room services |
| `bin/dk3-online`, `bin/dk3-operator` | Service client and operator utilities |

See [Build the engine](../tutorials/build-engine.md) for setup instructions.
