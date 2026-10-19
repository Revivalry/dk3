# Wisp cluster — review sheet

The reference file is `dlls/world/wisp.cpp`. Provenance only.

The native code is `src/classes/actors/wisp/` (`server/wisps.zig`: cluster and wisp flight; `client/`: sprites). The cluster is the shared energy swarm (`mechanics/policy/actors/energy_swarm.zig`, `mechanics/server/energy_swarms.zig`), which Wyndrax drains through its `collect`/`take`/`release` interface.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_wisp`: an invisible emitter, not an actor; 1–10 blue sprite wisps (13 clusters: 10 in e3m4b, 3 ambient in e3m5a) | Implemented |
| Keys | `count` (1–10, default 3), `distance` (20–200, 75), `velocity` (1–500, 35), `scale`, `delta_alpha`, `alpha_level` (0.35) | Implemented |
| Flight | Each 100 ms: wanders about its home, turning back beyond `distance` + 100 or when stalled; sine kicks by personality | Implemented |
| Collection | When Wyndrax drains it, one wisp at a time flies to him, puffs, and grants one ammo; collected wisps respawn after 100 s | Implemented |
| Sounds | `e_wisploopa` ambient while any wisp is active; its "lostsole" companion files do not exist in Gold (silent, kept) | Implemented |

## Animation inventory

Sprites only (no clips).

## Verification (sequence 411)

- Implemented, not yet verified in game.
