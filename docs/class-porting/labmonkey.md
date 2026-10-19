# Lab monkey — review sheet

The reference files are `dlls/world/labmonkey.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/labmonkey/` (`labmonkey.zig`: bands, reach, hops; `server/labmonkey.zig`: the shared ground combat with monkey hooks, `use` wake).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_labmonkey` (30, e4m4–e4m5), model `m_labmonkey`, aidata 150 HP; punch 10 + rnd·20, reach 70 | Implemented |
| Reach | Within 70 always; within 250 on a re-rolled half; it keeps closing in until a roll passes | Implemented (sequence 411: punch reach, closing in) |
| Attack | Beyond 108 a leap (`atakc`/`atakd`, 1.5 × run, 270 up); 56–108 `ataka`/`atake`; closer `atakb`; after a clip it hops aside (75% / 50%) | Implemented |
| Strikes | Led at the enemy and landing without facing; a landed strike plays `global/m_punchg` | Implemented (sequence 411) |
| Wake | Spawnflag 16 monkeys wait in their crates until used or hurt | Implemented |
| Pain | Generic handler, 20% rolls, limit 35 | Implemented |
| Death | `diea` | Implemented |
| Open questions | The e4m4c monkey targeted by `monkeyhurt1` has no matching trigger (Gold: dormant until hurt; kept) | Recorded |

## Animation inventory (converted `.anim`)

`m_labmonkey`: `amba` 0–29, `ambb` 30–64, `ambc` 65–89, `ataka` 126–146, `atakb` 147–171, `atakc` 172–196, `atakd` 197–216, `atake` 217–246, `diea` 247–266, `hita` 296–315, `runa` 353–365, `walka` 366–385. All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
