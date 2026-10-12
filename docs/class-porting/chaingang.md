# Chaingang — review sheet

The reference files are `dlls/world/chaingang.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/chaingang/` (`chaingang.zig`: strafe, burst counter, phases; `server/chaingangs.zig`: flight, landing, takeoff, bursts; `server/chaingang.zig`: hooks).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_chaingang` (31, Episode 4), jetpack chaingunner, aidata 150 HP; chaingun 1 per bullet, reach 350, six bullets per fire call | Implemented |
| Start | Hovers if spawned over 100 above the floor, else walks; its AI starts about 2.2 s after spawning | Implemented (sequence 411: start-up delay) |
| Flight | Hovering it orbits 384 from its enemy, re-picking one of six strafe directions every 1.5–4 s, 25% swoops; lands where its enemy's room is under 250, takes off where both rooms exceed 350 (55% per think) | Implemented |
| Landing | Flies to a ground node; an approach that runs out of time lands in place; it holds its flight clip's last frame on the way | Implemented (sequence 411) |
| Bursts | Wind-up (`transb`/`transd`), then `atakf` (air) or `ataka` (ground): 15 fire calls per 2.3 s; a ground burst is followed by a dodge | Implemented |
| Pain | One 75% roll (`hita`), never on the acquiring hit; a takeoff or landing under way carries on | Implemented (sequence 411) |
| Death | `diea` 2/3, `diec` 1/3; in flight it falls at twice gravity | Implemented (sequence 411: gravity) |
| Takeoff and landing | A small blast above it and four smoke puffs (±15) as its jets fire; four smaller puffs (±7) as it settles | Implemented (sequence 411) |
| Reach | A burst ending with its enemy beyond the gun's reach (350) chases again; its orbit (384) lies just outside, so it closes in and backs off | Implemented (sequence 411) |

## Animation inventory (converted `.anim`)

`m_chgang`: `amba` 0–20, `ambb`–`ambe` 21–125, `ataka` 126–146, `atakf` 181–200, `diea` 201–221, `diec` 243–263, `flya` 264–303, `flyb` 304–328, `flyc` 329–359, `hita` 360–369, `runa` 430–442, `transb` 460–473, `transd` 494–504, `walka` 505–524. All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
