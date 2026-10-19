# Asset pipeline

dk3 separates original game data, converted packages, code builds and installations.
Each has a different lifetime.

## Original data and converted packages

The original data directory contains PAK archives and loose overrides. A profile
determines their priority and the required inputs. Conversion produces the engine
formats used by dk3: map and navigation data, textures, models, audio and runtime
tables.

The converter writes a content-keyed generation. Its identity includes input
content, conversion code and relevant tool settings. A changed input produces a
different generation rather than replacing a package that an existing installation
may still use.

The `current` link selects a completed generation. It is updated only after the
conversion finishes. Interrupted work can reuse completed unchanged stages without
exposing a partial generation as ready.

## Code builds and installations

A code build creates executables and native libraries. An installation combines
those files with one converted generation and any selected local overlays.

This distinction makes code-only iteration cheaper: rebuilding gameplay does not
require converting maps or audio again. Conversely, converter changes need an
explicit asset conversion before their new output can be used.

## Profiles and overlays

The retail and 1.3 profiles interpret the original archive set and table priorities.
Loose source files override archive content. After conversion, optional packages
can supply HD textures, remaster materials, skeletal characters or HD weapons.

An overlay changes the installation's content selection. It does not become part
of the original data directory. Explicit package paths are useful when comparing
an alternative package without changing another installation's inputs.

## Profiles, saves and map identity

Player settings and saves live outside the generated installation directory. They
can survive code rebuilds, while the installation itself remains reproducible from
its manifest.

Map saves include checksums. If conversion changes geometry, a save for the old map
may no longer apply to the new one. Keeping the previous installation and its saves
together provides a way back without weakening that check.

See the [asset reference](../reference/assets.md) for profile rules and options, or
[Update an installation](../how-to/update-installation.md) for the commands.
