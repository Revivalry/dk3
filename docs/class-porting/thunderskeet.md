# Thunderskeet — review sheet

The reference files are `dlls/world/thunderskeet.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/thunderskeet/thunderskeet.zig` and `src/classes/actors/thunderskeet/server/thunderskeet.zig` with `server/thunderskeets.zig` and `server/thunder_spray.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Spawn | Generic spawnflags; 128 makes it a turret | 128 honoured (stays put, still fires); 1/4 (and, once it has seen the player, any idle skeet) wander the air nodes at twice walk speed (`common.airWander`; implemented, unverified in game) |
| Identity | `monster_thunderskeet`, `m_tskeet`; 600 HP, run 350, FOV 215; flies; robotic, always gibs | Implemented |
| Combat | Chase to within 600 and above by 96; attack `ataka` (700 ms): one glob per window (frames 27–28 and 31–32: the thinks see 28 and 32), the second alternate; then hover 2 s (rising 64 u/s while there is headroom) → chase | Implemented; the volley now fires two globs, not four |
| Glob | 128 + rnd·64 u/s wobbling sprite, 15 s life, passes through bodies, 40-point blast (256 radius, quadratic) on world contact; owner takes half | Implemented |
| Pain | 10% `hita` (700 ms lock), not on the acquiring hit | Implemented (`common.flinch`) |
| Open questions | Dart and fly-away tasks are dead code in the reference (not ported) | Recorded |

## Animation inventory (converted `.anim`)

`m_tskeet`: `amba`, `ataka` 20–33, `flya`, `hita` 67–81, `diea`. All present.

## Verification (sequence 405)

- Unit tests: two shots per volley at frames 28 and 32; blast falloff; glob wobble bounds.
- In game: not staged (the e1m1b thunderskeet is not present at map start).
