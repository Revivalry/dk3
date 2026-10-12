# Buboid — review sheet

The reference files are `dlls/world/BUBOID.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/buboid/` (`buboid.zig`: melt, resurrection and coffin state; `server/buboids.zig`: swings, melt, resurfacing; `server/buboid.zig`: hooks, damage).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_buboid` (159, Episode 3; summoned by Nharre and Garroth), model `m_buboid`, aidata 100 HP, run 80; punch 15 + rnd·10, reach 60 | Implemented |
| Attack | Under 60: `atakb` 2/3 (hit 18), `ataka` 1/3 (hits 12, 19); facing within 5° | Implemented |
| Melt | Enemy out of sight beyond 300, or holy ground ahead (surface flag), or 75% when hurt beyond 250: melts (`atakc`, alpha to 0.05), waits 3–6 s, resurfaces at the first clear node beside the enemy (8 directions), unmelts (`atakd`) | Implemented (sequence 411: 100 ms thinks, 1 s holy retry) |
| Lost sight | A melt on losing sight ends that fight: it resurfaces by the enemy and must find it again | Implemented (sequence 411) |
| Fake death | The first lethal hit collapses it (`diea`, health 1); after 10 s it rises (`speciala`) at full health; a hit while rising leaves it at one; a second lethal hit kills | Implemented (sequence 411: no refill at the end of the rise) |
| Coffin | Nharre's summons rise from a coffin (`speciala`) | Implemented |
| Pain | Generic handler: two 20% rolls, limit 40, the acquiring hit skips the first | Implemented |
| Open questions | The collapse does not alert nearby monsters; melted it is hidden outright (the reference draws it at alpha 0.05) | Open |

## Animation inventory (converted `.anim`)

`m_buboid`: `amba` 0–19, `ambb` 20–79, `ataka` 80–119, `atakb` 120–150, `atakc` 151–184, `atakd` 185–200, `diea` 201–215, `dieb` 216–270, `hita` 271–288, `runa` 305–320, `speciala` 321–340, `walka` 341–360 (`hitb` unused). All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
