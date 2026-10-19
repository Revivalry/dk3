# Lycanthir — review sheet

The reference files are `dlls/world/lycanthir.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/lycanthir/` (`lycanthir.zig`: choice, jump range, pain, evasion, collapse; `server/lycanthir.zig`: the shared ground combat with lycanthir hooks; `server/lycanthirs.zig`: collapse, rise and playback).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_lycanthir` (45, e3m2–e3m5), model `m_lycanthir`, aidata 200 HP, run 300; punch 15 + rnd·5, reach 80; always gibs on a real death | Implemented |
| Engage | Closes in until its jump-attack distance (160), then chooses | Implemented (sequence 411: was 1000) |
| Attack | Under 80: 60% chase attack (`atakd`) on a retreating moving enemy, else `ataka`/`atakb`/`atakc` by thirds. 80–160: 20% leap (`jumpb`, within run × 2 × 270 / 800 = 202.5), else `atakd` | Implemented (sequence 411: jump range from aidata) |
| Leap | Leaves the ground at the clip's first sound frame (forward 1.5 × run, up 270) and never damages (its row has no second sound frame) | Implemented (sequence 411: no leap strike) |
| Evasion | 20% after a claw clip, 10% after `atakd`: sidestep or strafe, at most 500 ms | Implemented (sequence 411) |
| Collapse | A kill not dealt by the player holding the Silverclaw collapses it (`diea`, health 1); it rises (`diea` reversed) after 15 / 10 / 5 s by skill, once its spot is clear; while down only the Silverclaw harms it | Implemented |
| Pain | Generic handler: two 15% rolls, `hita` on the second for 35+, the acquiring hit skips the first | Implemented (sequence 411: was one 10% roll) |
| Death | The real death howls and gibs (`dieb` without gibs) | Implemented (sequence 411: howl) |
| Open questions | The collapse does not alert nearby monsters; the chase attack does not restart when the enemy is more than 64 above or below | Open |

## Animation inventory (converted `.anim`)

`m_lycanthir`: `amba` 0–39, `ambb` 40–63, `ataka` 64–83, `atakb` 84–115, `atakc` 116–137, `atakd` 138–151, `diea` 152–167, `dieb` 168–191, `eata` 192–226 (script), `hita` 227–241, `jumpb` 287–306, `runa` 307–320, `walka` 321–340 (`hitb`, `jumpa` unused). All present.

## Verification (sequence 411)

- Unit tests: choice boundaries with the aidata jump range (202.5).
- New `--scenario e3-creatures`: a spawned lycanthir attacks and flinches with `hita`.
