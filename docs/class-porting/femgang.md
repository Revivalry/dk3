# Femgang — review sheet

The reference files are `dlls/world/femgang.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/femgang/` (`femgang.zig`: choice, reach, evasion; `server/femgang.zig`: the shared ground combat with femgang hooks).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_femgang` (9, e4m3), model `m_femgang`, aidata 150 HP, run 350; punch 5 + rnd·15, reach 80 | Implemented |
| Attack | In reach (under 200), facing: under 80 `ataka` slash, else the `atakb` lunge at attack speed | Implemented |
| Evasion | Targeted, half the time she sidesteps or strafes for at most 0.5 s instead | Implemented (sequence 411: 0.5 s) |
| Hit sound | A landed strike plays `global/m_knifehita` | Implemented (sequence 411: shared melee hit sound) |
| Pain | Generic handler, 20% rolls, limit 35 | Implemented |
| Death | `diea`/`dieb` 50/50 | Implemented |

## Animation inventory (converted `.anim`)

`m_femgang`: `amba` 0–40, `ambb` 41–61, `ataka` 62–87, `atakb` 88–102, `diea` 103–121, `dieb` 122–142, `hita` 143–158, `runa` 175–190, `walka` 191–210 (`hitb` unused). All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
