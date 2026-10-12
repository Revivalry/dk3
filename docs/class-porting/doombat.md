# Doombat — review sheet

The reference files are `dlls/world/doombat.cpp`, the flight helpers in `func2.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/doombat/` (`doombat.zig`: fireball rule, bob, flight speed, fireball style; `server/doombats.zig`: flight, claw and fireball cycles). Its escape points are the shared air escape; its fireball is the shared fireball.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_doombat` (88, Episode 3), model `m_doombat`, aidata 50 HP; claw 2 + rnd·5, reach 80; fireball 2 + rnd·10 at 400 u/s; senses across the level | Implemented |
| Mode | Line of sight, health at most base²/200 and a 25% roll: fireball cycle; otherwise claw cycle, re-rolled every 300 ms while closing in | Implemented (sequence 411: re-roll) |
| Claw cycle | Flies to 80 above the enemy, `atakb` claw, then flies away to a free node | Implemented |
| Fireball cycle | Hover 650 ms (spit warning), `ataka` spit | Implemented; native flies its escape before hovering (the reference's escape deletes itself) |
| Flight | Walk × 2 (400) until it first chases without sight, then run speed (250); bobs through five impulses; touching a wall pushes it off | Implemented (sequence 411: speeds, five-step bob) |
| Pain | One 75% roll (`hita`), no limit | Implemented |
| Death | Falls at twice gravity, `diea`; gibs on a heavy kill | Implemented (sequence 411: twice gravity) |
| Open questions | Sight range stays at the whole level after acquisition (the reference drops it to 4000); the swing starts without waiting for the flight loop to end | Open |

## Animation inventory (converted `.anim`)

`m_doombat`: `amba` 0–14, `ataka` 15–24, `atakb` 25–39, `diea` 40–54, `flya` 55–64, `hita` 65–79. All present (`flyc` is absent from the model and never requested).

## Verification (sequence 411)

- Unit tests: health rule; the five-step bob.
- Implemented, not yet verified in game.
