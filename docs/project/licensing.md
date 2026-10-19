# Licensing and game data

dk3 code is licensed under **GPL-2.0-or-later**. See the
[license](https://github.com/dmytrogajewski/dk3/blob/main/LICENSE) and
[copyright notices](https://github.com/dmytrogajewski/dk3/blob/main/COPYRIGHT.md).

## Game data

Playing requires legally acquired Daikatana data. The repository does not include
the original game archives, converted game packages, generated character packages
or saved games. Those files are produced or supplied locally.

Development screenshots depict artwork owned by its respective rights holders.
The source-code license does not relicense that artwork.

## Bundled components

| Component | Location | Terms |
| --- | --- | --- |
| ioquake3 and bundled libraries | `engine/ioquake3/` | Upstream licenses and notices retained |
| BSPC | `engine/bspc/` | Bundled GPL navigation compiler |
| Lua 5.4.7 | `engine/lua/` | MIT |
| FidelityFX FSR 3.1 shader subset | `engine/fidelityfx/` | MIT |

The upstream LCC tools have separate terms and are not required for the native
game runtime. NVIDIA DLSS/NGX binaries and SDK headers are not distributed with dk3.

The [component provenance record](https://github.com/dmytrogajewski/dk3/blob/main/docs/provenance.md)
lists origins and dispositions. Daikatana and Quake names identify compatibility
and belong to their respective owners.
