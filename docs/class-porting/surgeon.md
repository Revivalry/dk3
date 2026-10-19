# Surgeon — review sheet

The reference files are `dlls/world/surgeon.cpp`, which reuses the skinny worker's functions in `skinnyworker.cpp` and its actor type, plus the generic AI (`ai_func.cpp`, `ai_think.cpp`, `Sidekick.cpp` for the hide-node search). Provenance only.

The native code is `src/classes/actors/surgeon/surgeon.zig` (policy: cower, hide, stall, timings) and `src/classes/actors/surgeon/server/surgeon.zig` with `server/surgeons.zig`. The hide voice is the shared `src/mechanics/policy/actors/hide_voice.zig` (the workers use it too). The surgeon stays its own class, so its saved state keeps its key.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_surgeon`, model `m_mwsurgeon`, aidata 25 HP, run 150, walk 40, FOV 220; no weapon; flesh gibs | Implemented |
| Spawn | Ignores the player (built in). Spawnflag 2 path follows; 1024 always gibs. All six (e1m3a) carry `uniqueid` and run level scripts | Implemented (`spawn` sets `ignore_player`) |
| Pain | Any client, bot or monster hit: a player's hit clears ignore-player; the attacker becomes its enemy; it cowers in place (no run-away), for at least 15 s. A 75% stall restarts the cower with a fresh pose and reconsider delay, at most once per pose clip (950 / 350 ms) | Implemented (`State.hurt`) |
| Cower | 50/50 looping `gamba` or `gambc`; does not face the enemy. After 10 s: enemy within 300 units and in sight → calm (its goal, often a script, resumes). Enemy beyond its active distance → calm | Implemented (`State.advance`) |
| Hide | Once no longer ignoring the player, a calm surgeon that sees him hides like a skinny worker: hide voice, runs away (`runa`, 10 s limit) node to node, then cowers where it stops | Implemented (sequence 406: `perceive`, `State.hide`/`settle`, the shared flight) |
| Script | A working (scripted) surgeon is blind; fleeing or cowering pauses its script | Implemented (`scriptable`, `pausesScript`) |
| Voice | Hide: 50% silent; `Man_snifs` 12.5%, `skinnydeath` 15%, `skinnydeath2` 22.5% | Implemented (shared `hide_voice`, thin) |
| Death | `diea`; flesh gibs | Implemented (shared remains) |
| Open questions | (1) The reference's 15 s hold is stored as an absolute 15.0 and so never holds; native holds 15 s. (2) Calming by distance walks to the world origin in the reference; native returns home. (3) The reference uses an active distance of 4000 after the alert; native uses the class's sight range. (4) A cambot alarm sends an ignoring surgeon at the player forever (reference quirk, not ported) | Decisions recorded |

## Animation inventory (converted `.anim`)

`m_mwsurgeon`: `amba` 48–67, `diea` 275–291, `gamba` 540–559, `gambc` 568–575, `runa` 576–589, `walka` 590–605, plus the script clips. All present.

Neural replacement: motion authored on the admitted anatomical rig, not fitted to the source (sequences 418–420 were rejected by the owner). Procedural idle, locomotion and death clips; since sequence 421, its cowers and clipboard are authored action clips (`neural_actions.py`). See [neural monsters](../neural-monsters.md).

## Verification (sequence 406)

- Unit tests: injury hold and stall; hide keeps home and settles into a cower without the injury hold.
- `runtime_player_probe.py --scenario surgeon` (e1m3a, surgeon 471 `SRGNasta`): ignores the player beside it; hurt (diagnostic damage), cowers in place (`gambc` 569–575) from 3.8 s; at 13.6 s it sees the player within 300 units, runs (`runa` 576–580) and cowers again.
- Surgeon 476 (`SRGNfyst`, a looping work script) cowers when hurt, then goes back to work blind, as the reference's script rule says.
