# Lasergat — review sheet

The reference files are `dlls/world/lasergat.cpp` and the generic AI (`ai_think.cpp`, `ai_func.cpp`). Provenance only.

The native code is `src/classes/actors/lasergat/lasergat.zig` (policy: turn rate, pain stall, servo sound) and `src/classes/actors/lasergat/server/lasergat.zig` with `server/lasergats.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_lasergat`, model `m_trakatak` (only `shoota`); immobile, robotic, bloodless, always gibs; aidata 170 HP, FOV 215; laser 5 + rnd·5 at 800 u/s, straight along its angles | Implemented |
| Turning | 10° yaw per think, pitch toward the enemy (clamped ±60°); servo sound at most every 400 ms; it fires only within 1° yaw and 2° pitch | Implemented |
| Firing | `shoota` restarts at its last frame: one shot per 500 ms (its clip runs at 10 fps after its first turn); the weapon range never stops it | Implemented (sequence 406: no range stop; cycle on the clip's own clock) |
| Out of sight | Keeps turning toward its enemy; the clip restarts every think and never reaches its fire frame | Implemented (sequence 406) |
| Pain | No pain clip. The acquiring hit only acquires; later hits stall it 75% of the time: the shot cycle restarts after about 100 ms; 500 ms lock | Implemented (sequence 406) |
| Death | Always gibs and vanishes | Implemented (`vanish_on_death`) |
| Sounds | Shot `m_lasergatshoota`; servo `m_lazergatservo` (also its sight sound) | Implemented |
| Open questions | The 10 fps clip after the first turn and the yaw speed of 10 are reference quirks kept as behaviour. The track-turret design (`monster_trackattack`) is dead code | Recorded |

## Animation inventory (converted `.anim`)

`m_trakatak`: `shoota` 0–5. The reference uses no other clip.

## Verification (sequence 406)

- `runtime_player_probe.py --scenario lasergat` (e1m4a, a turret spawned in sight of the player): it turns onto the player and fires every 500 ms (21 shots). Diagnostic hits from the player stalled it 5 times; each following shot came 300 ms after the stall.
