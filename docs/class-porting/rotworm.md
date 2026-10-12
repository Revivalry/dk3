# Rotworm — review sheet

The reference files are `dlls/world/rotworm.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/rotworm/` (`rotworm.zig`: choice, pain, spit style; `server/rotworms.zig`: ceiling, attacks, pain). Its spit is the shared venom spit.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_rotworm` (67, e3m1–e3m5), model `m_rotworm`, aidata 25 HP; bite 2 + rnd·10, reach 40, poisons; spit 2 + rnd·10 at 400 u/s, reach 300, poisons players | Implemented |
| Ceiling | Spawnflag 2048: hangs upside down 11 below the ceiling, scanning; drops when it acquires an enemy | Implemented; native also drops when shot (the reference's hanging worm never drops after being shot) |
| Attack | Chases until its enemy is within the spit's reach (300); then under 60 or on 25% it bites (`ataka`, strike 13), otherwise spits (`atakc`, fire 5); no facing check | Implemented (sequence 411: reach bound) |
| Leap | The reference's jump attack starts no flight (it only re-plans the attack): no leap | Implemented (sequence 411: the leap removed) |
| Pain | One 75% roll (`hita`), never on the acquiring hit | Implemented (sequence 411: was missing) |
| Death | `diea`; a hanging worm's pitch is reset (native) | Implemented |

## Animation inventory (converted `.anim`)

`m_rotworm`: `amba` 0–28, `ataka` 29–48, `atakb` 49–67 (loaded for saved poses only), `atakc` 68–81, `diea` 82–102, `hita` 103–117, `runa` 118–130, `walka` 131–150. All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
