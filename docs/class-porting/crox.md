# Crox — review sheet

The reference files are `dlls/world/crox.cpp` and the generic AI (`ai_func.cpp`, `ai_think.cpp`, `ai_weapons.cpp`, `ai_aim.cpp`). Provenance only.

The native code is `src/classes/actors/crox/crox.zig` (policy: attack choice, height rule, pain chance) and `src/classes/actors/crox/server/actor_crox.zig` with `server/crox.zig` (think, swim).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_crox`, model `m_croco`, aidata 150 HP, run 175, walk 50, FOV 270; amphibious, robotic, bloodless; bite 15 + rnd·20, reach 60 | Implemented |
| Spawn | Generic spawnflags; maps use `sight` 1024/128 and skill bits | Honoured (shared) |
| Height rule | An enemy more than 100 units above or below: it wanders (and stops seeing the player); back within 100 it resumes | Implemented (`beyondHeight`) |
| Movement | Water level 2+: swims (`swima`, swim sounds on odd seconds); on land `runa` with an enemy, `walka` without | Implemented (`swim`, `actor_water`) |
| Water | A swimmer never drowns (AI_CheckWaterDamage skips MOVETYPE_SWIM, DFL_AMPHIBIOUS) | Implemented and passed (`amphibious` trait, sequence 375 `crox/`) |
| Combat | Within 60 and facing (5° yaw): surface/land `atakc` 67% / `atakd` 33%, submerged `atakb` 67% / `ataka` 33%; the bite lands on clip frame 13 if facing, else that bite misses; beyond 60 the bite stops at once | Implemented (sequence 406: a turned-away strike frame is lost) |
| Pain | Single roll (the reference's `AI_StartPain`): 20%, `hita`, no damage threshold; the acquiring hit only acquires; the interrupted bite restarts | Implemented (sequence 406: `common.flinch`) |
| Death | `diea` or `dieb` 50/50; robotic gibs on a kill of 30% of base health | Implemented |
| Timing | Clips at 20 fps (bites 750/800 ms, `hita` 450 ms lock) | Implemented (sequence 407: actor clips at 20 fps) |
| Open questions | After its first ambient the reference crox treads `walka` in place (end-flag consumption); native idles. The height rule leaves ignore-player set if the wander ends otherwise (not ported) | Decisions recorded |

## Animation inventory (converted `.anim`)

`m_croco`: `amba` 0–19, `ambb` 20–47, `ataka` 48–63, `atakb` 64–79, `atakc` 80–94, `atakd` 95–109, `diea` 110–131, `dieb` 132–151, `hita` 152–161, `runa` 172–185, `swima` 186–205, `walka` 206–225 (`hitb` unused). All present.

## Verification (sequence 406)

- Unit tests: attack pose, height rule, facing, wander candidates.
- `runtime_player_probe.py --scenario crox` (regression).
- Implemented, not yet verified in game: pain and the lost strike.
