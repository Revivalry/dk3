# Skeleton — review sheet

The reference files are `dlls/world/SKELETON.CPP` and the generic AI. Provenance only.

The native code is `src/classes/actors/skeleton/` (`skeleton.zig`: attack choice, pain constants; `server/skeleton.zig`: the shared ground combat with a class spec and directional death).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_skeleton`, model `m_skeleton`, aidata 150 HP, run 250, FOV 215; swing 10 + rnd·5, reach 64; bone remains | Implemented |
| Attack | Within 64 and facing: one of `ataka`, `atakb`, `atakc`, `atakd`, `atake`, `atakg` (a sixth each); further away it runs at the enemy swinging `atakf` (looped); a strike frame passed while not facing is lost | Implemented (`select`, `chase_pose`) |
| Pain | Generic two 20% rolls, limit 35 (`hita`, 450 ms lock); the acquiring hit skips the first | Implemented (sequence 410; it was one roll) |
| Death | By the killer's side: `dieb` from the side, `diea` from in front, `died` from behind | Implemented (`die`) |
| Spawners | e2m1c bone and statue spawners, e2m3a "multimash": spawned skeletons wander | Honoured (spawner spawnflags) |
| Open questions | `atakh`, `diec`, `hitb` unused; the atake/atakf sounds are swapped in the reference table | Recorded |

## Animation inventory (converted `.anim`)

`m_skeleton`: `amba` 0–28, `ataka` 29–44, `atakb` 45–63, `atakc` 64–80, `atakd` 81–100, `atake` 101–118, `atakf` 119–131, `atakg` 132–151, `diea` 165–184, `dieb` 185–199, `died` 225–243, `hita` 244–253, `runa` 284–296, `walka` 297–318. All present.

## Verification (sequence 410)

- Implemented, not yet verified in game.
