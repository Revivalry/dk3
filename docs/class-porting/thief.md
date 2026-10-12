# Thief — review sheet

The reference files are `dlls/world/thief.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/thief/` (`thief.zig`: choice, shaft style; `server/thieves.zig`); its range test is the shared `thrown_range`, its knife a shared shaft (`axe` touch).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_thief`, model `m_thief` (scale 1.5), aidata 150 HP, run 500, FOV 190; punch 10 + rnd·10, reach 80; knife 4 + rnd·4 at 900 u/s, reach 600 | Implemented |
| Range | Re-rolled at each test: under 80 always; within 600 on 60%; 100–250 on a second 60% | Implemented (`thrown_range.inRange`) |
| Attack | Facing (5°): beyond 80 `ataka` (knife released on frame 10, clear-shot check or sidestep), else `atakb` (chop on frame 10); no cooldown, it acts every think; an unfaced release waits | Implemented (sequence 410: every think, not every second) |
| Knife | Spins 300°/s; stuck in the world it is pulled back 12 and pitched over (body-hit sound); vanishes in the sky; 3 s flight | Implemented (shaft `axe` touch) |
| Pain | Generic two 30% rolls, limit 35; the acquiring hit skips the first | Implemented |
| Death | `diea` or `dieb` 50/50 | Implemented (`deathCoin`) |
| Take cover | Spawnflag 512 only; no shipped thief has it | Not ported (no placement) |
| Open questions | No stealing behaviour exists in the reference despite the name | Recorded |

## Animation inventory (converted `.anim`)

`m_thief`: `amba` 0–19, `ambb` 20–79, `ataka` 80–113, `atakb` 114–140, `diea` 141–152, `dieb` 153–180, `hita` 181–202, `runa` 214–225, `walka` 226–245 (`jumpa` unused). All present.

## Verification (sequence 410)

- Unit tests: the range test's bands; the 80-unit choice.
- Implemented, not yet verified in game.
