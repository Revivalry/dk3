# Rats — review sheet

The reference files are `dlls/world/prat.cpp` (plague rat), `dlls/world/piperat.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/rats/` (`rats.zig`: reach, pain, poison tuning; `server/rats.zig`: attacks, leaps, evasion; `server/actor_rats.zig`: hooks, amphibious movement).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_plague_rat` (105, Episode 3; aidata 25 HP; punch 2 + rnd·4 or a 20% poison bite) and `monster_piperat` (129 plus 6 spawned, Episode 4; 30 HP; punch only); both amphibious | Implemented |
| Reach | Re-rolled: under 40 always; under 120 on 30% | Implemented |
| Attack | Facing: in reach `ataka` (strike 7), else a leap (`atakb` for the plague rat, `jumpa` for the pipe rat; 1.5 × run forward, 280 up) | Implemented |
| Leap | Never damages (no second sound frame on either leap clip) | Implemented (sequence 411: no leap strike) |
| Evasion | At a clip end in reach: 50% sidestep (96) or strafe (80) | Implemented |
| Water | They keep their run and walk clips in water (`swima` is never played) | Implemented (sequence 411: `swima` removed) |
| Pain | Plague rat: generic handler, two 25% rolls, limit 35. Pipe rat: one 10% roll. Neither on the acquiring hit | Implemented (sequence 411: the plague rat never flinched) |
| Death | Plague rat `diea`/`dieb` 50/50; pipe rat `diea` | Implemented |
| Open questions | The reference's per-think random melee/leap dispatch (leaps that bite by chance, a melee step freezing a leap mid-air) is not reproduced; the strafe lasts 1.1 s (shared evasion) | Open |

## Animation inventory (converted `.anim`)

`m_prat` (pipe rat at 0.8 scale shares the layout): `amba` 0–18, `ambb` 19–37, `ataka` 38–47, `atakb` 48–77, `diea` 78–97, `dieb` 98–120, `hita` 145–153, `jumpa` 164–177, `runa` 178–191, `walka` 211–237. All present.

## Verification (sequence 411)

- New `--scenario e3-creatures`: a spawned plague rat attacks and flinches with `hita`.
