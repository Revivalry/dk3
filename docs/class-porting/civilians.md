# Civilians (workers and plain prisoners) — review sheet

The reference files are `dlls/world/skinnyworker.cpp`, `fatworker.cpp`, `PRISONER.CPP` and the
generic AI in `ai_func.cpp`, `ai_think.cpp`, `AI_File.cpp`, `Sidekick.cpp` (hide-node search) and
`action.cpp` (scripts). They are provenance only.

The native code is `src/classes/actors/civilians/civilians.zig` (policy and per-classname roles),
`src/classes/actors/civilians/workers.zig` (fear state, voices, timings) and
`src/classes/actors/civilians/server/civilians.zig` (adapter: `routes`, `loadAnimations`,
`perceive`, `prepare`, `move`, `playback`, `scriptable`/`follows`, `diagnose`, `mustGib`). Wander,
fleeing and spawnflags are shared mechanisms (`common.roam`/`common.moveRoaming`,
`common.moveFleeing`, `src/mechanics/policy/actors/spawnflags.zig`). The armed black and white prisoners are a
separate class (`prisoners`), reviewed at the end.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_skinnyworker` (`m_mwskny`), `monster_fatworker` (`m_mwfaty`), `monster_prisoner` (`m_priza`), `monster_prisonerb` (`m_prizb`); actor kind `.civilian`; each classname has a role (skinny worker, fat worker, prisoner) | Implemented (`civilians.roleOf`) |
| Spawn | Spawnflags 1/4 node wander, 2 path follow, 16 ignore player, 128 do-not-move, 1024 always gib. No class-specific bits (`PRISONER_WANDER`, `SKINNYWORKER_HIDE` are goal names). Keys: `default_aiscript` (work loop), `uniqueid`, `sight`, `speak`. `aiscript` is not read on monsters. `monster_spawnprisoner` is unreachable (no export, no caller) | Honoured: 1, 2, 4, 16, 128. `default_aiscript` runs the work loop (sequence 388) |
| Work loop | `default_aiscript` loops script animations (clipboard `eambd`, pockets `famba`, typing `bamba`/`tamba`, kneeling `camba`, seated `samba`). When a goal stack empties, the spawnflag goals and the default script come back, so a worker returns to work after a scare | Implemented by the shared script runner: fleeing and cowering pause the script (`pausesScript`, `scriptable`), which resumes when the worker calms down |
| Sight (workers) | Every 300 ms, when not in a script, not ignoring the player, a visible client (FOV 220 or within 256 units, clear trace) makes the worker hide: run away (10 s limit) to the farthest node from the enemy, then cower. A working worker never sees the player | Implemented: `perceive` acquires through `actor_perception`, looking from 16 units above the origin (a seated worker's origin is inside his chair); the step skips perception while a script acts, so working workers are blind |
| Pain (skinny) | Clears ignore-player, alerts others, runs away node to node from the enemy (`runa`), then cowers. With do-not-move: cowers at once | Implemented (`panic`, the shared flee; immobile workers cower at once) |
| Pain (fat) | Alerts only (no run-away); the next sight scan makes him hide | Implemented: the attacker becomes his threat; a visible threat starts the hide |
| Witness | `AI_EnemyAlert`: monsters within the alerter's speak radius (active distance × 0.15: 150 for workers, 300 for prisoners) with line of sight get the enemy | Implemented as witnessing a visible injury or death within `witness_range`, now the reference speak radius |
| Cower (skinny) | 50/50 looping `gamba` (1000 ms) or `gambc` (400 ms), not facing the enemy, no time limit. After 10 s: enemy within 300 units in sight → run again; enemy beyond the active distance → calm | Implemented (`workers.State`) |
| Cower (fat) | No cower hooks: the generic cower turns into a wander (walking), the hide restarts, a hide → wander cycle | Decision: the fat worker wanders (walking, shared roam) for his cower period, then calms down |
| Prisoners | Never notice the player by sight. When hit (or alerted): sight sound (`sighta` 50%, `b`/`c` 25%), then endless node wander (`walka`, walk speed). Never flee or cower | Implemented: alerted prisoners roam; sight sounds play (`actor_audio` no longer silences bystanders) |
| Idle | `amba` (workers 100%: no weights); prisoners `amba` 80 / `ambb` 10 / `ambc` 10 with chatter sounds (sound2 2–5%, 10–40 s cooldown) | Implemented (`actor_audio` ambient choices) |
| Animation | Run `runa`, walk `walka`, death `diea` only; no `hit*` clips | Implemented |
| Voices | Hide: 50% silent; skinny `Man_snifs` 12.5%, `skinnydeath` 15%, `skinnydeath2` 22.5%; fat `Man_snifs` 35%, `skinnydeath` 15% | Implemented (`workers.voice`) |
| Death | Generic `diea`; the fat worker always gibs | Implemented (`mustGib`) |
| Skill | Aidata multiplier only | Implemented (aidata parse) |
| Persistence | Fear phase, start, retry deadline, cower variant; roam home, leg and deadline | `workers.State` and the shared `roam` field, with `rebase`/`validate` |
| Open questions | (1) A skinny worker's cower that ends by distance walks to the world origin in the reference (an uninitialised return point); native: he calms where he stands and his work script resumes. (2) The skinny worker's restart within 300 units is a no-op on top of a work script in the reference; native restarts the run either way. (3) The fat worker's hide/wander cycle is derived from code reading; native wanders for one cower period | Decisions recorded |

## Animation inventory (converted `.anim`)

| Model | Clips used |
|---|---|
| `m_mwskny` | `amba` 59–72, `runa` 780–793, `walka` 983–1002, `gamba` 692–711, `gambc` 720–727, `diea` 325–341, work clips `eambd`, `famba`, `camba`, `samba`, `walke` |
| `m_mwfaty` | `amba` 50–69, `runa` 491–502, `walka` 775–792, `diea` 361–390, work clips `tamba`, `samba`, `camba` |
| `m_priza` | `amba` 41–80, `ambb`, `ambc`, `runa` 182–197, `walka` 260–279, `diea` 161–181, `samba` |
| `m_prizb` | `amba` 33–62, `ambb`, `ambc`, `runa` 169–184, `walka` 276–295, `diea` 149–168, `samba` |

Every clip the sheet needs is present.

Neural replacement: motion authored on the admitted anatomical rig, not fitted to the source (sequences 418–420 were rejected by the owner). Procedural idle, locomotion and death clips; since sequence 421, the workers' cowers, clipboard, pockets, console, floor, seated and stool work and gestures are authored action clips (`neural_actions.py`). See [neural monsters](../neural-monsters.md).

## Armed prisoners (`monster_blackprisoner`, `monster_whiteprisoner`)

Reference: `blackpris.cpp`, `whitepris.cpp`. Aidata replaces the class code's values (135 HP, run
240, walk 60, attack distance 64). In range at ≤ 64 units, or between 350 and 500 with a 10% roll
per think; melee (`ataka`/`atakb`/`atakc`, a third each) below 207 units, else a rock (`atakd`,
ballistic, flight time = distance / 600, 3 s life). Pain: chance 10 (black) / 20 (white), and a
second roll for damage ≥ 35 / 40; death `diea` for damage < 20 or 30%, else `dieb`. The native
`prisoners` policy and adapter already implement these (`inRange`, `select`, `die`).

## Verification (sequence 404)

- Policy test: the roles follow the reference classes.
- `runtime_player_probe.py --scenario workers` (e1m3a): worker 25 sees the player, plays a hide
  voice, runs (`runa` 780–793) and cowers (`gambc` 720–727); prisoner 462, hurt by the player
  (diagnostic damage), walks node legs with `walka` 260–279 and never flees; do-not-move
  prisoner 318 is alerted in place. 462 is caged until the level's script opens his cell, so his
  legs stay blocked.
- `--scenario worker-wander` (e1m2b): spawnflag-4 worker 51 walks node to node with `walka`.
- Headless sampling: fat worker 9 (e1m2a) hides, wanders through his cower, then hides again
  while the player stays close; working worker 145 (e1m3a, `WRKRfreddo`) ignores the player
  beside him.
- Open: the probe's attack input does not fire the player's weapon (every build; the combat,
  status-weapons and civilians scenarios fail on it) (cause: a spawned player's command clock starts at the server's time, about 800 ms ahead of the slow headless client's command stamps, so early or brief presses are dropped as stale; held after the client catches up, the Glock fires. In play the gap is a frame or two), so pain is staged with
  `dk3_runtime_hurt`.
