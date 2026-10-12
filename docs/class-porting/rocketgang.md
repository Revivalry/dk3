# Rocket gang (rocketdude) — review sheet

The reference files are `dlls/world/rocketgang.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/rocketgang/` (`rocketgang.zig`: choice, rocket tuning and style; `server/rocketgang.zig`: attacks, evasion; `server/actor_rocketgang.zig`: hooks). Rockets are the shared actor rockets.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_rocketdude` (22, e4m2–e4m3), model `m_rockgang`, aidata 180 HP; rockets 40 + rnd·10 | Implemented |
| Choice | Under 500 the standing shot (`ataka`, reach 700), else kneeling (`atakb`, reach 1400); its reach follows the last rocket | Implemented |
| Cycle | Volleys follow each other without rest; targeted, it takes evasive action (50% at a start, 80% at a clip end) | Implemented (sequence 411: the 2 s rest removed) |
| Stationary | Do-not-move rocketeers fire at any range they see | Implemented (sequence 411) |
| Rocket | Leaves the shoulder, accelerates from 1/7 speed to full at 510 ms, 4 s life, bursts within 128 | Implemented |
| Pain | Generic handler, 10% rolls, limit 50 | Implemented |
| Death | `dieb` when its killer is within 45° in front, else `diea` | Implemented (attacker, not the projectile, gives the side) |
| Open questions | Its own blast does not hurt it (shared rockets); take cover and snipe are used by no map | Open |

## Animation inventory (converted `.anim`)

`m_rockgang`: `amba` 0–19, `ambb` 20–72, `ataka` 73–108, `atakb` 109–150, `diea` 151–180, `dieb` 181–199, `hita` 200–219, `runa` 262–275, `walka` 276–299. All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
