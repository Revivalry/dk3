# Asset conversion reference

The converter reads original Daikatana data and writes the packages used by dk3.
It needs Python with `dkq3/tools/requirements.txt` installed and FFmpeg 7 with PCM
and Vorbis support.

## Synopsis

```sh
zig build assets -DDK_DATA=/path/to/data -Dasset-profile=retail
```

Add `-Dpython=.venv/bin/python` to use a virtual environment.

## Input profiles

| Profile | Required archives | Priority |
| --- | --- | --- |
| `retail` | `pak1.pak` through `pak3.pak`; `pak4.pak` is optional | Present numbered archives from pak0 through pak9, followed by loose files |
| `1.3` | Retail archives, `pak4.pak`, `pak6.pak`, and either `pak5.pak` or `pak5.zip` containing exactly one `pak5.pak` | pak5 overrides the other archives; loose files override archives |

Names are resolved case-insensitively. Ambiguous loose-file names produce an error.
Use the profile matching your installation, including its loose overrides.

For tables, the 1.3 profile prefers JSON over CSV/VSC. The retail profile prefers
CSV/VSC over JSON. VSC tables are decoded and normalized into runtime records.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `-DDK_DATA` | Required | Input directory |
| `-Dasset-profile` | `retail` | Input profile |
| `-Dassets-dir` | `zig-out/assets` | Output cache |
| `-Dasset-workers` | `4` | Concurrent workers, 1–12 |
| `-Dpython` | `python3` | Python interpreter |
| `-Dffmpeg` | `ffmpeg` | Audio encoder executable |
| `-Dffmpeg-major` | `7` | Expected encoder major version |

An alternate FFmpeg major becomes part of the generation identity. It is not
interchangeable with a generation produced using the default encoder.

## Output

Conversion writes `zig-out/assets/<key>/`, including packages, reports and a final
manifest. The key depends on source content, converter code, profile, interpreter,
NumPy and encoding options. Packages use fixed archive metadata.

Completed stages can be reused after an interruption. The `current` link changes
only when conversion finishes and the inputs remain consistent. Worker-count
changes alone do not invalidate completed deterministic stages.

## Navigation variants

Conversion compiles navigation for difficulty and multiplayer selections. Selections
with identical eligible brush entities share an AAS file; other selections receive
distinct variants. A per-map configuration selects the variant at runtime.

## Using the output

`play-install` uses the completed generation and verifies its packages. Supplying
`-DDK_DATA` to `play` or `play-install` also requests conversion. Omit that option
for a code-only rebuild.

See [Start your first game](../tutorials/first-game.md) for a walkthrough and
[Asset pipeline](../explanation/assets.md) for how generations and installations fit together.
