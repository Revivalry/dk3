# Deathsphere — review sheet

The reference files are `dlls/world/deathsphere.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/deathsphere/deathsphere.zig` (policy: muzzles, bob, bolt look, pain chance) and `src/classes/actors/deathsphere/server/deathsphere.zig` with `server/deathspheres.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_deathsphere`, model `m_dsphere`, aidata 200 HP, run 250, FOV 180; hovers; robotic, bloodless, always gibs; bolt 5 + rnd·5 splash 96, 700 u/s, reach 512, 3 s life | Implemented |
| Cycle | Chase (`flya`) into 512 and sight; charge (`ready`, charge sound, orienting, 750 ms); attack: within 2° it loops `ataka` and fires four bolts on frame 1 and four more two frames later, then the cycle restarts | Implemented |
| Evasion | Aimed at by the player: 50% per think a dash (avoid, nearest node along world ±X, ≤250 ms); a like monster or a wall 64 ahead: sidestep 256 from the enemy (6 directions, 2 s). Not facing at attack start: it dashes | Implemented (`avoid`, `sidestep`) |
| Room height | Near the ceiling it drops 96–224; near the floor it dashes along world +X (reference angle defect, kept) | Implemented |
| Bob | 15·sin per think over 12 thinks | Implemented (`bobImpulse`) |
| Pain | No pain clip: 10% of hits (not the acquiring one) stall it for one think; its pain window is the current clip's span | Implemented (sequence 406: acquiring rule) |
| Death | Always gibs | Implemented |
| Sounds | Sight `m_dspheresightb`; charge `m_dspherechargea`; attack `m_dsphereatak`; dash steam; hover loops (`hoverf` walking, `hovera` fighting; silent until it first walks) | Implemented |
| Timing | Clips at 20 fps (`ataka` 600 ms) | Implemented (sequence 407: actor clips at 20 fps) |
| Pain restart | A pain stall restarts the interrupted task: a fresh 750 ms charge, or the attack from its first frame | Implemented (sequence 411) |

## Animation inventory (converted `.anim`)

`m_dsphere`: `amba` 0–28, `ataka` 29–40, `diea` 41, `flya` 42–55, `ready` 259–269 (`flyb`, `intera` unused). All present.

## Verification (sequence 406)

- Unit tests: bob impulses, extra volley frames.
- Implemented, not yet verified in game: the acquiring rule.
