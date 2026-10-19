# Inmater — review sheet

The reference files are `dlls/world/inmater.cpp` and the generic AI (`ai_think.cpp`, `ai_func.cpp`, `ai_weapons.cpp`, `ai_aim.cpp`). Provenance only.

The native code is `src/classes/actors/inmater/inmater.zig` (policy: attack choice, sweep offsets, pain chance) and `src/classes/actors/inmater/server/inmater.zig` with `server/inmaters.zig` (think, sweep, sidestep).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_inmater`, model `m_inmater`, aidata row (250 HP, run 120, walk 45, FOV 360); robotic, bloodless; laser (15 + rnd·5, 900 u/s, reach 800) and punch (25 + rnd·25, reach 160) | Implemented (aidata, `laser.Tuning`) |
| Spawn | Generic spawnflags; maps use 0, 128 and 2 with `target` | Honoured: 2, 128 |
| Combat | Faces within 1° before each clip. Beyond 128 units: `ataka` 75% (laser on the attack frame) or `atakc` 25% (six-shot sweep on clip frames 10, 14, 18, 22, 26, 36 from six muzzle offsets); within 128: `atakb` (punch). Crossing 128 mid-clip restarts the choice. The next clip starts at once at the end of the last | Implemented (`select`, `sweep`, `inmaters.think`) |
| Sweep cover | A sweep shot blocked by a living ally of the same side pushes a 52-unit sidestep (2 s limit) | Implemented (`clearSweep`, sidestep) |
| Engage range | The reach of the weapon it used last (800 laser, which it starts with; 160 after a punch); aidata attack distance 900 is unused | Implemented (sequence 406: `reach`) |
| Pain | The hit that makes its attacker the enemy only acquires it; later hits flinch with `hita` 5% of the time, no damage threshold, 700 ms | Implemented (sequence 406) |
| Idle | `amba`; after the player has been seen, node wander with `walka` | Implemented (shared idle and roam) |
| Death | `diea`; robotic gibs on a kill of 30% of base health | Implemented (shared remains) |
| Sounds | Sight `m_inmatersight`; clip frame sounds (atakb and atakc file names are swapped in the reference table); punch hit `m_knifehite` | Implemented from the event table |
| Timing | Monster clips run at 20 fps (`ataka` 400 ms, `atakb` 1200 ms, `atakc` 2200 ms) | Implemented (sequence 407: actor clips at 20 fps) |
| Open questions | Prisoner execution goal is dead code. A crouched player takes untraced fire-frame damage (reference defect, not ported). The sweep permanently moves later `ataka` shots to the last sweep offset (not ported) | Decisions recorded |

## Animation inventory (converted `.anim`)

`m_inmater`: `amba` 0–22, `ataka` 23–31, `atakb` 32–55, `atakc` 56–100, `diea` 146–166, `hita` 167–181, `runa` 182–200, `walka` 201–230 (`atakstart`/`atakstop` unused). All present.

Neural replacement: motion authored on the admitted anatomical rig, not fitted to the source (sequences 418–420 were rejected by the owner). Procedural idle, locomotion and death clips; since sequence 421, its cannon shot, stab, six-shot sweep and pain are authored action clips (`neural_actions.py`). See [neural monsters](../neural-monsters.md).

## Verification (sequence 406)

- Unit tests: attack choice keeps the 128-unit melee boundary and the 75/25 split; it engages within its last weapon's reach.
- Implemented, not yet verified in game: the first-hit pain rule and the reach change.
