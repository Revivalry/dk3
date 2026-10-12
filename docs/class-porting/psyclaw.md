# Psyclaw — review sheet

The reference files are `dlls/world/psyclaw.cpp`, the psyclaw section of `ai_weapons.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/psyclaw/psyclaw.zig` (policy: blast tuning, sphere pulse) and `src/classes/actors/psyclaw/server/psyclaw.zig` with `server/psyclaws.zig`, `server/psyclaw_spheres.zig` and `server/psychic_warp.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_psyclaw`, model `m_psyclaw`, aidata 700 HP, run 375, FOV 215; punch (25 + rnd·5, reach 125) and psychic blast (10 + rnd·10, 450 u/s, reach 900); only spawned by `target_monster_spawn` (e1m7b) | Implemented |
| Spawn | Takes no damage for its first 750 ms | Implemented (`protected_until_ms`) |
| Combat | Faces within 5°, then beyond 135 units (target not warped) `ataka`: two spheres on frame 10, the big one warps a player; within 135 or against a warped target `atakb`: punches on frames 5 and 14. The next clip starts at once; a fire frame passed while not facing is lost | Implemented |
| Evasion | When the player aims at it, 50% at attack start and after a ranged clip: a 52-unit sidestep (2.5 s limit) | Implemented (`evade`) |
| Jump | Chasing, an enemy within 200 units horizontally and 32–136 above: leaps at it (450 up), horizontal speed cut to a quarter after 450 ms | Implemented |
| Spheres and warp | Spheres never expire; the big one warps a client for 8 s (5 s full, 3 s fade: velocity scramble, FOV wobble, roll, green flash, `e_atmospheref` loop); the small one deals a second hit | Implemented (`psyclaw_spheres`, `psychic_warp`) |
| Pain | Generic two rolls of 15%, limit 35; the acquiring hit skips the first roll | Implemented (sequence 406: shared acquiring rule) |
| Death | `diea` only (`dieb` is missing from the model) | Implemented |
| Timing | Clips at 20 fps (`ataka` 900 ms, `atakb` 1000 ms) | Implemented (sequence 407: actor clips at 20 fps) |
| Open questions | A small sphere reaching an unwarped client first corrupts memory in the reference; warp damage credits the player himself. Neither is ported | Decisions recorded |

## Animation inventory (converted `.anim`)

`m_psyclaw`: `amba` 0–20, `ambb` 21–40, `ambc` 41–60, `ataka` 61–78, `atakb` 79–98, `diea` 99–119, `hita` 120–136, `runa` 137–149, `walka` 150–169. All present.

## Verification (sequence 406)

- Unit test: the sphere pulse reverses at its bounds.
- Implemented, not yet verified in game: the acquiring-hit pain rule.
