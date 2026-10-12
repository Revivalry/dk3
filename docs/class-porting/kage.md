# Kage and his ghosts — review sheet

The reference files are `dlls/world/kage.cpp`, its ghost code and the generic AI. Provenance only.

The native code is `src/classes/actors/kage/` (`kage.zig`: skill tables, recharge, refund, smoke, shield; `server/kages.zig`: fight, smoke escape, protector ring, charge; `server/kage.zig`: hooks) and `src/classes/actors/ghost/` (the protector ghosts). Skill tiers come from the shared `difficulty` module.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_kage`, Episode 4's boss, spawned in e4m6c by `kagespawn` after the mid cinematic; aidata 1200 HP; slice reach 90; death fires `mid_cine2` and takes the Daikatana from the player | Implemented |
| Skill | Recharges 2/5/10, escapes 2/4/8, recharge below 25/50/75% of base health (Ronin / Samurai / Shogun) | Implemented (sequence 412: Samurai had Shogun's tables) |
| Slice | Facing: `ataka`/`atakb`/`atakc` a third each; a hit leaves the target at 1 health while it has more | Implemented |
| Smoke escape | Targeted: 30% roll every 5 s while escapes remain: smoke, vanish 5–9 s, reappear by the enemy (within 64 height, nearest node), fade in; invulnerable meanwhile | Implemented |
| Recharge | Below the threshold: twelve protector ghosts in a ring (one every 0.65 s), then health climbs 1/5/10 every 2/1.5/1 s; damage while charging is refunded | Implemented |
| Shield | For 15 / 7.5 / 4.5 s after each recharge damage is turned away (the reference's megashield timer) | Implemented (sequence 412) |
| Ghosts | Wake (alpha to 0.4), fly at the enemy, one 1–4 strike, fade; leave the attack beyond their weapon's reach (90); calls at 0.95 volume, 512–1024 | Implemented (sequence 412: reach, call levels) |
| Pain | One 2% roll | Implemented |
| Decisions | A lethal hit while charging is refunded once (Gold refunds twice: die and pain hooks); ghosts that would spawn inside walls are skipped but counted; a ghost at exactly 0 health fades | Decided |
| Open questions | The hum plays at full volume (the reference: 0.65) | Open |

## Animation inventory (converted `.anim`)

`m_kage`: `amba`, `ataka`, `atakb`, `atakc`, `atake`, `hita`, `diea`, `runa`, `walka`, `jump`; `we_kage` (ghost): `amba`, `ataka`, `flya`. All present.

## Verification (sequence 412)

- `--scenario kage`: attacks, summons protector ghosts below his threshold, refunds damage while recharging (100 → 265 on a 40 hit).
- Smoke escape and the post-recharge shield: implemented, not yet verified in game.
