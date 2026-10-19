# Satyr — review sheet

The reference files are `dlls/world/SATYR.CPP` and the generic AI. Provenance only.

The native code is `src/classes/actors/satyr/` (`satyr.zig`; `server/satyr.zig`: the shared ground combat with a class spec).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_satyr`, model `m_satyr`, aidata 200 HP, run 280, FOV 215; punch 15 + rnd·10, reach 80 | Implemented |
| Attack | Within 80: `ataka` or `atakb` 50/50 (strikes on frames 12; 8 and 18); further away it runs swinging `atakc`; a pending strike waits for it to face | Implemented |
| Transitions | `transa`/`transb` are asked for but missing from the model: nothing plays | Same (absent clips) |
| Pain | Generic two 5% rolls, limit 35 (`hita`, 1000 ms lock); the acquiring hit skips the first | Implemented (sequence 410; it was one roll) |
| Idle | `amba` 67%, `ambb` 23%, `ambc` 10% with their sounds | Implemented (idle choices) |
| Death | `diea` only | Implemented |

## Animation inventory (converted `.anim`)

`m_satyr`: `amba` 0–19, `ambb` 20–72, `ambc` 73–115, `ataka` 116–135, `atakb` 136–158, `atakc` 159–175, `diea` 176–213, `hita` 214–234, `runa` 255–270, `walka` 271–290 (`hitb` unused). All present.

## Verification (sequence 410)

- Implemented, not yet verified in game.
