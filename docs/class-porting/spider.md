# Spider and small spider — review sheet

The reference files are `dlls/world/spider.cpp`, `smallspider.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/spider/` (`spider.zig`: range, run-away, pain; `server/spider.zig`, `server/spiders.zig`). Both classnames share one policy and the reference's actor type.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_spider` (150 HP, run 300, bite 10 + rnd·5, reach 80) and `monster_smallspider` (35 HP, run 250, render scale 0.2, bite 2 + rnd·2, reach 40); FOV 315 | Implemented |
| Attack | Within reach `ataka` at twice the clip rate (frame increment 2): a bite about every 500 ms; from further away (an attack restarted out of reach) `jumpa`: a leap at 1.5 × run speed, 270 up (200 for the small spider) at the clip's sound frame | Implemented (bite at twice the 20 fps rate) |
| Small spider | 50% after a bite: a 52-unit sidestep. Hurt (not by the acquiring hit): it runs away (first leg 2–7 s) after any flinch | Implemented (sequence 410: no run-away on the acquiring hit) |
| Pain | One 75% roll (`hita`, 950 ms lock), never on the acquiring hit | Implemented (sequence 410) |
| Activation | The e2m4b "hate" swarm (spawnflag 16) stops ignoring the player when its trigger uses it | Implemented (sequence 410: `use`) |
| Death | `diea` only | Implemented |
| Open questions | Run-aways stack without a cap in the reference; native keeps one | Decision recorded |

## Animation inventory (converted `.anim`)

`m_spider`: `amba` 0–19, `ambb` 20–39, `ataka` 40–59, `diea` 60–80, `hita` 81–100, `jumpa` 101–118, `runa` 119–128, `walka` 129–148. `m_sspid`: `amba` 0–19, `ambb` 20–39, `ataka` 40–59, `diea` 60–80, `hita` 102–121, `jumpa` 122–146, `runa` 147–156, `walka` 157–176 (`dieb` unused). All present.

## Verification (sequence 410)

- Implemented, not yet verified in game.
