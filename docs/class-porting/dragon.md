# Dragon — review sheet

The reference files are `dlls/world/dragon.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/dragon/` (`dragon.zig`: fireball style, breath; `server/dragons.zig`: hover, breath, fireball, patrol calls; `client/`: the breath). Its fireball is the shared fireball (raised 96, burning).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_dragon` (two: e3m4a, e3m6a, both on closed corner paths), model `m_dragon`, aidata 800 HP; fireball 15 + rnd·5 at 600 u/s; always gibs | Implemented |
| Patrol | Flies its path (`flya`); every 5 s a 25% call | Implemented |
| Cycle | In sight: hover 1–3 s (calls on every hover), then `ataka`: breath (visual) from 1100 to 1950 ms, fireball at frame 44 straight at the enemy, five blasts at its impact (up to 2.2 × damage) | Implemented (sequence 411: breath window) |
| Pain | One 75% roll (`hita`, 850 ms); an interrupted hover re-rolls, an interrupted attack replays from its first frame without breathing again | Implemented (sequence 411: attack replay) |
| Death | Always gibs | Implemented |
| Calls | Its hover call carries 2048 units at full volume, its patrol calls 900–1024 | Implemented (sequence 411) |
| Open questions | After killing its enemy it returns to its path (the reference freezes in its finished attack pose) | Decided |

## Animation inventory (converted `.anim`)

`m_dragon`: `ataka` 0–58, `diea` 59–84, `flya` 106–125, `hita` 126–143, `hover` 144–163 (`dieb` unused). All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
