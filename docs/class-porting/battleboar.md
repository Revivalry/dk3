# Battleboar — review sheet

The reference files are `dlls/world/battleboar.cpp` and the generic AI (`ai_func.cpp`, `ai_think.cpp`, `ai_weapons.cpp`, `ai_aim.cpp`). Provenance only.

The native code is `src/classes/actors/battleboar/battleboar.zig` (policy: weapon choice, hit clips, pain) and `src/classes/actors/battleboar/server/battleboar.zig` with `server/battleboars.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_battleboar`, model `m_bboar`, aidata 250 HP, run 250, FOV 180; wheeled; robotic, bloodless; guns (4 per bullet, reach 600) and rocket (20 + rnd·10 splash 128, 550 u/s, reach 1000, 5 s life) | Implemented |
| Combat | Faces within 10° to choose: within 120 `ataka` (guns, one bullet on frame 5), beyond 120 `atakb` (rocket on frame 7) 85% else guns. Fires only with a clear shot (the first thing hit is its live enemy) and within 5°; a fire frame passed while not facing is lost. Engage range follows the last weapon (starts 1000). The next clip starts at once | Implemented (`select`, `clearShot`) |
| Muzzle flash | Two flashes toggling every 50 ms over frames 92–96 of `ataka` | Implemented (`decorate`) |
| Pain | Its single roll stops it with `hita` 25% of the time (not on the acquiring hit); otherwise every hit outside its pain window plays `hita`/`hitc`/`hitb` (a third each) while it keeps chasing or attacking | Implemented (sequence 406; it used to freeze for every hit clip) |
| Death | `diea` or `dieb` 50/50 | Implemented (`deathCoin`) |
| Timing | Clips at 20 fps (guns 800 ms, rocket 1200 ms) | Implemented (sequence 407: actor clips at 20 fps) |
| Open questions | A flag-subtraction defect gives it berserk retargeting against monsters that hit it; `rev` is never visible (overwritten at once); hit clips can fire its weapon on their default attack frame. None is ported | Decisions recorded |

## Animation inventory (converted `.anim`)

`m_bboar`: `amba` 0–19, `ambb` 20–39, `ambc` 40–84, `ataka` 85–101, `atakb` 102–126, `diea` 127–148, `dieb` 149–162, `hita` 163–177, `hitb` 178–199, `hitc` 200–214, `rev` 215–227, `runa` 228–252. All present.

## Verification (sequence 406)

- Unit tests: weapon choice at the 120-unit boundary; hit clips in thirds.
- Implemented, not yet verified in game: the pain rework.
