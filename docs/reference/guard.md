# dkguard reference

`dkguard` runs a command with optional memory limits, a process-group timeout,
GPU serialization and a virtual display.

## Synopsis

```text
dkguard [options] -- command [arguments]
```

The default build installs it at `zig-out/native-dev/bin/dkguard`.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `--gpu` | Off | Hold the shared GPU lock while the command runs |
| `--no-wait` | Off | With `--gpu`, exit if the lock is busy instead of waiting |
| `--lock-file PATH` | `/tmp/dkguard-gpu.lock` | Lock used to serialize GPU jobs |
| `--mem CAP` | No cap | Limit memory using a systemd user scope or `prlimit` |
| `--timeout DURATION` | No timeout | Limit the entire process group's runtime |
| `--headless` | Off | Use software rendering, dummy audio and a virtual X display |
| `--screen WIDTHxHEIGHT` | Xvfb default | Set the virtual display dimensions; requires `--headless` |
| `--help`, `-h` | — | Print command-line help |

Memory values use a positive integer, optionally followed by `K`, `M`, `G` or `T`.
Suffixes are powers of 1024. Durations use a positive integer with `ms`, `s`, `m`
or `h`; a bare duration is seconds.

## Examples

```sh
./zig-out/native-dev/bin/dkguard --mem 512M --timeout 30s -- python3 --version
```

```sh
./zig-out/native-dev/bin/dkguard --headless --screen 1280x720 --mem 8G --timeout 90s -- your-command
```

`--headless` selects software rendering; use `--gpu` for a physical GPU run instead.

## Dependencies

Memory caps need a working systemd user scope or `prlimit` on `PATH`.
Headless graphics need `xvfb-run` and `xauth`. Software Vulkan also needs a driver
such as Mesa lavapipe.

## Exit status

The child command's exit status is returned on ordinary completion. Timeout returns
124. With `--gpu --no-wait`, a busy GPU lock returns 75. A signal-terminated child
is reported with its signal; status 137 indicates SIGKILL and can result from a
memory-limit kill.
