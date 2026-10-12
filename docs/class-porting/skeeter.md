# Slaughterskeet — review sheet

The reference files are `dlls/world/skeeter.cpp`, `protopod.cpp` (hatching) and the generic AI. Provenance only.

The native code is `src/classes/actors/skeeter/skeeter.zig` and `src/classes/actors/skeeter/server/skeeter.zig` with `server/skeeters.zig` (flight). The protopod's hatching is `server/protopods.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_slaughterskeet`, `m_skeeter`; 50 HP, run 200, walk 120, FOV 215; flies; robotic, always gibs | Implemented |
| Spawn | Generic spawnflags only (1/4 node wander, 2 path follow, 8 random wander, 16 ignore player, 32 snipe, 128 do-not-move, 512 take cover, 1024 always gib); keys `target`, `skin`, `sight`, `SightRange`, `speak`, `spawnname`, `default_aiscript`; hatched from a protopod (`speciala`, rising 4 u per tick) | Hatching implemented; 2 (path follow, air path) and 128 (stays put, still strikes what comes within reach) honoured; 1/4 (and, once it has seen the player, any idle skeet) wander the air nodes at twice walk speed (`common.airWander`; implemented, unverified in game) |
| Combat | Chase (run speed, air nodes when out of sight) until within 178 → dart at 1.5 × run speed (3 s) → strike when within reach + 32 (80) → `ataka` (hit at frame 7, 48-unit trace, 5 + rnd·2) → fly away (≤ 512 units, 3 s or within 64) → chase | Implemented; the dart strike threshold now uses the 32-unit margin |
| Pain | 75% `hita` (950 ms lock), no threshold; not on the acquiring hit | Implemented (`common.flinch`); not while hatching |
| Sounds | Sight ≈ always `sightb`; flight loop `flya`; attack `ataka` frame 3; pain `hita` | Implemented through frame cues |
| Open questions | Idle and wander for fliers (air node wander) not ported; the reference's world-axis fly-away search is replaced by the shared air escape | Recorded |

## Animation inventory (converted `.anim`)

`m_skeeter`: `amba`, `ambb`, `ataka`, `flya`, `hita` 136–155, `speciala`, `diea`. All present.

## Verification (sequence 405)

- Unit test: dart → attack at 79 units (reach 48 + 32), strike once, retreat.
- In game: covered by the existing probes (opening-actors); pain shares the frog's verified mechanism.
