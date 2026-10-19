# Firefly — review sheet

The reference file is `dlls/world/FireFly.cpp`. Provenance only.

The native code is `src/classes/actors/firefly/` (`firefly.zig`: sprite shapes; `server/fireflies.zig`: spawning and flight); the particles are the shared glowing sprite particles (`mechanics/policy/actors/glow_particle.zig`).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_firefly`: an invisible emitter, not an actor; 1–10 sprite flies wander about it (10 masters, 54 flies, E1 maps) | Implemented |
| Keys | `count` (1–10), `distance` (20–200), `velocity` (1–500), `scale`, `_color`, `color2` (colour cycling), `delta_alpha`, `alpha_level`; spawnflags pick the sprite (first set bit) | Implemented (`shape`) |
| Flight | Each 100 ms: heads home when beyond `distance` or stalled, scatters outward near home, wobbles by its personality; passes through walls, stopped only by liquids | Implemented |
| Alpha and colour | Alpha steps every `5·personality` thinks between 0 and its level; colour cycles to `color2` and back | Implemented |
| Open questions | Bit 0 can never select its sprite and flag 8 repeats flag 4's sprite (reference defects, kept). A personality of 0 divides by zero in the reference; native floors it | Recorded |

## Animation inventory

Sprites only (no clips).

## Verification (sequence 410)

- Implemented, not yet verified in game.
