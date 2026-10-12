# Griffon — review sheet

The reference files are `dlls/world/griffon.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/griffon/` (`griffon.zig`; `server/griffons.zig`: flight, landing, jump, attacks, pain).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_griffon` (15, Episode 2), model `m_griffon`, aidata 350 HP, run 250, FOV 215; punch 15 + rnd·10, reach 100; always gibs | Implemented |
| Flight | Chases airborne (`flya`, curved flight, 1.15 × run, 90 above its enemy); stuck or over water it flies away to a free node | Implemented |
| Landing | In a low room (≤ 250) with ground within 700: flies to the nearest ground node, `drop`, then walks; it takes off again when it disengages | Implemented |
| Ground | Walking: a 25% leap per think between 150 and 300 (1.65 × run, 297 up; 15 damage on landing within 150) | Implemented |
| Attack | Within 135: flying `atakd` (strike frame 8, no braking; after a strike it lands if it can); walking `ataka` or `atakb` 50/50 | Implemented |
| Pain | Its own 15% flinch (`hita` flying, `hitb` walking) shown only until the next think; else the shared 10% roll (`hita`), never on the acquiring hit | Implemented (sequence 410: short flinch, acquiring rule) |
| Death | Always gibs | Implemented |

## Animation inventory (converted `.anim`)

`m_griffon`: `amba` 0–18, `ataka` 19–42, `atakb` 43–82, `atakd` 103–121, `diea` 122–142, `drop` 143–161, `flya` 162–180, `hita` 220–237, `hitb` 238–251, `jumpa` 272–297, `runa` 298–309, `walka` 310–332 (`atakc`, `flyb`, `flyc`, `hovera` unused). All present.

## Verification (sequence 410)

- Implemented, not yet verified in game.
