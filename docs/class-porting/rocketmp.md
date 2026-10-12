# Rocket MP — review sheet

The reference files are `dlls/world/rocketmp.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/rocketmp/` (`rocketmp.zig`: choices, chase-evade, rocket tuning; `server/rocketmp.zig`: attacks; `server/actor_rocketmp.zig`: hooks). Rockets are the shared actor rockets.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_rocketmp` (41, e4m5–e4m6), model `m_rocketmp`, aidata 150 HP, run 300; knife 10 + rnd·10, reach 96; rockets 20 + rnd·10 at 600 u/s | Implemented |
| Chase attack | A mobile MP opens chasing: a running rocket (`atakc`) when its 2 s cooldown has passed, else the knife (`atakb`) | Implemented (sequence 411: no standing opener) |
| Close | Under 120: knife (`atakb`) half the time, else a 1 s chase-evade 25° off the enemy line | Implemented (sequence 411: no cooldown gate, 1 s) |
| Stationary | Do-not-move MPs fire `ataka` at any range they see | Implemented (sequence 411) |
| Rockets | Only the left launcher fires (no right-hand shot is authored); 1/4 speed to full at 210 ms | Implemented |
| Pain | Generic handler, 20% rolls, limit 25 | Implemented |
| Death | `diea` | Implemented |
| Take cover | Spawnflag 512 (four placed): the shared cover cycle; from cover its rocket leaves whichever way it faces | Implemented (sequence 411) |
| Open questions | Run and walk clips carry a default attack frame in the reference (not reproduced) | Open |

## Animation inventory (converted `.anim`)

`m_rocketmp`: `amba` 0–19, `ambb` 20–59, `ataka` 60–89, `atakb` 90–109, `atakc` 110–121, `diea` 122–139, `hita` 140–159, `runa` 160–171, `walka` 172–191. All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
