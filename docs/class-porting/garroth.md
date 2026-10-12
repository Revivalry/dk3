# Garroth — review sheet

The reference files are `dlls/world/garroth.cpp`, the stave and summon weapons in `ai_weapons.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/garroth/` (`garroth.zig`: range, chooser, pain; `server/garroths.zig`: attacks, summons). His meteor is the shared meteor (`mechanics/policy/actors/meteors.zig`); his wisp is the shared wisp lightning.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_garroth` (one, e3m6a, spawned by the throne button), model `m_gharroth`, aidata 1400 HP; never gibs; deathtarget ends the episode | Implemented |
| Range | Under 200 the punch, in range below 120; otherwise in range up to 600 | Implemented |
| Chooser | Attack chance 0.30 / 0.70 / 0.85 by skill. Not facing or declined: `amba` pause. Facing under 120: `atakc` punch (hit frame 149, 50 + rnd·20). Otherwise `ataka` (fire frame 77): stave meteor, wisp or buboid summon, a third each | Implemented |
| Summon | A buboid 100 units from the enemy in the most open direction, without a deathtarget | Implemented |
| Pain | One 5% roll (`hita`), never on the acquiring hit | Implemented (sequence 411) |
| Death | `diea`/`dieb` 50/50, never gibs | Implemented |
| Gold quirk decision | The stave meteor's blast radius equals its damage (15), measured to the target's centre, so direct hits deal almost nothing and fragments nothing. Kept as Gold: the meteor is a spectacle and the punch, wisps and summons carry the fight | Decided (faithful) |
| Open questions | The cinematic's teleport names the wrong class in Gold and does nothing; native keeps that (no teleport) | Recorded |

## Animation inventory (converted `.anim`)

`m_gharroth`: `amba` 0–19, `ambb` 20–44, `ambc` 45–75, `ataka` 76–96, `atakc` 133–158, `diea` 159–179, `dieb` 180–200, `hita` 201–220, `runa` 221–233, `walka` 234–253 (`atakb` unused). All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
