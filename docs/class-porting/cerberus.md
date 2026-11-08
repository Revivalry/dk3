# Cerberus — review sheet

The reference files are `dlls/world/cerberus.cpp`, the generic AI, and the Episode 2 weapon damage path (`weapon_funcs.cpp`). Provenance only.

The native code is `src/classes/actors/cerberus/` (`cerberus.zig`: range, choice, damage admission; `server/cerberus.zig`: the shared ground combat with a class spec).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_cerberus` (e2m4e boss), model `m_cerberus`, aidata 1000 HP, run 350, FOV 215; bite 25 + rnd·25, reach 108; its death fires `dogdeath` | Implemented |
| Range | In range under 108, or under 250 on a 40% roll re-rolled at each test | Implemented (`inRange`) |
| Attack | Facing (5°): beyond 108 a leap (`jumpa`: 350 forward, 270 up at the clip's sound frame, the bite resolves at take-off); within 108 `ataka`/`atakb` 50/50 (strike frame 10) | Implemented (leap at the sound frame) |
| Damage | Of the Episode 2 weapons only the trident harms it; the Daikatana sword never does; other damage (Zeus, monsters) applies | Implemented; sequence 579 also exposes sword immunity through this class's admission hook so bot selection can honor it |
| Pain | One 10% roll (`hita`, 400 ms lock), never on the acquiring hit | Implemented (ground-combat `.roll`) |
| Death | `diea` only | Implemented |
| Open questions | Phantom bites from non-attack clips' default attack frame while it turns (reference defect, not ported) | Recorded |

## Animation inventory (converted `.anim`)

`m_cerberus`: `amba` 0–19, `ambb` 20–48, `ataka` 49–60, `atakb` 61–85, `diea` 86–101, `hita` 102–110, `jumpa` 111–131, `runa` 132–144, `walka` 166–195 (`test` unused). All present.

## Verification (sequence 410)

- Unit tests: leap admission and selection; Episode 2 damage only from the trident.
- Implemented, not yet verified in game.

## Sequence 579 — boss weapon admission

The copied Acropolis replay exposed bots firing the discus at a 750-HP Cerberus
without hurting it. Bots now query actor-owned damage admission when choosing
weapons and firing stands, rather than discovering this only after futile fire.
The class owns its refused weapon names and resolves the registry's identity
metadata; it no longer reads other weapon classes' policy modules for IDs.
Pure admission coverage includes the sword, discus, trident, Zeus and unrelated
weapons. `cerberus-slopes-25/` demonstrates an actual kill and travel to Medusa A
without a death, from the legitimate wheel checkpoint. The earlier `killed 0`
result was a separate default-radius bug and never established a boss defeat.
Continuous episode and final-module encounter acceptance remain open.
