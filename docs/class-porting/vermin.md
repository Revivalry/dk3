# Venom vermin — review sheet

The reference files are `dlls/world/Vermin.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/vermin/vermin.zig` and `src/classes/actors/vermin/server/actor_vermin.zig` with `server/vermin.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_venomvermin`, `m_vermin`; 60 HP, run 180, FOV 215; robotic | Implemented |
| Combat | Bands: ≤ 40 bite (`ataka`, poison 1/3 s for 15 s), ≤ 192 lunge (`runa`, no damage: its `atakd` clip is missing), ≤ 400 rocket (`atakc`, 1.5 s cooldown, accelerating to 450 u/s, 128 blast); 25% evasion when targeted | Implemented |
| Pain | Two 50% rolls: `hita` on the first, or on the second for hits of 35 or more (else a brief stall); the hit that acquires the enemy skips the first roll only | Implemented (`actor_pain.generic`; sequence 406 corrects 405, which skipped both rolls) |
| Open questions | The lunge never bites (missing `atakd`); kept as in the reference | Recorded |

## Animation inventory (converted `.anim`)

`m_vermin`: `amba`, `ambb`, `ataka`, `atakc`, `runa`, `walka`, `hita`, `diea`. `atakd` is absent (as in the reference).

## Verification (sequence 405)

- Unit tests: attack bands.
- In game: covered by existing probes; pain uses the shared generic mechanism.
