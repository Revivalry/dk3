# Shark — review sheet

The reference files are `dlls/world/shark.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/shark/` (`shark.zig`: bite choice, water rules, pain; `server/sharks.zig`: swimming, wandering, biting).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_shark` (26, e4m2 and e4m6b), model `m_shark`, aidata 150 HP, run 360; bite 10 + rnd·10, reach 80 | Implemented |
| Goals | Spawnflag 1 or 4 wanders (at twice its walk speed); otherwise it idles until it has an enemy | Implemented (sequence 411: idling, wander pace) |
| Dry prey | Its enemy leaving the water (level 0) suspends the fight and it wanders; it resumes when the enemy is fully submerged (level 3) | Implemented |
| Chase | Swims at its prey; with no way through the water it gives up the chase | Implemented (sequence 411: giving up) |
| Bite | Within 80: `atakb` 2/3 or `ataka` 1/3, stopping dead | Implemented |
| Pain | Generic handler at 100%, limit 25: every hit flinches, the acquiring hit only for 25 or more | Implemented (sequence 411: light hits flinch) |
| Death | `diea`, sinking | Implemented |
| Open questions | Native steers along its water route without the reference's velocity blend and keeps out of the shallows (native containment) | Recorded |

## Animation inventory (converted `.anim`)

`m_shark`: `amba` 0–19, `ataka` 20–40, `atakb` 41–61, `diea` 87–107, `hita` 123–137, `swima` 138–167 (`atakc`, `dieb` unused). All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
