# Mishima guard — review sheet

The reference files are `dlls/world/mishimaguard.cpp` and the generic AI in `ai_func.cpp`,
`ai_aim.cpp`, `ai_weapons.cpp`, `AI_File.cpp` and `Nodelist.cpp`. They are provenance only.

The native code is `src/classes/actors/mishima_guard/mishima_guard.zig` (policy) and
`src/classes/actors/mishima_guard/server/mishima_guard.zig` (adapter: `attacks`, `routes`,
`loadAnimations`, `spawn`, `think`, `move`, `playback` and `diagnose`). Cover, wander, side-steps
and spawnflags are shared mechanisms the adapter composes: `src/mechanics/policy/actors/cover.zig` with
`server/actor_cover.zig`, `src/mechanics/policy/actors/wander.zig` with `server/actor_wander.zig`,
`server/actor_evasion.zig`, and `src/mechanics/policy/actors/spawnflags.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_mishimaguard`; model `m_mwguard`; aidata row; actor kind `.mishima_guard` | Implemented |
| Spawn | Spawnflags: 1 wander, 2 path follow, 4 node wander, 8 random wander, 16 ignore player, 128 do-not-move, 512 take cover. 51 E1 guards carry 512, 20 carry 1, 14 carry 128 | 1, 2, 4, 16, 128 and 512 honoured. 8 is not: the reference random-wander goal reads a follower's owner, which monsters lack, so its monster behaviour is undefined |
| Idle | `AI_SelectAmbientAnimation` plays `amba`/`ambb`/`ambc` with weights 90/5/5 | Implemented (`actor_audio` ambient cycling) |
| Chase | Runs to the enemy with `runa`. Guards with 512 never chase; guards with 128 never move | Implemented |
| Attack | `ataka`/`atakb`/`atakc`. A new clip is chosen every 4 shots (`rand() % 3`). It fires only while facing the enemy (yaw turns at `ang_speed`) with a clear shot. The next shot comes 0.2 s plus a random 0–1 s later. Between shots the guard faces the enemy and the last attack clip holds | Implemented, including holding the pose between shots (adapter `think` and `playback`). The yaw snaps instantly (gap) |
| Reload | Eight rounds, then `reload` with the `i_scammo` sound | Implemented |
| Pain | `ai_generic_pain_handler(limit 35)` with the default 75% chance: `hita` when the damage is 35 or more | Implemented in the adapter; the constants are in the policy |
| Sidestep | When the shot is blocked at the fire frame (`ai_check_projectile_attack` fails), push SIDESTEP: 52 units across its facing (96 − 44), the other side if blocked, ground required, `runa`, 2 s limit; then the goal restarts | Implemented: the cycle reports `blocked`, the adapter calls the shared `actor_evasion.sidestep`. Never with 128 |
| Take cover | With spawnflag 512 (AI_TakeCover, AI_MishimaguardTakeCoverAttack): shoot `ataka` once while the enemy is completely visible (sight lines from both shoulders at 0.4 height, ±0.6 × width), 2 s cooldown, no rounds or reload. Otherwise, every 4 s with 50% chance, run back out toward the enemy (look). Otherwise, while the enemy can see it, run (`runa`) to the closest hide node (flag 0x1000) within 768 units hidden from the enemy's centre and both shoulder lines and reachable; ambient there. No hide node: stand and fight | Implemented. Native bounds: a look lasts at most 4 s; the hide search repeats at most every 0.5 s; a run that stops progressing (route blocked 750 ms) is given up until the next look period (reference stuck detector) |
| Wander | Flags 1 and 4 (identical in the reference) add node wander: `walka`, a random linked node ahead within the active distance of the start, a leg's time limit = distance / walk speed + 1 s, no pause between legs; stops when an enemy is known | Implemented through the shared `actor_wander.next` and `wander.Roam`. Flag 8: see Spawn |
| Skill | The aidata multiplier scales health, damage, speeds and sight range (0.75/1/1.25). Leading deviation in `ai_aim.cpp`. A bullet hurts only if `rnd() > 0.5/(skill+1)` | Multiplier implemented (aidata parse). Damage-admission roll implemented. Leading not used by the guard |
| Perception | `AI_IsVisible`: a trace, then FOV (aidata 220) or within 256 units horizontally. Damage makes the attacker the target | The adapter has its own FOV scan, a duplicate of `actor_perception`. It should use the shared mechanism |
| Do not move | Spawnflag 128: no chase, cover run, look, side-step or wander; turning and firing still work; with no enemy in sight it idles | Implemented |
| Persistence | Phase, rounds, pose, timers; cover destination, look and search timers; roam home, leg and deadline | `mishima.State` plus the shared `cover` and `roam` actor fields, each with `rebase` and `validate` |

## Animation inventory (`models/e1/m_mwguard.dkm`)

`amba` 77–90, `ambb`, `ambc`, `ataka` 131–136, `atakb`, `atakc`, `hita`, `reload` 241–264,
`runa` 265–278, `walka` 354–373, `diea`. Every clip the sheet needs is present.

Neural replacement (`models/neural/e1_mishimaguard.iqm`, remaster): sequence 417 found only
`walka`, `runa`, `cwalka` and `diea` moving; the idles, reload, pain and stances were one static
pistol pose and the attacks a one-unit recoil. Sequences 418–420 fitted the source motion and
were rejected by the owner. Since sequence 421 the attacks (one-handed, kneeling and turned
aims that kick on the shot and settle aimed for the hold), the doubled-over pain and the reload
are authored action clips on the admitted rig (`neural_actions.py`); locomotion, idles and the
death keep the procedural clips. See [neural monsters](../neural-monsters.md).
The neural guard was sculpted without his pistol; since sequence 423 the client draws a pistol model in his
right hand (`render_mishima_guard.zig`, `tag_weapon`).

Remaster presentation: the guard's skeletal model bends its chest and head toward the enemy it
attacks (`cg_skeletalAim`, sequence 417). The reference has no pitch (yaw only).

## Verification (sequence 402)

- Policy tests: the eight-round cycle and its blocked event; cover shots (`ataka` only, one per
  2 s, no rounds). Shared tests: shoulder geometry, look period, arrival, roam legs, spawnflags.
- In game (`runtime_player_probe.py --scenario guard`, e1m3b): guard 65 fires eight rounds and
  reloads; cover guard 90 never spends rounds, fires at most once per 2 s and runs for its hidden
  node. e1m4b guard 119 (flag 1) walks node to node showing `walka` frames 354–373. e1m4a guard
  80 (flag 128) holds its spawn point while firing and reloading.
