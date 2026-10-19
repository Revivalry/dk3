---
template: home.html
title: dk3 — Engine field manual
description: Explore the engine, build the native runtime, and follow the evidence behind the game.
hide:
  - navigation
  - toc
---

## Read the machinery

dk3 is an independent Daikatana rebuild on a bundled, modified ioquake3 engine.
Game, client and UI behavior run in Zig 0.16. The project includes a native Vulkan
renderer, OpenGL alternatives, campaign systems, multiplayer and local asset tools.
This manual publishes the design, build instructions and verification limits together.

<div class="manual-links" markdown>

[**01 / Build & play**<br>Dependencies, source build, legally acquired assets and an isolated installation.](getting-started.md)

[**02 / Inside the engine**<br>The build graph, ECS, native ABI, renderer, worlds, network and persistence.](engine.md)

[**03 / State of the game**<br>Implemented systems, focused passing scenarios and remaining campaign acceptance.](status.md)

[**04 / The reference library**<br>Browse every guide, class review and historical engineering record.](documentation.md)

</div>

## A complete world is the goal

All four episodes, companions, cinematics, deathmatch, CTF and deathtag are in scope.
All 28 weapon classes have native implementations. Focused checks cover many systems;
no complete episode or full campaign has passed end-to-end acceptance.

The [current assessment](status.md) separates source implementation, recorded scenarios
and fresh checks. The [acceptance ledger](native-acceptance.md) retains failures and
superseded results. A green component suite establishes build and regression health.
Campaign completion needs gameplay evidence.

## Bring your own world data

Source builds do not require proprietary game data or private reference code.
Playing requires legally acquired Daikatana assets converted locally. Original and
converted assets, generated character packages and saves are not shipped here.
See [asset setup](assets.md), [component provenance](provenance.md) and
[copyright and licensing](../COPYRIGHT.md).
