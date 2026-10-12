# Fish — review sheet

The reference files are `dlls/world/goldfish.cpp`, `greyfish.cpp`, `guppyone.cpp`, `guppytwo.cpp`, `dopefish.cpp`, the swim helpers in `func2.cpp` and the blood cloud in `gib.cpp`. Provenance only.

The native code is `src/classes/actors/fish/` (`fish.zig`: aggression, turning, surfacing; `server/fishes.zig`: swimming, dopefish fight; `server/fish.zig`: hooks) and the blood cloud modules.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | Ambient `fish_goldfish`/`grayfish`/`guppy1`/`guppy2` (162 placed, wandering) and `fish_dopefish` (4; aidata 5000 HP, bite 20 + rnd·10, reach 130) | Implemented |
| Swimming | Wanders linked water nodes at twice its walk speed, re-picking after distance / walk + 1 s; steers smoothly, never banking; never rises out of the water | Implemented (sequence 412: no banking, timeout) |
| Dopefish | Its first sighting within 175 engages at once; afterwards engages within 150 on a half roll and lets go beyond 175; a bite that draws blood leaves a blood cloud | Implemented (sequence 412: first sighting) |
| Pain | Dopefish: one 75% roll, never on the acquiring hit; small fish ignore pain | Implemented (sequence 412: acquiring hit) |
| Death | Always gibs | Implemented |
| Open questions | Fish keep swimming with no player within their active distance (the reference freezes them; unseen either way); the blood cloud's extent is the attacker's box (larger than the reference's); tables follow the 1.3 profile (larger fish boxes) | Open / recorded |

## Animation inventory (converted `.anim`)

Small fish: `swima`, `diea`. Dopefish: `swima`, `atak`, `hita`, `diea`. All present.

## Verification (sequence 412)

- Implemented, not yet verified in game.
