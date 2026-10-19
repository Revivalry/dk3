# Wyndrax — review sheet

The reference files are `dlls/world/wyndrax.cpp`, `WyndraxandWispShare.h`, the wisp weapons in `ai_weapons.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/wyndrax/` (`wyndrax.zig`: ammunition, charge and phase state; `server/wyndrax_actor.zig`: phases, recharge, collection). His attack wisps and lightning are the shared wisp lightning (`mechanics/server/wisp_lightning.zig`); the clusters he drains are the shared energy swarms (`mechanics/server/energy_swarms.zig`, owned by the wisp class).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_wyndrax` (spawned in e3m4b by the spellbook sequence), model `m_wyndrax`, aidata 1200 HP; drops `weapon_wyndrax` | Implemented |
| Lightning phase | Above half health: `charged` and a zap past frame 120 (four beams, 5 within 90 per tick, at most 60); spent charge sends him to the emitter (`chargea`, beams on 84–86) | Implemented |
| Wisp phase | At or below half: `wispa` launches a homing wisp (frame 244) while ammo lasts and fewer than 10 are out; out of ammo he drains the nearest cluster (`wispb`, looping `wispc`); with 10 out he backs away | Implemented |
| Pain | One 5% roll (`hita`), never on the acquiring hit | Implemented (sequence 411) |
| Death | `diea`; his wisps fade | Implemented |
| Gold quirk decision | A cluster's last wisp can count twice (the cluster and the collect step both grant ammo). Kept: it only changes how soon he returns to combat | Decided |
| Open questions | Gold crash paths (draining with no cluster left) are guarded natively: he wanders instead | Recorded |

## Animation inventory (converted `.anim`)

`m_wyndrax`: `amba` 0–19, `chargea` 77–105, `charged` 106–130, `diea` 131–151, `hita` 152–167, `runa` 168–180, `walka` 223–242, `wispa` 243–264, `wispb` 265–272, `wispc` 273–284 (`ambb`, `ataka`, `turna`, `turnb`, `wispd` unused). All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
