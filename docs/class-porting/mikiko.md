# Mikiko (monster form) — review sheet

The reference files are `dlls/world/mikiko_monster.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/mikiko/` (`mikiko.zig`: swing sounds and volume; `server/mikiko_actor.zig`: fight, aura, dodge; `server/mikiko.zig`: hooks, ambient loop, aura projection; `client/sword_aura.zig`). The sidekick Mikiko is the companions class.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_mikiko`, model `m_smikiko`, aidata 500 HP, run 400; sword 50 + rnd·10, reach 90. Spawned only in e4m6c by the closing cinematic's button; her death ends the game (`end_wait`) | Implemented |
| Engage | Chases until within her sword's reach (90) and in sight | Implemented (sequence 411: was the aidata attack distance, 100) |
| Attack | Facing: `ataka`, `atakb` or `atakc`, a third each; one strike on each clip's second frame (the table's misaligned columns) | Implemented |
| Dodge | When targeted, half the time each think she dodges, also while turning to face | Implemented (sequence 411: while turning) |
| Aura | The first time she sees her enemy her sword glows (one-shot) with a dark light, and the Daikatana hum loops until she dies; the glow lasts through her death clip | Implemented (sequence 411: through the death clip) |
| Sounds | Swing whooshes and jumps at 0.75 volume on authored frames; no pain or sight sounds | Implemented (sequence 411: volume) |
| Pain | Generic handler, two 10% rolls, limit 35; the acquiring hit skips the first | Implemented |
| Death | Always `diea` (`dieb` is absent from the model), `mikiko/death2` | Implemented |
| Open questions | The ambient hum plays at full volume (the reference: 0.7); the unreferenced `e4/m_mikiko` table (pain, laugh) stays unused as in Gold | Open / recorded |

## Animation inventory (converted `.anim`)

`m_smikiko`: `amba` 0–29, `ataka` 30–49, `atakb` 50–66, `atakc` 67–86, `diea` 87–111, `hita` 112–121, `runa` 122–133, `walka` 134–153. All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
