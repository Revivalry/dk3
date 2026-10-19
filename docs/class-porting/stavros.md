# Stavros — review sheet

The reference files are `dlls/world/stavros.cpp`, the stave weapon in `ai_weapons.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/stavros/` (`stavros.zig`: pain, tuning; `server/stavros_actor.zig`: fight). His meteor is the shared meteor (`mechanics/policy/actors/meteors.zig`).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_stavros`, aidata 800 HP, scale 1.625; stave meteor 80 over 80 units, reach 800. No shipped map places him (cut content; spawnable for tests) | Implemented |
| Attack | Within 800 and facing (yaw within 5°; pitch does not count within reach): `ataka`, the meteor on frame 26; an unfaced strike frame is lost | Implemented (sequence 412: yaw-only facing, lost strike) |
| Meteor | Grows from 0.2 scale while accelerating (to about 600 u/s), 12 s life, torch loop; bursts into 4–6 fragments that do no damage | Implemented |
| Ring of fire | A held ring of fire quarters his meteor's damage | Implemented (sequence 412: actor blasts carry their class) |
| Pain | Generic handler, two 1% rolls, limit 35 | Implemented |
| Death | `diea` | Implemented |

## Animation inventory (converted `.anim`)

`m_stavros`: `amba`, `ataka`, `hita`, `diea`, `walka` (also his chase clip). All present.

## Verification (sequence 412)

- Implemented, not yet verified in game.
