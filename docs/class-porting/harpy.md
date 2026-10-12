# Harpy — review sheet

The reference files are `dlls/world/harpy.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/harpy/` (`harpy.zig`: attacks, shaft style; `server/harpies.zig`); its magic arrow is a shared shaft (`magic` touch).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_harpy` (52, Episode 2), model `m_harpy`, aidata 170 HP, FOV 215; magic arrow 10 + rnd·10 at 600 u/s, reach 1000; always gibs | Implemented |
| Modes | Flying; lands (`drop` forward to frame 209) where its enemy's room is under 250 high; takes off (`drop` reversed to 191, climbing 275 u/s) where both rooms are over 350 | Implemented |
| Attack | Within 1000 and in sight: hovers in place, `atakb` flying / `ataka` walking (arrow on frames 132 / 84); a live monster in the line makes it dodge | Implemented |
| Arrow | Glowing red bolt, 10 s flight, vanishes on contact (impact sound on the world) | Implemented (shaft `magic` touch) |
| Pain | Generic two 10% rolls, limit 25; the acquiring hit skips the first | Implemented |
| Death | Always gibs | Implemented |
| Open questions | The reference's hovering `flya` also fires on its default attack frame (about doubling the fire rate) | Open: not verified natively |

## Animation inventory (converted `.anim`)

`m_harpy`: `amba` 0–29, `ambb` 30–69, `ataka` 70–110, `atakb` 111–149, `diea` 150–178, `drop` 179–214, `flya` 215–234, `hita` 235–250, `runa` 307–321, `walka` 322–341 (`hitb`, `jumpa`, `jumpb` unused). All present.

## Verification (sequence 410)

- Implemented, not yet verified in game.
