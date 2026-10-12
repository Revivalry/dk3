# Cambot — review sheet

The reference files are `dlls/world/cambot.cpp`, `ai_weapons.cpp` (`light_fire`, the spotlight) and the generic AI. Provenance only.

The native code is `src/classes/actors/cambot/cambot.zig` (policy: detection cone and range, follow bands, light) and `src/classes/actors/cambot/server/cambot.zig` with `server/cambots.zig`; the light is drawn by the client's cambot render class.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_cambot`, model `m_cambot`, aidata 80 HP, walk 50, run 250, FOV 215; hovers (no gravity); robotic, bloodless, always gibs; no attack | Implemented |
| Spawn | Spawnflag 2 (or `aistate pathfollow`) patrols the path corners; 16 never spots by sight (pain still alarms). Maps use 2 and 18 | Honoured |
| Patrol | `flya` at walk speed from corner to corner; it hovers at a chain end | Implemented (shared path follow) |
| Detection | A live player within its active distance, within 64 units of height and 1024 horizontally, within ±75° of its facing; three clear traces from 0.6 of its height (centre and both sides); no 256-unit rule | Implemented (sequence 406 adds the height and horizontal limits) |
| Alarm | `m_cambotalarm`; every other live monster in its sound range gets the player as its enemy when the player is within 1024 of the camera; the camera then follows | Implemented |
| Follow | Faces the player. Under 72 units horizontally it backs away (clear point, side memory); 72–192 it hovers, and when the player aims at it, 25% per think it flies to a clear point 100–250 units away; beyond 192 it flies to 72 above the player. Out of sight it chases through the air graph | Implemented (`movement`, `backAway`, `dodge`) |
| Bob and sounds | Vertical bob of 15·sin per think over 12 thinks; hover tone and control-tone chatter (35% / 70% when chasing) | Implemented |
| Light | Yellow sweep (−45°…+64° at 8° per 100 ms, 45° down, reach 600) while searching; red on the enemy | Implemented (render class) |
| Pain | Any hit alarms it; a 75% pain stall of 100 ms (no pain clip) | Alarm on a player's hit; stall not ported |
| Open questions | (1) The reference picks the nearest path corner anywhere, ignoring `target`; native follows `target`. (2) The reference's ceiling escape heads sideways (angle defect), not ported. (3) After its enemy dies the reference camera hovers forever; native resumes its patrol. (4) The alarm drags ignoring civilians into an endless chase in the reference; native gives them the enemy (workers then hide) | Decisions recorded |

## Animation inventory (converted `.anim`)

`m_cambot`: `amba` 0–28, `diea` 29, `flya` 30–31. All present.

## Verification (sequence 406)

- Unit tests: follow bands, facing cone, and the detection height and horizontal limits.
- Bridge scenario (e1m1b) keeps its cambots patrolling (`path=`), regression only.
