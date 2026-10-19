# Build the engine

This tutorial builds dk3 from source and checks that its process runner works.
You do not need Daikatana game data for these steps.

## Before you start

You need a Linux x86-64 machine, Git, and Zig 0.16.x on your `PATH`.
Run `zig version` to check the compiler version.

The package commands below use Ubuntu 24.04. On another distribution, install the
equivalent SDL2, SQLite3 and Vulkan development packages, `pkg-config`, `glslc`,
Make, Python and Python virtual-environment support.

## Install the build dependencies

```sh
sudo apt-get update
sudo apt-get install -y git make pkg-config libsdl2-dev libsqlite3-dev libvulkan-dev glslc python3-venv xvfb xauth
```

## Get the source

```sh
git clone https://github.com/dmytrogajewski/dk3.git
cd dk3
```

The checkout includes ioquake3 and the navigation compiler. You do not need a
separate engine checkout.

## Set up Python

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r dkq3/tools/requirements-test.txt
```

The virtual environment contains the packages used by the asset tools and tests.
It does not change your system Python installation.

## Build

```sh
zig build -Dpython=.venv/bin/python
```

The build writes its executables to `zig-out/native-dev/bin/` and game modules to
`zig-out/native-dev/lib/dk3/`.

## Check the result

Run Python through `dkguard`, the included process runner:

```sh
./zig-out/native-dev/bin/dkguard --mem 512M --timeout 30s -- .venv/bin/python --version
```

You should see your Python version and `dkguard: finished status=0 (exited)`.

You now have the client, dedicated server, renderers, native modules and command-line
tools. Continue with [Start your first game](first-game.md) to convert your game data
and launch dk3.

For build failures, see [Troubleshoot startup](../how-to/troubleshoot.md).
