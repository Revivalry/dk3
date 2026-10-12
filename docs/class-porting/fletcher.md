# Fletcher — review sheet

The reference files are `dlls/world/fletcher.cpp` and the generic AI. Provenance only.

The native code is the archers class (`src/classes/actors/archers/`: the fletcher shares one policy with the centurion): `archers.zig` (choice, pain, death side, shaft styles) and `server/archers.zig`; its arrow is a shared shaft (`mechanics/policy/actors/shafts.zig`, magic touch).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_fletcher` (40, e3m2–e3m6), model `m_fletcher`, aidata 150 HP, walk 45, FOV 170; magic arrow 10 + rnd·20 at 950 u/s, reach 1000; one in e3m4b drops `ammo_bolts` | Implemented |
| Attack | When targeted, 30% evasive action at attack start and clip ends; otherwise `ataka` under 400 (fire 26), `atakb` beyond (fire 30), standing still | Implemented |
| Arrow | Red glowing bolt, 10 s life, removed on contact (impact sound on the world) | Implemented (shaft `magic` touch) |
| Pain | Generic handler: two 20% rolls, `hita` on the second for 25+, the acquiring hit skips the first | Implemented (sequence 410) |
| Death | Facing its killer's inflictor `diea`, otherwise `dieb` | Implemented (sequence 410) |
| Open questions | The per-think projectile check that sidesteps a blocked shot is not ported; take cover (512) and snipe (32) are used by no map; its pain sound is knight1's file (kept) | Open |

## Animation inventory (converted `.anim`)

`m_fletcher`: `amba` 0–39, `ambb` 40–79, `ataka` 80–114, `atakb` 115–154, `diea` 155–175, `dieb` 176–196, `hita` 197–212, `runa` 243–258, `walka` 259–278 (`hitb` unused). All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
