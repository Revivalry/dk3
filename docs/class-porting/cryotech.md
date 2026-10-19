# Cryotech — review sheet

The reference files are `dlls/world/cryotech.cpp`, `ai_weapons.cpp` (`cryo_spray`) and the generic AI. Provenance only.

The native code is `src/classes/actors/cryotech/cryotech.zig` (policy: spray table, cooldown, pain constants) and `src/classes/actors/cryotech/server/cryotech.zig` with `server/cryotechs.zig` and `server/cryo_spray.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_cryotech`, model `m_cryotech`, aidata 175 HP, run 70, walk 40, FOV 140; spray 4 + rnd·10, reach 256; opens doors | Implemented |
| Combat | Faces within 5°, then `bambb` at most every 3 s: eight invisible spray bolts (250 u/s, 0.8 s life) from a right-to-left nozzle sweep on clip frames 8–22; between volleys it holds the clip's last frame and keeps turning. No freeze or slow: damage only | Implemented (`pulses`, `State.begin`) |
| Engage range | The spray's reach (256); the aidata attack distance (210) is unused | Implemented (sequence 406) |
| Scripts | Scripted `bambb`/`bambc` spray on their table frames (the e1m6 work scripts) | Implemented (`ambient`) |
| Pain | Generic two rolls of 25%, limit 35 (`hita` on the first roll, or on the second for 35+); the acquiring hit skips the first roll | Implemented (sequence 406; it was 25% for 35+ only) |
| Death | `diea` only | Implemented |
| Timing | Clips at 20 fps (sprays 400–1100 ms into `bambb`) | Implemented (sequence 407: actor clips at 20 fps) |
| Open questions | Spray firing that depends on think-phase alignment, and the post-pain spray burst, are reference defects, not ported. The header's "ignore the player until shot" design is unimplemented in the reference | Decisions recorded |

## Animation inventory (converted `.anim`)

`m_cryotech`: `amba` 60–88, `bamba` 119–147, `bambb` 148–176, `bambc` 177–186, `diea` 434–459, `hita` 460–474, `runa` 475–490, `walka` 491–514, plus script clips. All present.

Neural replacement: motion authored on the admitted anatomical rig, not fitted to the source (sequences 418–420 were rejected by the owner). Procedural idle, locomotion and death clips; since sequence 421, its spray sweeps and pain are authored action clips (`neural_actions.py`). See [neural monsters](../neural-monsters.md).

## Verification (sequence 406)

- Implemented, not yet verified in game: pain and engage range.
