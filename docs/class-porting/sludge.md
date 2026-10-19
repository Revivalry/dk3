# Sludge minion — review sheet

The reference files are `dlls/world/sludgeminion.cpp` and `ai_weapons.cpp`. Provenance only.

The native code is `src/classes/actors/sludge/sludge.zig` and `src/classes/actors/sludge/server/sludge.zig` with `server/sludgeminions.zig` and `server/sludge_globs.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_sludgeminion`, `m_sludgeminion`; 275 HP, run 80, FOV 215; mechanical | Implemented |
| Combat | Facing, `atakb` 20% / `ataka` 80%; left glob (10 + rnd·10) and right glob (20 + rnd·10), 900 u/s bouncing, 3 s, two touches | Implemented |
| Ammo | 5 rounds; in liquid at 0 it scoops (`ambb` 3 s passes, `getmud`), then `atakstart` fires one left glob; on dry ground firing never stops | Implemented |
| Pain | Two 5% rolls: `hita` on the first, or on the second for hits of 45 or more (else a brief stall); the acquiring hit skips the first roll only | Implemented (`actor_pain.generic`; sequence 406 corrects 405, which skipped both rolls) |
| Idle | In liquid `amba` 40% / `ambb` 60% (a cosmetic scoop); dry `amba` | Implemented |

## Animation inventory (converted `.anim`)

`m_sludgeminion`: `amba`, `ambb`, `ataka`, `atakb`, `atakstart`, `runa`, `walka`, `hita`, `diea`. All present.

Neural replacement: motion authored on the admitted anatomical rig, not fitted to the source (sequences 418–420 were rejected by the owner). Procedural idle, locomotion and death clips; since sequence 421, its left and right glob shots and pain are authored action clips (`neural_actions.py`). See [neural monsters](../neural-monsters.md).

## Verification (sequence 405)

- Unit tests: attack choice, scoop refills.
- In game: covered by existing probes.
