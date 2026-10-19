# Froginator — review sheet

The reference files are `dlls/world/froginator.cpp` and the generic AI (`ai_think.cpp`, `ai_func.cpp`, `ai_weapons.cpp`, `ai_aim.cpp`). Provenance only.

The native code is `src/classes/actors/froginator/froginator.zig` (policy: attack choice, strikes, tuning, spit) and `src/classes/actors/froginator/server/froginator.zig` with `server/froginators.zig` (think, leap) and `server/frog_spit.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_froginator`, model `m_frog`, aidata row (30 HP, run 220, walk 45, FOV 270, scale 0.65); amphibious, robotic, bloodless | Implemented |
| Spawn | Generic spawnflags only (1/4 node wander, 2 path follow, 8 random wander, 16 ignore player, 32 snipe, 128 do-not-move, 512 take cover, 1024 always gib); keys `target`, `skin`, `sight`, `SightRange`, `speak`, `spawnname`, `default_aiscript` | Honoured: 1/4 (node wander), 2, 16, 128 (attacks from where it stands, never chases or leaps). 8, 32 and 512 are not |
| Combat | ATTACK_THINK: within 400 units, 40% (not on easy) attack, else chase. Spit (`ataka`, frame 7) beyond 80 units and dry, else bite (`atakb`, frames 6 and 14). Chase: 35% per think a leap between 200 and 425 units (`atakc`, 2.35 × run speed × distance / 425 forward, 270 up); bite within 60 | Implemented (`State.choose`, `strikes`, `froginators.think`) |
| Spit | Straight, 400 u/s, 5 s life, 5 + rnd·5 damage; on a client: poison 1 per 3 s for 15 s | Implemented (`frog_spit.zig`) |
| Pain | A hit from a new enemy only acquires it; otherwise 20% `hita` (900 ms lock), no threshold. The reference pain task also stops a leap mid-air | Implemented (`common.flinch`); decision: no flinch in mid-leap |
| Idle | `amba` 75% / `ambb`; after the player has been seen, an idle frog wanders the nodes (`walka`) | Implemented (`common.roam`) |
| Death | `diea`; gibs (robotic) on a kill of 30% of base health or more | Implemented (shared remains) |
| Sounds | Sight `sighta`/`sightb` 50/50; spit and bite frame sounds; leap `jumpa`+`amba`, landing `ambb`; wall rebound shield hits | Implemented except the wall-rebound sound |
| Open questions | The reference never makes the frog swim (dead code); its wall rebound sound is not played natively | Recorded |

## Animation inventory (converted `.anim`)

`m_frog`: `amba`, `ambb`, `ataka`, `atakb`, `atakc`, `hita` 104–122, `runa`, `walka`, `diea`. All present.

## Verification (sequence 405)

- Unit tests: attack choice, strikes; pain-clip traits.
- Headless (e1m1b frog 118): after the first acquiring hit, diagnostic hits flinch with `hita` (frames 108–119) on some hits.
