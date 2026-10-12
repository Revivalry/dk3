# Medusa — review sheet

The reference files are `dlls/world/medusa.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/medusa/` (`medusa.zig`: range, spit style; `server/medusas.zig`: attacks, gaze, petrify); her spit is the shared venom spit.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_medusa` (one, e2m5e, spawnflags 192: do-not-move), model `m_medusa`, aidata 1200 HP; bite 15 + rnd·10, reach 80 (poisons); spit 10 + rnd·5 at 400 u/s, reach 350; her death fires the mid-level cinematic | Implemented |
| Range | Re-rolled: within 80 always; within 350 on 50%; within 1250 on 5% | Implemented |
| Attack | Within 80 the bite (`ataka`); beyond 350 or on a 5% roll the gaze; otherwise the spit (`atakb`) | Implemented |
| Gaze | Rattle (`atakc`, 3 s: grey flashes and gravel sounds on odd seconds), gaze (`atakd`, 3 s: eye contact petrifies), set down (`atake`); no pain for the whole gaze | Implemented |
| Pain | One 1% roll (`hita`, 850 ms) | Implemented |
| Death | `diea`, or gibs on a heavy kill | Implemented |

## Animation inventory (converted `.anim`)

`m_medusa`: `amba` 0–29, `ataka` 30–69, `atakb` 70–109, `atakc` 110–131, `atakd` 132–151, `atake` 152–161, `diea` 162–190, `hita` 191–208, `runa` 209–226, `walka` 227–250. All present.

## Verification (sequence 410)

- Implemented, not yet verified in game.
