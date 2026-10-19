# Nharre — review sheet

The reference files are `dlls/world/nharre.cpp`, the summon weapons in `ai_weapons.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/nharre/` (`nharre.zig`: teleport and reaper state; `server/nharres.zig`: chooser, summons, teleport; `server/nharre_retreat.zig`: repositioning; `server/nharre_reaper.zig` and `client/`: the reaper).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_nharre` (one, e3m5a), model `m_nharre`, aidata 1000 HP, run 125; drops `weapon_nightmare`; deathtarget opens the exit | Implemented |
| Chooser | Teleport when targeted (25%, 2 s cooldown); else summon on 75% past the shared cooldown (10% the reaper `atakc`, 10 s; else minions `atakb`, 1.5 s); else reposition away from the enemy | Implemented |
| Minions | Buboid, doombat or plague rat at the first clear point 96 units out (yaws 0, 45, 135, 270, 90, 315, 225, 180); flare and smoke; buboids rise from a coffin | Implemented |
| Reaper | Freezes its victim, appears after 0.5 s, strikes at frame 42 (10 fps) for 50 and a 1500 u/s push | Implemented |
| Teleport | Invulnerable fade out (0.1 per think), relocates when the point is clear, fades in; the final authored point is never chosen (Gold off-by-one, kept) | Implemented |
| Pain | Generic handler, two 1% rolls, limit 35; any hit during an attack teleports him at most once per 2 s | Implemented |
| Death | `diea`; may gib | Implemented |
| Gold quirk decision | Minions inherit his deathtarget in Gold, so the first minion death opens the exit early. Treated as a Gold bug: native minions carry no deathtarget | Decided |

## Animation inventory (converted `.anim`)

`m_nharre`: `amba` 0–19, `atakb` 20–79, `atakc` 80–138, `diea` 139–168, `hita` 169–188, `runa` 209–221, `walka` 222–241 (`hitb` unused). `we_nnreaper`: `ataka` 0–43. All present.

## Verification (sequence 411)

- Unit tests: teleport selection keeps the final-point exclusion; fade waits on an occupied point.
- Implemented, not yet verified in game.
