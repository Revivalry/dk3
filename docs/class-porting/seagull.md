# Seagull — review sheet

The reference file is `dlls/world/seagull.cpp` and the flight helpers in `func2.cpp`. Provenance only.

The native code is `src/classes/actors/seagull/` (`seagull.zig`: bob; `server/seagulls.zig`: flight; `server/seagull.zig`: hooks). Its obstruction probes are the shared `actor_flight.avoid` (also the doombat's).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `e_seagull` (8, Episode 2 coast maps), ambient, on authored corner paths, no attack, always gibs | Implemented |
| Flight | Follows its path at twice its walk speed (150), smooth turn 0.01, banking; bobs through ten impulses per cycle | Implemented |
| Obstructions | Four probes ahead; striking anything but a door or train pushes it back at half speed | Implemented (sequence 412: shared probes) |
| Open questions | Native routes between corners through air nodes (the reference flies straight) | Recorded |

## Animation inventory (converted `.anim`)

`e_seagull`: `flya`, `diea`, `stand` (`flyb` unused). All present.

## Verification (sequence 412)

- Implemented, not yet verified in game.
