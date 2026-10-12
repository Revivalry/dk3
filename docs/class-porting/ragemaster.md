# Ragemaster — review sheet

The reference files are `dlls/world/ragemaster.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/ragemaster/ragemaster.zig` (policy: attack, pain constants) and `src/classes/actors/ragemaster/server/ragemaster.zig` (the shared ground combat with a class spec).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_ragemaster`, model `m_ragemaster`, aidata 340 HP, run 200, walk 100, FOV 215; robotic, bloodless; punch 15 + rnd·20, reach 130; no door use | Implemented |
| Spawn | Generic; two e1m4b ragemasters carry `sight` 320/300 and stay dormant until the player comes that close or hits them | Honoured (`sight` key) |
| Combat | Faces within 5° and within 130: `atake`, punches on frames 14 and 22; clips run back to back; beyond 130 it chases (`runa`) | Implemented (shared ground combat) |
| Pain | Generic two rolls of 5%, limit 65 (`hita` on the first roll, or on the second for 65+, else a brief stall); the acquiring hit skips the first roll | Implemented (sequence 406; it was one 5% roll) |
| Death | `diea` only | Implemented |
| Timing | Clips at 20 fps (`atake` 1500 ms, punches at 800 and 1200 ms) | Implemented (sequence 407: actor clips at 20 fps) |
| Open questions | `ataka`–`atakd` are unused in the reference; the punch sound plays on world hits too | Recorded |

## Animation inventory (converted `.anim`)

`m_ragemaster`: `amba` 0–39, `atake` 151–180, `diea` 181–203, `hita` 204–223, `runa` 224–243, `walka` 244–275 (`ataka`–`atakd` unused). All present.

Neural replacement: motion authored on the admitted anatomical rig, not fitted to the source (sequences 418–420 were rejected by the owner). Procedural idle, locomotion and death clips; since sequence 421, its two punches and pain are authored action clips (`neural_actions.py`). See [neural monsters](../neural-monsters.md).

## Verification (sequence 406)

- Implemented, not yet verified in game: the generic pain.
