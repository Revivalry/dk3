# Centurion — review sheet

The reference files are `dlls/world/centurion.cpp` and the generic AI. Provenance only.

The native code is the archers class (`src/classes/actors/archers/`: the centurion and the fletcher share one policy): `archers.zig` (choice, reach, pain, shaft styles) and `server/archers.zig`; its spear is a shared shaft (`mechanics/policy/actors/shafts.zig`, knife touch).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_centurion`, model `m_centurion`, aidata 200 HP, run 250, FOV 170; spear 10 + rnd·10 at 1000 u/s, reach 700; punch 7 + rnd·15, reach 90 | Implemented |
| Spawn | 88 placed (e2m3–e2m5), two spawned in e2m5e with wander; spawnflag 512 has no effect | Honoured (shared spawnflags) |
| Engage range | The current weapon's reach: it starts with the punch (90), so the first engagement closes to melee; after it throws a spear the reach is 700 | Implemented (sequence 408: `reach`) |
| Attack | Facing (5°): under 90 `ataka` (punch on frame 9), else `atakb` (spear on frame 7, clear-shot check or sidestep); 750 ms after a throw before the next; an unfaced release is lost; when targeted, 25% evasive action at attack start and clip ends | Implemented |
| Spear | Sticks in the world (armour clank) or drops off its victim; 3 s flight, fades 4–5 s after impact | Implemented (shaft `knife` touch) |
| Pain | One 30% roll (`hita`, 750 ms lock), no damage threshold, never on the acquiring hit | Implemented (sequence 408) |
| Death | `diea` only | Implemented |
| Open questions | Its targeting test for non-client enemies checks its own facing (reference defect, not ported) | Recorded |

## Animation inventory (converted `.anim`)

`m_centurion`: `amba` 0–29, `ataka` 30–45, `atakb` 46–60, `diea` 61–85, `hita` 86–101, `runa` 136–151, `walka` 152–171 (`jumpa`/`jumpb` unused). All present.

## Verification (sequence 410)

- Unit tests: melee/far boundaries; reach follows the last weapon.
- Implemented, not yet verified in game.
