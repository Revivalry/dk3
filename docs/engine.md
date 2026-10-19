# Engine architecture

Assessed against the merged native runtime on **20 October 2026**. dk3 targets
Linux x86-64 GNU and Zig 0.16.x. It combines the bundled ioquake3 platform with
project-owned Zig gameplay, networking and Vulkan rendering. The complete game
remains in development; [status](status.md) records the acceptance limits.

## Build products and dependencies

`make build` invokes `zig build -Doptimize=ReleaseSafe`. It compiles directly from
`engine/ioquake3`, without a sibling engine checkout, Gold code or proprietary assets.
The default prefix is `zig-out/native-dev`.

| Product | Purpose |
| --- | --- |
| `bin/dk3` | Client and local campaign host |
| `bin/dk3ded` | Dedicated server |
| `bin/renderer_vulkan.so` | Native Zig Vulkan renderer |
| `bin/renderer_opengl1.so`, `bin/renderer_opengl2.so` | Bundled OpenGL alternatives |
| `lib/dk3/qagame.so`, `cgame.so`, `ui.so` | Native Zig server, client and menu modules |
| `bin/dkguard` | Guarded process execution, time/memory limits and headless display |
| Online binaries | Coordinator, worker, client utility and operator utility |

SDL2, Vulkan development files, `glslc`, SQLite3 development files and `pkg-config`
are host dependencies. Optional FreeType support uses `-DUSE_FREETYPE=true`.
Python powers local asset/dev tools; component tests use the pinned CPU dependencies
in `dkq3/tools/requirements-test.txt`. [Building](building.md) covers setup and targets.

## From engine services to classes

```text
ioquake3 platform / filesystem / collision / audio / module loader
                         │ native ABI
              server.zig · client.zig · ui.zig
                         │
          mechanics ↔ checked registries ↔ class adapters
                         │
        core: ECS · jobs · math · animation · saves · navigation
```

The path defines ownership. `src/engine` exposes the ioquake3 ABI and services;
`src/core` implements game-independent runtime mechanisms. Neither layer imports
game behavior. `src/mechanics` supplies shared Daikatana mechanisms; `src/game`
enumerates classes and components. Each `src/classes/<kind>/<class>/` owns its
policy and server/client/domain adapters.

A new class supplies checked hooks and registry entries. Shared mechanisms do not
switch on named actors, map classnames or weapon IDs. A class never imports another
class's policy. The class-ownership checker enforces a baseline that only decreases;
the current baseline has zero violations. Read the [class contract](runtime-zig.md#class-contract)
and [porting procedure](class-porting.md) before adding behavior.

## ECS, identities and scheduling

The archetype ECS uses typed components, aligned chunks, generational handles and
persistent IDs separate from engine entity slots. Structural changes commit at
barriers in deterministic order. Component pointers cannot survive structural changes.
Systems resolve persistent IDs when using an entity, rather than retaining row indices.

Jobs declare reads, writes and dependencies. Compatible chunk work can run concurrently;
order-sensitive gameplay remains serial. ioquake3 calls stay on the owning thread.
Workers produce requests for engine queries, resolved at barriers. Workers join before
save capture and teardown. `dk3_jobs=0` runs inline; positive values select workers.
Engine structs are transport projections of authoritative ECS state.

## Rendering

Vulkan is the default renderer, with automatic OpenGL2 fallback if the Vulkan module
is unavailable or its capability probe refuses the system. Later surface/device
initialization failures can be fatal. OpenGL1 and OpenGL2 remain selectable through
`cl_renderer`. The native Vulkan
module requires Vulkan 1.3; optional ray-query capabilities enable its RT passes.
Renderer export ABI **13** is defined in the bundled `renderercommon/tr_public.h`.

| System | Implemented behavior | Acceptance limits |
| --- | --- | --- |
| World and models | BSP/PVS, resident world handles, MD3 and IQM animation, supplied bones, materials and lightstyles | Complete scene and material comparison remains open |
| Raster remaster | HDR, exposure, bloom, GGX material response, liquids, volumetrics, weather, clustered lights and model shadows | Overall artistic and physical-display acceptance remains open |
| Ray queries | World lighting/shadows/reflections, alpha-tested world geometry, GPU-skinned character shadow rays | Characters do not have a complete reflected-hit shading table |
| Advanced lighting | DDGI, directional baking and optional path tracing | Hardware/map/settings coverage is scoped; path tracing defaults off |
| Temporal resolve | Own resolve, bundled MIT FSR 3.1 and optional user-installed DLSS | Motion matching uses the nearest previous entity with the same model; hardware measurements are not universal FPS guarantees |

Useful controls:

```text
cl_renderer vulkan       # or opengl1 / opengl2; apply with vid_restart
r_vkRemaster 0           # classic presentation
r_vkRayTracing 0         # disable optional RT
r_vkPathTracing 0        # default: off
r_vkUpscaler -1          # auto; 0 own, 1 FSR, 2 optional DLSS (FSR fallback)
r_vkUpscaleQuality 2     # quality; 1 native, 3 balanced, 4 performance,
                        # 5 ultra performance, 6 custom r_vkRenderScale
r_vkStats 1
r_vkValidation 1
```

[Vulkan and remaster](vulkan-remaster.md) documents settings, implementation history,
recorded measurements and remaining visual review. FidelityFX shaders are bundled;
NVIDIA NGX/DLSS binaries and SDK headers are not distributed.

## Resident worlds and campaign progression

The resident-world system keeps region ownership explicit across collision, rendering,
simulation and networking. Authored passage controls transfer the player and party;
inactive/visited map state can be archived independently. World identity is not an
engine slot or renderer handle. Admission stages collision/assets before publication,
and saved state preserves namespaces and persistent references.

Focused scenarios exercise crossings, revisits, saved resident regions and death
restoration. All-map seamless traversal and campaign-wide companion behavior remain
open. See [resident worlds](seamless-worlds.md) and the [acceptance ledger](native-acceptance.md).

## Network and online services

The engine's current wire protocol is **1351**, defined in
`engine/ioquake3/code/qcommon/qcommon.h`. Clients, server and native modules need
matching compatibility identities. Stock Quake III and older dk3 protocols are not
compatible. This protocol number is distinct from the renderer ABI and save schema.

The Zig network layer owns bounded message fields, channels and managed-room packet
protection. Reviewed upstream Huffman code remains C; the C message codec is retained
as a differential test reference. Snapshot transport projects gameplay state rather
than serializing ECS memory.

Managed rooms use an HTTPS coordinator backed by SQLite, approved workers and isolated
dedicated servers. Admission uses guest identity/challenges and directional
ChaCha20-Poly1305 keys. A compatibility hash is a compatibility claim, not anti-cheat
attestation. Offline channels and managed public rooms have different admission paths.
See [wire protocol](protocol.md) and [online architecture](multiplayer-zig.md).
The current full Internet/mode/map acceptance matrix remains open.

## Persistence

Native gameplay snapshot schema **2** is declared in
`src/mechanics/domain/snapshot.zig`, with schema-1 migration. Its portable record
stream is codec version **1**: `DK3SAVE\0`, a 24-byte header, length/count fields and
CRC32. Named records carry typed JSON component/header values, not native memory,
pointers or executable instructions.

Loads decode and validate in separate storage before committing. Campaign records
include active, resident and visited worlds, namespaces, persistent IDs, resources
and map checksums. Timer deadlines rebase against the restored simulation clock.
Original Daikatana saves are not imported, and arbitrary development-save compatibility
is not promised. See [save format](save-format.md) for details.

## Assets, navigation and tools

Original data stays local. Python converters admit explicit retail or 1.3 profiles,
record generation inputs, and publish content-addressed output only after completion.
The installer combines current code with a completed asset generation. Settings and
saves live separately under the native development play prefix.

Bundled BSPC/botlib and local AAS variants support ground navigation. Authored air,
water and track graphs support other movement; runtime collision remains authoritative.
Loading all 84 maps or all navigation variants establishes structural coverage, not
successful gameplay on every route. See [asset conversion](assets.md),
[navigation](navigation.md), [bots](bots-zig.md) and [campaign driver](coop-bot.md).

`dkguard --headless` selects software rendering and dummy audio; use it without
`--gpu`. Xvfb/xauth support headless graphics, while memory caps need `prlimit` or
a working systemd user session. GPU runs use the guard's GPU serialization.

## Verification and source licensing

`make lint`, `make test` and `zig build test` invoke the same component suite.
Do not run them as three separate broad gates. They cover native contracts,
codec/security checks, process supervision, formatting, ownership and synthetic
Python tooling fixtures. Gameplay scenarios have their own inputs and evidence.

Project code is GPL-2.0-or-later. ioquake3 and bundled dependencies retain their
notices; LCC has separate terms and is not a required game-runtime toolchain.
Lua 5.4.7 and the admitted FidelityFX subset are MIT. Original game data, converted
packages, model weights, saves and private reference material are excluded.
Read [component provenance](provenance.md), [publication boundaries](publication.md)
and [copyright](../COPYRIGHT.md).
