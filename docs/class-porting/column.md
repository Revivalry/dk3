# Column — review sheet

The reference files are `dlls/world/column.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/column/` (`column.zig`: awakening, weapon admission; `server/column.zig`: the shared ground combat with an awakening gate).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_column` (five, e2m3–e2m4c), model `m_column`, shipped aidata 200 HP, run 200, walk 100; punch 25 + rnd·10, reach 108; never gibs | Implemented |
| Dormancy | A statue frozen on `awaken`'s first frame until a visible enemy is within 256 horizontally; it then plays `awaken` | Implemented (`awaken` gate) |
| Attack | Facing (5°): within 108 `ataka` (strike frame 18), else it advances with `atakb` (strike frame 14); in range under 200 | Implemented |
| Damage | Only the hammer (or its quake) harms it; other hits are refunded | Implemented (`admitDamage`) |
| Pain | Every admitted hammer hit outside its 700 ms window plays `hita` (under 20) or `hitb` (20+), the acquiring hit too | Implemented (sequence 410: the column opts out of the acquiring skip) |
| Death | `diea` only, never gibs | Implemented |
| Open questions | The reference's awakening is cut short by its target scan, and a hammer hit on a dormant column leaves it unable to move until it attacks (both from code reading, not ported) | Recorded |

## Animation inventory (converted `.anim`)

`m_column`: `ataka` 40–69, `atakb` 70–89, `awaken` 90–108, `diea` 109–128, `hita` 150–164, `hitb` 165–179, `runa` 180–195, `walka` 196–215 (`amba`, `ambb`, `dieb` unused). All present.

## Verification (sequence 410)

- Implemented, not yet verified in game.
